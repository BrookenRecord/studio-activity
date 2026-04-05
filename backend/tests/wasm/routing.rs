use axum::body::Body;
use http::{Request, StatusCode};
use tower::ServiceExt;
use wasm_bindgen_test::*;

use crate::helpers::{inject_edge, mock_edge_context, test_router};

#[wasm_bindgen_test]
async fn unknown_route_returns_404() {
    let app = test_router();
    let req = inject_edge(
        Request::get("/does-not-exist").body(Body::empty()).unwrap(),
        mock_edge_context(),
    );

    let resp = app.oneshot(req).await.unwrap();
    assert_eq!(resp.status(), StatusCode::NOT_FOUND);
}
