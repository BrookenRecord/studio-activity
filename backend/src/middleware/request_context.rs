use crate::{app::AppState, extractors::Edge};
use axum::{
    extract::{Request, State},
    middleware::Next,
    response::Response,
};
use tracing::Instrument;
use uuid::Uuid;

#[derive(Clone, Debug)]
#[allow(unused)]
pub struct RequestId(pub String);

pub async fn layer(
    State(_state): State<AppState>,
    Edge(edge): Edge,
    mut req: Request,
    next: Next,
) -> Response {
    let request_id = edge
        .cf_ray
        .clone()
        .unwrap_or_else(|| Uuid::new_v4().to_string());

    // Make request id available to downstream handlers/middleware
    req.extensions_mut().insert(RequestId(request_id.clone()));

    let span = tracing::info_span!("http_request", request_id = %request_id);

    let mut resp = next.run(req).instrument(span).await;

    // Echo request id back for client-side correlation
    resp.headers_mut().insert(
        http::header::HeaderName::from_static("x-request-id"),
        request_id.parse().unwrap(),
    );

    resp
}
