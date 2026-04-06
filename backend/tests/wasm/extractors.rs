use axum::body::Body;
use http::{Request, StatusCode};
use tower::ServiceExt;
use wasm_bindgen_test::*;

use crate::helpers::{body_json, test_router};

#[wasm_bindgen_test]
async fn missing_edge_context_returns_500() {
    let app = test_router();
    let req = Request::get("/health").body(Body::empty()).unwrap();

    let resp = app.oneshot(req).await.unwrap();
    assert_eq!(resp.status(), StatusCode::INTERNAL_SERVER_ERROR);

    let json = body_json(resp).await;
    assert_eq!(json["type"], "/errors/internal");
    assert!(json.get("detail").is_none(), "internal context must not leak");
}
