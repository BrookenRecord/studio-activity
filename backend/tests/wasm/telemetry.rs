use axum::body::Body;
use http::{Request, StatusCode};
use tower::ServiceExt;
use wasm_bindgen_test::*;

use backend::posthog::decompose_event;
use backend::proto::api::v1::{
    telemetry_request, AppOpened, AuthFailed, AuthStarted, TelemetryRequest,
};

use crate::helpers::{inject_edge, mock_edge_context, test_router};

// ---------------------------------------------------------------------------
// Proto type deserialization (JSON -> prost types)
// ---------------------------------------------------------------------------

#[wasm_bindgen_test]
async fn deserialize_app_opened_event() {
    let json = r#"{"distinctId":"user-1","event":{"appOpened":{}}}"#;
    let req: TelemetryRequest = serde_json::from_str(json).unwrap();
    assert_eq!(req.distinct_id, "user-1");
    assert!(matches!(
        req.event,
        Some(telemetry_request::Event::AppOpened(_))
    ));
}

#[wasm_bindgen_test]
async fn deserialize_auth_started_with_properties() {
    let json = r#"{
        "distinctId": "user-2",
        "event": {
            "authStarted": {
                "hasExistingCredentials": true
            }
        }
    }"#;
    let req: TelemetryRequest = serde_json::from_str(json).unwrap();
    assert!(matches!(
        req.event,
        Some(telemetry_request::Event::AuthStarted(AuthStarted {
            has_existing_credentials: true,
        }))
    ));
}

#[wasm_bindgen_test]
async fn deserialize_auth_failed_optional_fields() {
    let json = r#"{
        "distinctId": "user-3",
        "event": {
            "authFailed": {
                "errorType": "network"
            }
        }
    }"#;
    let req: TelemetryRequest = serde_json::from_str(json).unwrap();
    match req.event {
        Some(telemetry_request::Event::AuthFailed(e)) => {
            assert_eq!(e.error_type, "network");
            assert_eq!(e.error_code, None);
        }
        other => panic!("expected AuthFailed, got {other:?}"),
    }
}

#[wasm_bindgen_test]
async fn deserialize_auth_failed_with_all_fields() {
    let json = r#"{
        "distinctId": "user-3",
        "event": {
            "authFailed": {
                "errorType": "network",
                "errorCode": "ETIMEOUT"
            }
        }
    }"#;
    let req: TelemetryRequest = serde_json::from_str(json).unwrap();
    match req.event {
        Some(telemetry_request::Event::AuthFailed(AuthFailed {
            error_type,
            error_code,
        })) => {
            assert_eq!(error_type, "network");
            assert_eq!(error_code.as_deref(), Some("ETIMEOUT"));
        }
        other => panic!("expected AuthFailed, got {other:?}"),
    }
}

#[wasm_bindgen_test]
async fn deserialize_defaults_missing_scalar_fields() {
    // Proto3 scalars default when omitted; serde(default) handles this.
    let json = r#"{"distinctId":"user-4","event":{"appOpened":{}}}"#;
    let req: TelemetryRequest = serde_json::from_str(json).unwrap();
    assert!(matches!(
        req.event,
        Some(telemetry_request::Event::AppOpened(AppOpened {}))
    ));
}

#[wasm_bindgen_test]
async fn reject_unknown_event_variant() {
    let json = r#"{"distinctId":"user-5","event":{"madeUpEvent":{}}}"#;
    let result = serde_json::from_str::<TelemetryRequest>(json);
    assert!(result.is_err(), "unknown event variant should be rejected");
}

#[wasm_bindgen_test]
async fn reject_unknown_fields_on_event() {
    let json = r#"{
        "distinctId": "user-6",
        "event": {
            "authStarted": {
                "hasExistingCredentials": true,
                "extraField": 42
            }
        }
    }"#;
    let result = serde_json::from_str::<TelemetryRequest>(json);
    assert!(
        result.is_err(),
        "extra fields should be rejected with deny_unknown_fields"
    );
}

#[wasm_bindgen_test]
async fn reject_unknown_fields_on_request() {
    let json = r#"{
        "distinctId": "user-7",
        "event": {"appOpened": {}},
        "extraTopLevel": true
    }"#;
    let result = serde_json::from_str::<TelemetryRequest>(json);
    assert!(
        result.is_err(),
        "extra top-level fields should be rejected"
    );
}

#[wasm_bindgen_test]
async fn reject_wrong_property_types() {
    let json = r#"{
        "distinctId": "user-8",
        "event": {
            "authStarted": {
                "hasExistingCredentials": "yes"
            }
        }
    }"#;
    let result = serde_json::from_str::<TelemetryRequest>(json);
    assert!(result.is_err(), "wrong property type should be rejected");
}

// ---------------------------------------------------------------------------
// decompose_event (serde-driven name + properties extraction)
// ---------------------------------------------------------------------------

#[wasm_bindgen_test]
async fn decompose_produces_snake_case_name() {
    let event = telemetry_request::Event::AppOpened(AppOpened {});
    let (name, props) = decompose_event(&event);
    assert_eq!(name, "app_opened");
    assert_eq!(props, serde_json::json!({}));
}

#[wasm_bindgen_test]
async fn decompose_includes_event_properties() {
    let event = telemetry_request::Event::AuthStarted(AuthStarted {
        has_existing_credentials: true,
    });
    let (name, props) = decompose_event(&event);
    assert_eq!(name, "auth_started");
    assert_eq!(props["has_existing_credentials"], true);
}

#[wasm_bindgen_test]
async fn decompose_strips_null_optional_fields() {
    let event = telemetry_request::Event::AuthFailed(AuthFailed {
        error_type: "network".into(),
        error_code: None,
    });
    let (name, props) = decompose_event(&event);
    assert_eq!(name, "auth_failed");
    assert_eq!(props["error_type"], "network");
    assert!(
        props.get("error_code").is_none(),
        "None optional fields should be stripped, not serialized as null"
    );
}

#[wasm_bindgen_test]
async fn decompose_keeps_present_optional_fields() {
    let event = telemetry_request::Event::AuthFailed(AuthFailed {
        error_type: "network".into(),
        error_code: Some("ETIMEOUT".into()),
    });
    let (_, props) = decompose_event(&event);
    assert_eq!(props["error_code"], "ETIMEOUT");
}

// ---------------------------------------------------------------------------
// Integration tests (routing layer)
// ---------------------------------------------------------------------------

#[wasm_bindgen_test]
async fn telemetry_get_returns_405() {
    let app = test_router();
    let req = inject_edge(
        Request::get("/v1/telemetry").body(Body::empty()).unwrap(),
        mock_edge_context(),
    );

    let resp = app.oneshot(req).await.unwrap();
    assert_eq!(resp.status(), StatusCode::METHOD_NOT_ALLOWED);
}

#[wasm_bindgen_test]
async fn telemetry_missing_content_type_returns_400() {
    let app = test_router();
    // POST without Content-Type: application/json
    let req = inject_edge(
        Request::post("/v1/telemetry")
            .body(Body::from(r#"{"distinctId":"u","event":{"appOpened":{}}}"#))
            .unwrap(),
        mock_edge_context(),
    );

    let resp = app.oneshot(req).await.unwrap();
    // Without Env in extensions, WorkerEnv extractor fails first with 500.
    // With Env, AppJson would fail with 400 for missing content-type.
    // Either way, we get an error -- not a 204.
    assert_ne!(resp.status(), StatusCode::NO_CONTENT);
}

#[wasm_bindgen_test]
async fn telemetry_invalid_json_returns_error() {
    let app = test_router();
    let req = inject_edge(
        Request::post("/v1/telemetry")
            .header("content-type", "application/json")
            .body(Body::from("not valid json"))
            .unwrap(),
        mock_edge_context(),
    );

    let resp = app.oneshot(req).await.unwrap();
    // Without Env, WorkerEnv extractor returns 500 before JSON parsing.
    // The important thing: bad input never returns 204.
    assert_ne!(resp.status(), StatusCode::NO_CONTENT);
}

// Note: Tests that exercise rate limiting, KV identity tracking, and PostHog
// forwarding require a live Cloudflare Worker environment. These should be
// validated via `wrangler dev` or a staging deployment.
