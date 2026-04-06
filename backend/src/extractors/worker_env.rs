use axum::extract::FromRequestParts;
use http::request::Parts;

use crate::error::AppError;

/// Extracts the Cloudflare Worker `Env` from request extensions.
///
/// The `Env` is inserted per-request in `app::handle` before the router runs.
pub struct WorkerEnv(pub worker::Env);

impl<S> FromRequestParts<S> for WorkerEnv
where
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        parts
            .extensions
            .get::<worker::Env>()
            .cloned()
            .map(WorkerEnv)
            .ok_or(AppError::Internal {
                source: None,
                context: "worker::Env missing from request extensions".into(),
            })
    }
}
