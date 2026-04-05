use axum::body::Body;
use http::{Request, StatusCode};
use tower::ServiceExt;
use wasm_bindgen_test::*;

use crate::helpers::{inject_edge, mock_edge_context, test_router};

#[wasm_bindgen_test]
async fn root_returns_permanent_redirect() {
    let app = test_router();
    let req = inject_edge(
        Request::get("/").body(Body::empty()).unwrap(),
        mock_edge_context(),
    );

    let resp = app.oneshot(req).await.unwrap();
    assert_eq!(resp.status(), StatusCode::PERMANENT_REDIRECT);
}

#[wasm_bindgen_test]
async fn root_redirect_points_to_github() {
    let app = test_router();
    let req = inject_edge(
        Request::get("/").body(Body::empty()).unwrap(),
        mock_edge_context(),
    );

    let resp = app.oneshot(req).await.unwrap();
    let location = resp.headers().get("location").unwrap().to_str().unwrap();
    assert_eq!(location, "https://github.com/grilme99/studio-activity");
}
