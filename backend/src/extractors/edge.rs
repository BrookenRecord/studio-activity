use axum::extract::FromRequestParts;
use http::request::Parts;

use crate::error::AppError;
use crate::models::edge_context::EdgeContext;

pub struct Edge(pub EdgeContext);

impl<S> FromRequestParts<S> for Edge
where
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request_parts(parts: &mut Parts, _state: &S) -> Result<Self, Self::Rejection> {
        parts
            .extensions
            .get::<EdgeContext>()
            .cloned()
            .map(Edge)
            .ok_or(AppError::Internal {
                source: None,
                context: "EdgeContext missing from request extensions".into(),
            })
    }
}
