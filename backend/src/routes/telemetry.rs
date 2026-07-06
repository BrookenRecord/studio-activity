use axum::http::StatusCode;
use worker::send::SendFuture;

use crate::error::AppError;
use crate::extractors::{AppJson, Edge, WorkerContext, WorkerEnv};
use crate::posthog;
use crate::proto::TelemetryRequest;

const DEFAULT_POSTHOG_HOST: &str = "https://us.i.posthog.com";
const MAX_DISTINCT_IDS_PER_IP: usize = 3;
const IDENTITY_WINDOW_TTL_SECS: u64 = 86_400;
const MAX_DISTINCT_ID_LEN: usize = 64;

pub fn is_valid_distinct_id(distinct_id: &str) -> bool {
    !distinct_id.is_empty()
        && distinct_id.len() <= MAX_DISTINCT_ID_LEN
        && distinct_id
            .bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_')
}

/// Checks the per-IP and per-user Cloudflare rate limiters.
/// Returns `Some(reason)` if the request should be silently dropped.
async fn check_rate_limits(
    env: &worker::Env,
    client_ip: &str,
    distinct_id: &str,
) -> Option<&'static str> {
    if let Ok(limiter) = env.rate_limiter("TELEMETRY_IP_LIMITER") {
        match limiter.limit(format!("ip:{client_ip}")).await {
            Ok(res) if res.success => {}
            Ok(_) => return Some("ip_rate_limit"),
            Err(e) => {
                tracing::debug!(error = %e, "ip rate limiter unavailable, skipping");
            }
        }
    }

    if let Ok(limiter) = env.rate_limiter("TELEMETRY_USER_LIMITER") {
        match limiter.limit(format!("user:{distinct_id}")).await {
            Ok(res) if res.success => {}
            Ok(_) => return Some("user_rate_limit"),
            Err(e) => {
                tracing::debug!(error = %e, "user rate limiter unavailable, skipping");
            }
        }
    }

    None
}

/// Checks whether this IP has exceeded its `distinct_id` budget using KV.
/// Cloudflare KV is eventually consistent, so this is a best-effort abuse
/// control rather than an atomic concurrency limit.
/// Returns `Some("identity_spray")` if the request should be silently dropped.
async fn check_identity_budget(
    env: &worker::Env,
    client_ip: &str,
    distinct_id: &str,
) -> Option<&'static str> {
    let kv = match env.kv("TELEMETRY_KV") {
        Ok(kv) => kv,
        Err(e) => {
            tracing::debug!(error = %e, "KV namespace unavailable, skipping identity check");
            return None;
        }
    };

    let key = format!("ip:{client_ip}");

    let ids: Vec<String> = match kv.get(&key).json().await {
        Ok(Some(ids)) => ids,
        Ok(None) => Vec::new(),
        Err(e) => {
            tracing::debug!(error = %e, "KV read failed, skipping identity check");
            return None;
        }
    };

    if ids.iter().any(|id| id == distinct_id) {
        return None;
    }

    if ids.len() >= MAX_DISTINCT_IDS_PER_IP {
        return Some("identity_spray");
    }

    let mut updated = ids;
    updated.push(distinct_id.to_string());

    let serialized = match serde_json::to_string(&updated) {
        Ok(serialized) => serialized,
        Err(e) => {
            tracing::debug!(error = %e, "failed to serialize telemetry identity budget");
            return None;
        }
    };

    match kv
        .put(&key, serialized)
        .map(|p| p.expiration_ttl(IDENTITY_WINDOW_TTL_SECS))
    {
        Ok(write) => {
            if let Err(e) = write.execute().await {
                tracing::warn!(error = %e, "telemetry identity budget write failed");
            }
        }
        Err(e) => {
            tracing::warn!(error = %e, "telemetry identity budget write builder failed");
        }
    }

    None
}

/// Telemetry ingestion endpoint.
///
/// Returns a [`SendFuture`] because the handler body holds worker-rs types
/// (KV, `RateLimiter`) across await points. These wrap JS objects that are
/// `!Send`, but WASM is single-threaded so this is safe.
///
/// `PostHog` forwarding is deferred via `ctx.wait_until()` so the response
/// is sent before the outbound HTTP call, eliminating a timing side-channel
/// between dropped and forwarded events.
#[allow(clippy::must_use_candidate)]
pub fn telemetry(
    Edge(edge): Edge,
    WorkerEnv(env): WorkerEnv,
    WorkerContext(ctx_arc): WorkerContext,
    AppJson(payload): AppJson<TelemetryRequest>,
) -> SendFuture<impl std::future::Future<Output = Result<StatusCode, AppError>>> {
    SendFuture::new(async move {
        let client_ip = edge.client_ip.as_deref().unwrap_or("unknown");

        if !is_valid_distinct_id(&payload.distinct_id) {
            return Err(AppError::Validation {
                message: format!(
                    "distinct_id must be 1-{MAX_DISTINCT_ID_LEN} ASCII letters, numbers, dashes, or underscores"
                ),
                field: Some("distinct_id".into()),
            });
        }

        let event = payload.event.as_ref().ok_or_else(|| AppError::Validation {
            message: "event is required".into(),
            field: Some("event".into()),
        })?;

        let (event_name, _) = posthog::decompose_event(event);

        tracing::Span::current()
            .record("event_name", event_name.as_str())
            .record(
                "client_ip_known",
                !client_ip.is_empty() && client_ip != "unknown",
            );

        // Rate limiting (silent drop)
        if let Some(reason) = check_rate_limits(&env, client_ip, &payload.distinct_id).await {
            tracing::warn!(
                drop_reason = reason,
                event_name = event_name.as_str(),
                "telemetry event silently dropped",
            );
            return Ok(StatusCode::NO_CONTENT);
        }

        // IP identity budget check (silent drop)
        if let Some(reason) = check_identity_budget(&env, client_ip, &payload.distinct_id).await {
            tracing::warn!(
                drop_reason = reason,
                event_name = event_name.as_str(),
                ids_threshold = MAX_DISTINCT_IDS_PER_IP,
                "telemetry event silently dropped",
            );
            return Ok(StatusCode::NO_CONTENT);
        }

        let posthog_host = env
            .var("POSTHOG_HOST")
            .map_or_else(|_| DEFAULT_POSTHOG_HOST.to_string(), |v| v.to_string());

        let api_key = match env.secret("POSTHOG_API_KEY") {
            Ok(key) => key.to_string(),
            Err(e) => {
                tracing::error!(error = %e, "POSTHOG_API_KEY secret not configured");
                return Ok(StatusCode::NO_CONTENT);
            }
        };

        // Defer PostHog forwarding until after the response is sent.
        // This eliminates the timing difference between dropped and
        // forwarded events -- both return 204 in the same timeframe.
        let client_ip_owned = client_ip.to_string();
        let event_clone = event.clone();
        ctx_arc.wait_until(async move {
            posthog::forward_event(
                &posthog_host,
                &api_key,
                &payload,
                &event_clone,
                Some(&client_ip_owned),
            )
            .await;
        });

        Ok(StatusCode::NO_CONTENT)
    })
}
