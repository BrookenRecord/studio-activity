use axum::body::Body;
use http::{Request, StatusCode};
use tower::ServiceExt;
use wasm_bindgen_test::*;

use crate::helpers::{inject_edge, mock_edge_context, mock_edge_context_minimal, test_router};

#[wasm_bindgen_test]
async fn cf_ray_propagated_as_request_id() {
    let app = test_router();
    let req = inject_edge(
        Request::get("/ping")
            .header("content-type", "application/json")
            .body(Body::from(r#"{}"#))
            .unwrap(),
        mock_edge_context(),
    );

    let resp = app.oneshot(req).await.unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    let request_id = resp
        .headers()
        .get("x-request-id")
        .expect("x-request-id header should be set")
        .to_str()
        .unwrap();
    assert_eq!(request_id, "test-ray-abc123");
}

#[wasm_bindgen_test]
async fn missing_cf_ray_generates_fallback_request_id() {
    let app = test_router();
    let req = inject_edge(
        Request::get("/ping")
            .header("content-type", "application/json")
            .body(Body::from(r#"{}"#))
            .unwrap(),
        mock_edge_context_minimal(),
    );

    let resp = app.oneshot(req).await.unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    let request_id = resp
        .headers()
        .get("x-request-id")
        .expect("x-request-id header should be set")
        .to_str()
        .unwrap();
    assert!(
        !request_id.is_empty(),
        "fallback request id should not be empty"
    );
    assert_ne!(
        request_id, "unknown",
        "should generate a UUID, not 'unknown'"
    );
}
