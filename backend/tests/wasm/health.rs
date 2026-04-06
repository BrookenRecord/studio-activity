use axum::body::Body;
use http::{Request, StatusCode};
use http_body_util::BodyExt;
use tower::ServiceExt;
use wasm_bindgen_test::*;

use crate::helpers::{inject_edge, mock_edge_context, test_router};

#[wasm_bindgen_test]
async fn health_returns_200() {
    let app = test_router();
    let req = inject_edge(
        Request::get("/health").body(Body::empty()).unwrap(),
        mock_edge_context(),
    );

    let resp = app.oneshot(req).await.unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    let body = resp.into_body().collect().await.unwrap().to_bytes();
    assert!(body.is_empty(), "health response should have no body");
}
