use axum::response::IntoResponse;
use backend::error::AppError;
use http::StatusCode;
use wasm_bindgen_test::*;

use crate::helpers::body_json;

#[wasm_bindgen_test]
async fn validation_returns_400_with_detail() {
    let err = AppError::Validation {
        message: "name is required".into(),
        field: Some("name".into()),
    };

    let resp = err.into_response();
    assert_eq!(resp.status(), StatusCode::BAD_REQUEST);

    let json = body_json(resp).await;
    assert_eq!(json["type"], "/errors/validation");
    assert_eq!(json["title"], "Validation Error");
    assert_eq!(json["status"], 400);
    assert_eq!(json["detail"], "name is required");
}

#[wasm_bindgen_test]
async fn not_found_returns_404_with_resource_type() {
    let err = AppError::NotFound {
        resource_type: "User".into(),
        resource_id: "abc-123".into(),
    };

    let resp = err.into_response();
    assert_eq!(resp.status(), StatusCode::NOT_FOUND);

    let json = body_json(resp).await;
    assert_eq!(json["type"], "/errors/not-found");
    assert_eq!(json["title"], "Not Found");
    assert_eq!(json["status"], 404);
    assert_eq!(json["detail"], "User not found");
}

#[wasm_bindgen_test]
async fn unauthorized_returns_401_without_detail() {
    let resp = AppError::Unauthorized.into_response();
    assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);

    let json = body_json(resp).await;
    assert_eq!(json["type"], "/errors/unauthorized");
    assert_eq!(json["title"], "Authentication Required");
    assert_eq!(json["status"], 401);
    assert!(json.get("detail").is_none(), "detail must not be present");
}

#[wasm_bindgen_test]
async fn forbidden_returns_403_without_detail() {
    let resp = AppError::Forbidden.into_response();
    assert_eq!(resp.status(), StatusCode::FORBIDDEN);

    let json = body_json(resp).await;
    assert_eq!(json["type"], "/errors/forbidden");
    assert_eq!(json["title"], "Forbidden");
    assert_eq!(json["status"], 403);
    assert!(json.get("detail").is_none(), "detail must not be present");
}

#[wasm_bindgen_test]
async fn payload_too_large_returns_413() {
    let resp = AppError::PayloadTooLarge {
        limit_bytes: 16 * 1024,
    }
    .into_response();
    assert_eq!(resp.status(), StatusCode::PAYLOAD_TOO_LARGE);

    let json = body_json(resp).await;
    assert_eq!(json["type"], "/errors/payload-too-large");
    assert_eq!(json["title"], "Payload Too Large");
    assert_eq!(json["status"], 413);
}

#[wasm_bindgen_test]
async fn rate_limited_returns_429_with_retry_after() {
    let resp = AppError::TooManyRequests {
        retry_after_seconds: 5,
    }
    .into_response();
    assert_eq!(resp.status(), StatusCode::TOO_MANY_REQUESTS);
    assert_eq!(resp.headers()["retry-after"], "5");

    let json = body_json(resp).await;
    assert_eq!(json["type"], "/errors/rate-limited");
    assert_eq!(json["title"], "Too Many Requests");
    assert_eq!(json["status"], 429);
}

#[wasm_bindgen_test]
async fn internal_error_returns_500_without_leaking_context() {
    let err = AppError::Internal {
        context: "database connection pool exhausted".into(),
        source: None,
    };

    let resp = err.into_response();
    assert_eq!(resp.status(), StatusCode::INTERNAL_SERVER_ERROR);

    let json = body_json(resp).await;
    assert_eq!(json["type"], "/errors/internal");
    assert_eq!(json["title"], "Internal Server Error");
    assert_eq!(json["status"], 500);
    assert!(
        json.get("detail").is_none(),
        "internal context must not leak to client"
    );
}
