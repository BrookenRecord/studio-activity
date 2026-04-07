//! Browser-based `OAuth2` (PKCE) flow for Discord account linking.
//!
//! High-level lifecycle (see `protos/api/v1/api.proto` for the wire types):
//!
//! 1. Plugin generates `code_verifier` + `code_challenge` locally.
//! 2. Plugin POSTs to `/v1/oauth/browser/start` with the challenge.
//!    Backend stores `{challenge, status: pending}` in `OAUTH_KV` keyed by
//!    a fresh nanoid session token, and hands the plugin a short
//!    `start_url` (`/start/{token}`) plus the exact `redirect_uri` it will
//!    pass to Discord.
//! 3. User pastes `start_url` into a browser. `start_redirect` builds the
//!    Discord authorize URL using the stored challenge and 303s there.
//! 4. After consent, Discord redirects to `/v1/oauth/browser/callback`
//!    with `code` + `state`. The handler stores the `code` against the
//!    session and shows a "you can close this tab" page.
//! 5. Plugin polls `/v1/oauth/browser/poll`. On `complete`, the response
//!    carries the `code` and the KV entry is deleted (one-shot).
//! 6. Plugin calls Discord's `/oauth2/token` endpoint directly with
//!    `code + code_verifier`. The backend never sees the verifier or
//!    the resulting access/refresh tokens.

use axum::{
    extract::{Path, Query},
    http::StatusCode,
    response::{Html, IntoResponse, Redirect, Response},
};
use serde::{Deserialize, Serialize};
use worker::send::SendFuture;
use worker::Date;

use crate::error::AppError;
use crate::extractors::{AppJson, Edge, WorkerEnv};
use crate::proto::{
    BrowserFlowPollRequest, BrowserFlowPollResponse, BrowserFlowStartRequest,
    BrowserFlowStartResponse, BrowserFlowStatus,
};

const KV_NAMESPACE: &str = "OAUTH_KV";
const SESSION_KEY_PREFIX: &str = "browser_flow:";

/// Initial TTL for a pending session (10 minutes — matches Discord's
/// authorize-code window).
const SESSION_TTL_SECS: u64 = 600;

/// Once the callback has stored a `code`, the plugin should claim it
/// quickly. Shorten the TTL so abandoned codes don't sit around.
const COMPLETED_TTL_SECS: u64 = 120;

/// Recommended polling interval handed back to the plugin.
const POLL_INTERVAL_SECS: i32 = 2;

/// PKCE method we always advertise.
const CODE_CHALLENGE_METHOD: &str = "S256";

/// Default scope, mirrors `plugin/src/Api/Discord.luau`'s `DEFAULT_SCOPE`.
const DEFAULT_SCOPE: &str = "sdk.social_layer_presence";

/// `code_challenge` validation: base64url payload, 32–128 chars (43 is the
/// canonical S256 length, but accept anything within RFC bounds).
fn is_valid_code_challenge(s: &str) -> bool {
    let len = s.len();
    (32..=128).contains(&len)
        && s.bytes()
            .all(|b| b.is_ascii_alphanumeric() || b == b'-' || b == b'_')
}

#[derive(Serialize, Deserialize, Debug, Clone, Copy, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
enum SessionStatus {
    Pending,
    Complete,
    Denied,
    Expired,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
struct StoredSession {
    code_challenge: String,
    status: SessionStatus,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    code: Option<String>,
    created_at: u64,
}

/// `std::time::SystemTime::now()` panics on `wasm32-unknown-unknown`
/// (the Workers target). Use the JS `Date` bridge from worker-rs instead.
fn now_secs() -> u64 {
    Date::now().as_millis() / 1000
}

fn session_key(token: &str) -> String {
    format!("{SESSION_KEY_PREFIX}{token}")
}

async fn load_session(env: &worker::Env, token: &str) -> Option<StoredSession> {
    let kv = env.kv(KV_NAMESPACE).ok()?;
    kv.get(&session_key(token)).json().await.ok().flatten()
}

async fn store_session(
    env: &worker::Env,
    token: &str,
    session: &StoredSession,
    ttl_secs: u64,
) -> Result<(), AppError> {
    let kv = env.kv(KV_NAMESPACE).map_err(|e| AppError::Internal {
        context: "OAUTH_KV namespace unavailable".into(),
        source: Some(Box::new(std::io::Error::other(e.to_string()))),
    })?;

    let serialized = serde_json::to_string(session).map_err(|e| AppError::Internal {
        context: "failed to serialize OAuth session".into(),
        source: Some(Box::new(e)),
    })?;

    kv.put(&session_key(token), serialized)
        .map(|p| p.expiration_ttl(ttl_secs))
        .map_err(|e| AppError::Internal {
            context: "OAUTH_KV put builder failed".into(),
            source: Some(Box::new(std::io::Error::other(e.to_string()))),
        })?
        .execute()
        .await
        .map_err(|e| AppError::Internal {
            context: "OAUTH_KV put execute failed".into(),
            source: Some(Box::new(std::io::Error::other(e.to_string()))),
        })?;

    Ok(())
}

async fn delete_session(env: &worker::Env, token: &str) {
    if let Ok(kv) = env.kv(KV_NAMESPACE) {
        if let Err(e) = kv.delete(&session_key(token)).await {
            tracing::debug!(error = %e, "failed to delete OAuth KV entry");
        }
    }
}

fn read_var(env: &worker::Env, key: &str) -> Result<String, AppError> {
    env.var(key)
        .map(|v| v.to_string())
        .map_err(|e| AppError::Internal {
            context: format!("missing required var {key}"),
            source: Some(Box::new(std::io::Error::other(e.to_string()))),
        })
}

fn redirect_uri_for(public_url: &str) -> String {
    format!(
        "{}/v1/oauth/browser/callback",
        public_url.trim_end_matches('/')
    )
}

fn start_url_for(public_url: &str, token: &str) -> String {
    format!("{}/start/{token}", public_url.trim_end_matches('/'))
}

/// Build the Discord authorize URL with the canonical PKCE parameters.
fn build_authorize_url(
    client_id: &str,
    scope: &str,
    redirect_uri: &str,
    state: &str,
    code_challenge: &str,
) -> String {
    let mut url = url::Url::parse("https://discord.com/oauth2/authorize")
        .expect("static authorize URL is valid");
    url.query_pairs_mut()
        .append_pair("response_type", "code")
        .append_pair("client_id", client_id)
        .append_pair("scope", scope)
        .append_pair("redirect_uri", redirect_uri)
        .append_pair("state", state)
        .append_pair("code_challenge", code_challenge)
        .append_pair("code_challenge_method", CODE_CHALLENGE_METHOD)
        .append_pair("prompt", "consent");
    url.into()
}

// ---------------------------------------------------------------------------
// POST /v1/oauth/browser/start
// ---------------------------------------------------------------------------

#[allow(clippy::must_use_candidate)]
pub fn start_session(
    WorkerEnv(env): WorkerEnv,
    AppJson(payload): AppJson<BrowserFlowStartRequest>,
) -> SendFuture<
    impl std::future::Future<Output = Result<axum::Json<BrowserFlowStartResponse>, AppError>>,
> {
    SendFuture::new(async move {
        if !is_valid_code_challenge(&payload.code_challenge) {
            return Err(AppError::Validation {
                message: "code_challenge must be 32-128 base64url characters".into(),
                field: Some("code_challenge".into()),
            });
        }

        let public_url = read_var(&env, "BACKEND_PUBLIC_URL")?;

        // 21-char URL-safe alphabet ≈ 125 bits of entropy.
        let token = nanoid::nanoid!();

        let session = StoredSession {
            code_challenge: payload.code_challenge.clone(),
            status: SessionStatus::Pending,
            code: None,
            created_at: now_secs(),
        };

        store_session(&env, &token, &session, SESSION_TTL_SECS).await?;

        tracing::info!(session_token = %token, "browser oauth session created");

        Ok(axum::Json(BrowserFlowStartResponse {
            session_token: token.clone(),
            start_url: start_url_for(&public_url, &token),
            redirect_uri: redirect_uri_for(&public_url),
            expires_in: i32::try_from(SESSION_TTL_SECS).unwrap_or(i32::MAX),
            poll_interval: POLL_INTERVAL_SECS,
        }))
    })
}

// ---------------------------------------------------------------------------
// GET /start/{token}
// ---------------------------------------------------------------------------

#[allow(clippy::must_use_candidate)]
pub fn start_redirect(
    WorkerEnv(env): WorkerEnv,
    Path(token): Path<String>,
) -> SendFuture<impl std::future::Future<Output = Response>> {
    SendFuture::new(async move {
        let Some(session) = load_session(&env, &token).await else {
            return error_page(
                "This link has expired. Please return to Roblox Studio and start the account-link flow again.",
            )
            .into_response();
        };

        if session.status != SessionStatus::Pending {
            return error_page(
                "This link has already been used. Please return to Roblox Studio and start the account-link flow again.",
            )
            .into_response();
        }

        let public_url = match read_var(&env, "BACKEND_PUBLIC_URL") {
            Ok(v) => v,
            Err(e) => return e.into_response(),
        };

        let client_id = match read_var(&env, "DISCORD_CLIENT_ID") {
            Ok(v) => v,
            Err(e) => return e.into_response(),
        };

        let scope = env
            .var("DISCORD_OAUTH_SCOPE")
            .map_or_else(|_| DEFAULT_SCOPE.to_string(), |v| v.to_string());

        let authorize_url = build_authorize_url(
            &client_id,
            &scope,
            &redirect_uri_for(&public_url),
            &token,
            &session.code_challenge,
        );

        Redirect::to(&authorize_url).into_response()
    })
}

// ---------------------------------------------------------------------------
// GET /v1/oauth/browser/callback
// ---------------------------------------------------------------------------

#[derive(Deserialize, Debug)]
pub struct CallbackParams {
    code: Option<String>,
    state: Option<String>,
    error: Option<String>,
    #[allow(dead_code)]
    error_description: Option<String>,
}

#[allow(clippy::must_use_candidate)]
pub fn discord_callback(
    WorkerEnv(env): WorkerEnv,
    Query(params): Query<CallbackParams>,
) -> SendFuture<impl std::future::Future<Output = Response>> {
    SendFuture::new(async move {
        let Some(state) = params.state.as_deref() else {
            return error_page("Missing state parameter.").into_response();
        };

        let Some(mut session) = load_session(&env, state).await else {
            return error_page("This link has expired. Please return to Roblox Studio and start the account-link flow again.").into_response();
        };

        if let Some(error_kind) = params.error.as_deref() {
            tracing::warn!(error = error_kind, state, "discord callback returned error");
            session.status = if error_kind == "access_denied" {
                SessionStatus::Denied
            } else {
                SessionStatus::Expired
            };
            session.code = None;
            if let Err(e) = store_session(&env, state, &session, COMPLETED_TTL_SECS).await {
                tracing::error!(error = ?e, "failed to persist denied session");
            }
            return success_page(
                "Account linking was cancelled. You can close this tab and return to Roblox Studio.",
            )
            .into_response();
        }

        let Some(code) = params.code else {
            return error_page("Missing authorization code.").into_response();
        };

        session.status = SessionStatus::Complete;
        session.code = Some(code);

        if let Err(e) = store_session(&env, state, &session, COMPLETED_TTL_SECS).await {
            tracing::error!(error = ?e, "failed to persist completed session");
            return e.into_response();
        }

        success_page("Authentication complete. You can close this tab and return to Roblox Studio.")
            .into_response()
    })
}

// ---------------------------------------------------------------------------
// POST /v1/oauth/browser/poll
// ---------------------------------------------------------------------------

#[allow(clippy::must_use_candidate)]
pub fn poll_session(
    Edge(edge): Edge,
    WorkerEnv(env): WorkerEnv,
    AppJson(payload): AppJson<BrowserFlowPollRequest>,
) -> SendFuture<
    impl std::future::Future<Output = Result<axum::Json<BrowserFlowPollResponse>, AppError>>,
> {
    SendFuture::new(async move {
        if payload.session_token.is_empty() {
            return Err(AppError::Validation {
                message: "session_token is required".into(),
                field: Some("session_token".into()),
            });
        }

        // Per-IP poll throttle. Plugin polls every ~2s; 60/min leaves
        // plenty of headroom for a single user but blocks abusive loops.
        if let Ok(limiter) = env.rate_limiter("OAUTH_POLL_LIMITER") {
            let client_ip = edge.client_ip.as_deref().unwrap_or("unknown");
            match limiter.limit(format!("ip:{client_ip}")).await {
                Ok(res) if res.success => {}
                Ok(_) => {
                    return Err(AppError::Validation {
                        message: "Too many polls. Slow down.".into(),
                        field: None,
                    });
                }
                Err(e) => {
                    tracing::debug!(error = %e, "oauth poll limiter unavailable, skipping");
                }
            }
        }

        let Some(session) = load_session(&env, &payload.session_token).await else {
            return Ok(axum::Json(BrowserFlowPollResponse {
                status: BrowserFlowStatus::Expired as i32,
                code: String::new(),
            }));
        };

        let response = match session.status {
            SessionStatus::Pending => BrowserFlowPollResponse {
                status: BrowserFlowStatus::Pending as i32,
                code: String::new(),
            },
            SessionStatus::Denied => {
                delete_session(&env, &payload.session_token).await;
                BrowserFlowPollResponse {
                    status: BrowserFlowStatus::Denied as i32,
                    code: String::new(),
                }
            }
            SessionStatus::Expired => {
                delete_session(&env, &payload.session_token).await;
                BrowserFlowPollResponse {
                    status: BrowserFlowStatus::Expired as i32,
                    code: String::new(),
                }
            }
            SessionStatus::Complete => {
                let code = session.code.unwrap_or_default();
                // One-shot: hand the code over and immediately discard.
                delete_session(&env, &payload.session_token).await;
                BrowserFlowPollResponse {
                    status: BrowserFlowStatus::Complete as i32,
                    code,
                }
            }
        };

        Ok(axum::Json(response))
    })
}

// ---------------------------------------------------------------------------
// HTML responses for browser-facing endpoints
// ---------------------------------------------------------------------------

fn page_template(title: &str, headline: &str, body: &str) -> String {
    format!(
        r#"<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<style>
  :root {{ color-scheme: dark; }}
  body {{
    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", system-ui, sans-serif;
    background: #1a1b1f;
    color: #d6d8df;
    max-width: 480px;
    margin: 4rem auto;
    padding: 0 1.25rem;
    line-height: 1.5;
  }}
  h1 {{ color: #ffffff; font-weight: 600; font-size: 1.5rem; margin-bottom: 0.75rem; }}
  p {{ margin-top: 0; }}
</style>
</head>
<body>
  <h1>{headline}</h1>
  <p>{body}</p>
</body>
</html>"#
    )
}

fn success_page(body: &str) -> impl IntoResponse {
    (
        StatusCode::OK,
        Html(page_template(
            "Account linked",
            "Authentication complete",
            body,
        )),
    )
}

fn error_page(body: &str) -> impl IntoResponse {
    (
        StatusCode::NOT_FOUND,
        Html(page_template("Link expired", "Link expired", body)),
    )
}
