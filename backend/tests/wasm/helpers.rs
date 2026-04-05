use axum::{body::Body, middleware, Router};
use backend::{
    app::{build_router, AppState},
    middleware as mw,
    models::edge_context::EdgeContext,
};
use http::Request;
use http_body_util::BodyExt;
use serde_json::Value;

/// An `EdgeContext` with realistic test values (no CF runtime object).
pub fn mock_edge_context() -> EdgeContext {
    EdgeContext {
        cf: None,
        asn: Some(13335),
        as_organization: Some("Cloudflare".to_string()),
        country: Some("US".to_string()),
        colo: Some("SJC".to_string()),
        cf_ray: Some("test-ray-abc123".to_string()),
        client_ip: Some("192.0.2.1".to_string()),
    }
}

/// An `EdgeContext` with all metadata absent, simulating a request
/// without Cloudflare headers (e.g. local development).
pub fn mock_edge_context_minimal() -> EdgeContext {
    EdgeContext {
        cf: None,
        asn: None,
        as_organization: None,
        country: None,
        colo: None,
        cf_ray: None,
        client_ip: None,
    }
}

/// Builds the full production router (routes + middleware + state)
/// without requiring `worker::Env`.
pub fn test_router() -> Router {
    let state = AppState {};
    build_router()
        .layer(middleware::from_fn_with_state(
            state.clone(),
            mw::request_context::layer,
        ))
        .with_state(state)
}

/// Inserts an `EdgeContext` into the request's extensions,
/// mimicking what `lib.rs` does before handing off to axum.
pub fn inject_edge(mut req: Request<Body>, edge: EdgeContext) -> Request<Body> {
    req.extensions_mut().insert(edge);
    req
}

/// Collects a response body and deserializes it as JSON.
pub async fn body_json(resp: http::Response<Body>) -> Value {
    let bytes = resp.into_body().collect().await.unwrap().to_bytes();
    serde_json::from_slice(&bytes).unwrap()
}
