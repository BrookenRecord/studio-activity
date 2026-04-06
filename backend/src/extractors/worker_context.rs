use std::sync::Arc;

use axum::extract::FromRequestParts;
use http::request::Parts;

use crate::error::AppError;

/// Shared handle to the Cloudflare Worker `Context`.
///
/// Wrapped in `Arc` because `Context` is not `Clone` but
/// `http::Extensions` requires `Clone`. Since `wait_until` takes
/// `&self`, shared ownership via `Arc` is sufficient.
#[derive(Clone)]
pub struct WorkerContext(pub Arc<worker::Context>);

impl<S> FromRequestParts<S> for WorkerContext
where
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        parts
            .extensions
            .get::<WorkerContext>()
            .cloned()
            .ok_or(AppError::Internal {
                source: None,
                context: "worker::Context missing from request extensions".into(),
            })
    }
}
