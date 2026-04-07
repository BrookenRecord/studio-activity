//! `GET /v1/version/latest` — proxies the latest GitHub release for the
//! plugin so the plugin can show an "Update Available" badge without
//! hitting GitHub directly.
//!
//! GitHub's unauthenticated API budget is 60 req/hr per IP. Cloudflare
//! Workers all share a small pool of egress IPs, so we cache the upstream
//! response in KV for 5 minutes — well below the budget regardless of
//! plugin install count.

use axum::Json;
use http::StatusCode;
use serde::Deserialize;
use worker::send::SendFuture;
use worker::{Fetch, Headers, Method, Request, RequestInit};

use crate::error::AppError;
use crate::extractors::WorkerEnv;
use crate::proto::LatestVersionResponse;

const KV_NAMESPACE: &str = "VERSION_KV";
const CACHE_KEY: &str = "latest_release";

/// Cache lifetime for the upstream GitHub response.
const CACHE_TTL_SECS: u64 = 300;

/// Identifies this backend in GitHub's logs / abuse reports.
const USER_AGENT: &str = "studio-activity-backend";

/// Cached payload shape — same fields as the proto, serialized as JSON
/// in KV. Kept private so the wire type stays the proto.
#[derive(serde::Serialize, serde::Deserialize, Debug, Clone)]
struct CachedRelease {
    tag: String,
    version: String,
    html_url: String,
    published_at: String,
}

impl From<CachedRelease> for LatestVersionResponse {
    fn from(c: CachedRelease) -> Self {
        Self {
            tag: c.tag,
            version: c.version,
            html_url: c.html_url,
            published_at: c.published_at,
        }
    }
}

/// Subset of the GitHub releases response we care about.
#[derive(Deserialize)]
struct GithubRelease {
    tag_name: String,
    html_url: String,
    published_at: String,
}

fn read_var(env: &worker::Env, key: &str) -> Result<String, AppError> {
    env.var(key)
        .map(|v| v.to_string())
        .map_err(|e| AppError::Internal {
            context: format!("missing required var {key}"),
            source: Some(Box::new(std::io::Error::other(e.to_string()))),
        })
}

async fn load_cached(env: &worker::Env) -> Option<CachedRelease> {
    let kv = env.kv(KV_NAMESPACE).ok()?;
    kv.get(CACHE_KEY).json().await.ok().flatten()
}

async fn store_cached(env: &worker::Env, release: &CachedRelease) {
    let Ok(kv) = env.kv(KV_NAMESPACE) else {
        tracing::debug!("VERSION_KV namespace unavailable, skipping cache write");
        return;
    };

    let Ok(serialized) = serde_json::to_string(release) else {
        return;
    };

    let put_result = kv
        .put(CACHE_KEY, serialized)
        .map(|p| p.expiration_ttl(CACHE_TTL_SECS));

    match put_result {
        Ok(builder) => {
            if let Err(e) = builder.execute().await {
                tracing::warn!(error = %e, "VERSION_KV put execute failed");
            }
        }
        Err(e) => {
            tracing::warn!(error = %e, "VERSION_KV put builder failed");
        }
    }
}

async fn fetch_from_github(repo: &str) -> Result<CachedRelease, AppError> {
    let url = format!("https://api.github.com/repos/{repo}/releases/latest");

    let headers = Headers::new();
    headers
        .set("User-Agent", USER_AGENT)
        .and_then(|()| headers.set("Accept", "application/vnd.github+json"))
        .and_then(|()| headers.set("X-GitHub-Api-Version", "2022-11-28"))
        .map_err(|e| AppError::ExternalService {
            service: "github".into(),
            source: Box::new(std::io::Error::other(e.to_string())),
            status_hint: None,
        })?;

    let mut init = RequestInit::new();
    init.with_method(Method::Get).with_headers(headers);

    let req = Request::new_with_init(&url, &init).map_err(|e| AppError::ExternalService {
        service: "github".into(),
        source: Box::new(std::io::Error::other(e.to_string())),
        status_hint: None,
    })?;

    let mut resp = Fetch::Request(req)
        .send()
        .await
        .map_err(|e| AppError::ExternalService {
            service: "github".into(),
            source: Box::new(std::io::Error::other(e.to_string())),
            status_hint: None,
        })?;

    let status = resp.status_code();
    if !(200..300).contains(&status) {
        return Err(AppError::ExternalService {
            service: "github".into(),
            source: Box::new(std::io::Error::other(format!(
                "github returned status {status}"
            ))),
            status_hint: Some(StatusCode::from_u16(status).unwrap_or(StatusCode::BAD_GATEWAY)),
        });
    }

    let body = resp.text().await.map_err(|e| AppError::ExternalService {
        service: "github".into(),
        source: Box::new(std::io::Error::other(e.to_string())),
        status_hint: None,
    })?;

    let release: GithubRelease =
        serde_json::from_str(&body).map_err(|e| AppError::ExternalService {
            service: "github".into(),
            source: Box::new(e),
            status_hint: None,
        })?;

    // Drop a leading "v" if present so the plugin can string-compare
    // against `BuildVars.build.version` (which has no prefix).
    let version = release
        .tag_name
        .strip_prefix('v')
        .unwrap_or(&release.tag_name)
        .to_string();

    Ok(CachedRelease {
        tag: release.tag_name,
        version,
        html_url: release.html_url,
        published_at: release.published_at,
    })
}

// Suppress JS-stays-on-WASM-thread Send warnings — see telemetry.rs for context.
#[allow(clippy::must_use_candidate)]
#[tracing::instrument(skip_all)]
pub fn latest(
    WorkerEnv(env): WorkerEnv,
) -> SendFuture<impl std::future::Future<Output = Result<Json<LatestVersionResponse>, AppError>>> {
    SendFuture::new(async move {
        if let Some(cached) = load_cached(&env).await {
            tracing::debug!(version = %cached.version, "version cache hit");
            return Ok(Json(cached.into()));
        }

        let repo = read_var(&env, "GITHUB_REPO")?;
        let release = fetch_from_github(&repo).await?;
        tracing::info!(version = %release.version, "version cache miss, fetched from github");

        store_cached(&env, &release).await;

        Ok(Json(release.into()))
    })
}
