use axum::body::Body;
use http::{Request, StatusCode};
use tower::ServiceExt;
use wasm_bindgen_test::*;

use crate::helpers::{body_json, inject_edge, mock_edge_context, test_router};

fn ping_request(json_body: &str) -> Request<Body> {
    Request::get("/ping")
        .header("content-type", "application/json")
        .body(Body::from(json_body.to_owned()))
        .unwrap()
}

#[wasm_bindgen_test]
async fn ping_echoes_message() {
    let app = test_router();
    let req = inject_edge(ping_request(r#"{"message":"hello"}"#), mock_edge_context());

    let resp = app.oneshot(req).await.unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    let json = body_json(resp).await;
    assert_eq!(json["message"], "hello");
    assert!(json["timestamp"].is_i64(), "timestamp should be an integer");
}

#[wasm_bindgen_test]
async fn ping_defaults_to_pong_when_message_absent() {
    let app = test_router();
    let req = inject_edge(ping_request(r#"{}"#), mock_edge_context());

    let resp = app.oneshot(req).await.unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    let json = body_json(resp).await;
    assert_eq!(json["message"], "pong");
}

#[wasm_bindgen_test]
async fn ping_rejects_malformed_json() {
    let app = test_router();
    let req = inject_edge(ping_request("not valid json"), mock_edge_context());

    let resp = app.oneshot(req).await.unwrap();
    assert_eq!(resp.status(), StatusCode::BAD_REQUEST);

    let json = body_json(resp).await;
    assert_eq!(json["type"], "/errors/validation");
    assert_eq!(json["detail"], "Request body contains invalid JSON");
}

#[wasm_bindgen_test]
async fn ping_rejects_missing_content_type() {
    let app = test_router();
    let req = inject_edge(
        Request::get("/ping")
            .body(Body::from(r#"{"message":"hi"}"#))
            .unwrap(),
        mock_edge_context(),
    );

    let resp = app.oneshot(req).await.unwrap();
    assert_eq!(resp.status(), StatusCode::BAD_REQUEST);

    let json = body_json(resp).await;
    assert_eq!(json["type"], "/errors/validation");
    assert!(
        json["detail"].as_str().unwrap().contains("Content-Type"),
        "detail should mention Content-Type"
    );
}
