use axum::body::Body;
use http::{Request, StatusCode};
use tower::ServiceExt;
use wasm_bindgen_test::*;

use crate::helpers::{body_json, inject_edge, mock_edge_context, test_router};

#[wasm_bindgen_test]
async fn missing_edge_context_returns_500() {
    let app = test_router();
    let req = Request::get("/ping")
        .header("content-type", "application/json")
        .body(Body::from(r#"{}"#))
        .unwrap();

    let resp = app.oneshot(req).await.unwrap();
    assert_eq!(resp.status(), StatusCode::INTERNAL_SERVER_ERROR);

    let json = body_json(resp).await;
    assert_eq!(json["type"], "/errors/internal");
    assert!(
        json.get("detail").is_none(),
        "internal context must not leak"
    );
}

#[wasm_bindgen_test]
async fn app_json_syntax_error_returns_structured_error() {
    let app = test_router();
    let req = inject_edge(
        Request::get("/ping")
            .header("content-type", "application/json")
            .body(Body::from("{invalid"))
            .unwrap(),
        mock_edge_context(),
    );

    let resp = app.oneshot(req).await.unwrap();
    assert_eq!(resp.status(), StatusCode::BAD_REQUEST);

    let json = body_json(resp).await;
    assert_eq!(json["type"], "/errors/validation");
    assert_eq!(json["title"], "Validation Error");
    assert!(
        json.get("detail").is_some(),
        "validation errors should include detail"
    );
}
