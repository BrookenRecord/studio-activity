use crate::{app::AppState, extractors::Edge};
use axum::{
    extract::{Request, State},
    middleware::Next,
    response::Response,
};

#[derive(Clone, Debug)]
#[allow(unused)]
pub struct RequestId(pub String);

pub async fn layer(
    State(_state): State<AppState>,
    Edge(edge): Edge,
    mut req: Request,
    next: Next,
) -> Response {
    let request_id = edge.cf_ray.clone().unwrap_or_else(|| "unknown".to_string());

    // Make request id available to downstream handlers/middleware
    req.extensions_mut().insert(RequestId(request_id.clone()));

    let span = tracing::info_span!("http_request", request_id = %request_id);
    let _enter = span.enter();

    let mut resp = next.run(req).await;

    // Echo request id back for client-side correlation
    resp.headers_mut().insert(
        http::header::HeaderName::from_static("x-request-id"),
        request_id.parse().unwrap(),
    );

    resp
}
