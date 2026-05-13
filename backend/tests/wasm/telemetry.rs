use axum::body::Body;
use http::{Request, StatusCode};
use tower::ServiceExt;
use wasm_bindgen_test::*;

use backend::posthog::decompose_event;
use backend::proto::{
    telemetry_request, AccountLinked, BrowserFlowFailed, DeviceCodeFlowFailed, OnboardingCompleted,
    PluginLoaded, PresenceToggled, ProfileSelected, SessionError, TelemetryRequest,
};

use crate::helpers::{inject_edge, mock_edge_context, test_router};

// ---------------------------------------------------------------------------
// Proto type deserialization (JSON -> prost types)
// ---------------------------------------------------------------------------

#[wasm_bindgen_test]
async fn deserialize_plugin_loaded() {
    let json = r#"{
        "distinctId": "user-1",
        "pluginLoaded": {
            "accountCount": 2,
            "isPresenceActive": true,
            "activeProfile": "default"
        }
    }"#;
    let req: TelemetryRequest = serde_json::from_str(json).unwrap();
    assert_eq!(req.distinct_id, "user-1");
    match req.event {
        Some(telemetry_request::Event::PluginLoaded(e)) => {
            assert_eq!(e.account_count, 2);
            assert!(e.is_presence_active);
            assert_eq!(e.active_profile, "default");
        }
        other => panic!("expected PluginLoaded, got {other:?}"),
    }
}

#[wasm_bindgen_test]
async fn deserialize_plugin_loaded_defaults() {
    let json = r#"{"distinctId":"user-1","pluginLoaded":{}}"#;
    let req: TelemetryRequest = serde_json::from_str(json).unwrap();
    match req.event {
        Some(telemetry_request::Event::PluginLoaded(PluginLoaded {
            account_count,
            is_presence_active,
            active_profile,
        })) => {
            assert_eq!(account_count, 0);
            assert!(!is_presence_active);
            assert_eq!(active_profile, "");
        }
        other => panic!("expected PluginLoaded, got {other:?}"),
    }
}

#[wasm_bindgen_test]
async fn deserialize_ui_opened() {
    let json = r#"{"distinctId":"user-2","uiOpened":{}}"#;
    let req: TelemetryRequest = serde_json::from_str(json).unwrap();
    assert!(matches!(
        req.event,
        Some(telemetry_request::Event::UiOpened(_))
    ));
}

#[wasm_bindgen_test]
async fn deserialize_onboarding_completed() {
    let json = r#"{
        "distinctId": "user-3",
        "onboardingCompleted": { "optedIntoTelemetry": true }
    }"#;
    let req: TelemetryRequest = serde_json::from_str(json).unwrap();
    assert!(matches!(
        req.event,
        Some(telemetry_request::Event::OnboardingCompleted(
            OnboardingCompleted {
                opted_into_telemetry: true,
            }
        ))
    ));
}

#[wasm_bindgen_test]
async fn deserialize_account_linked() {
    let json = r#"{
        "distinctId": "user-4",
        "accountLinked": {
            "accountCount": 1,
            "isFirstAccount": true,
            "linkFlow": 1
        }
    }"#;
    let req: TelemetryRequest = serde_json::from_str(json).unwrap();
    assert!(matches!(
        req.event,
        Some(telemetry_request::Event::AccountLinked(AccountLinked {
            account_count: 1,
            is_first_account: true,
            link_flow: 1,
        }))
    ));
}

#[wasm_bindgen_test]
async fn deserialize_device_code_flow_failed() {
    let json = r#"{
        "distinctId": "user-5",
        "deviceCodeFlowFailed": { "error": "expired" }
    }"#;
    let req: TelemetryRequest = serde_json::from_str(json).unwrap();
    match req.event {
        Some(telemetry_request::Event::DeviceCodeFlowFailed(DeviceCodeFlowFailed { error })) => {
            assert_eq!(error, "expired");
        }
        other => panic!("expected DeviceCodeFlowFailed, got {other:?}"),
    }
}

#[wasm_bindgen_test]
async fn deserialize_browser_flow_failed() {
    let json = r#"{
        "distinctId": "user-5b",
        "browserFlowFailed": { "error": "timeout" }
    }"#;
    let req: TelemetryRequest = serde_json::from_str(json).unwrap();
    match req.event {
        Some(telemetry_request::Event::BrowserFlowFailed(BrowserFlowFailed { error })) => {
            assert_eq!(error, "timeout");
        }
        other => panic!("expected BrowserFlowFailed, got {other:?}"),
    }
}

#[wasm_bindgen_test]
async fn deserialize_presence_toggled() {
    let json = r#"{
        "distinctId": "user-6",
        "presenceToggled": { "isActive": false }
    }"#;
    let req: TelemetryRequest = serde_json::from_str(json).unwrap();
    assert!(matches!(
        req.event,
        Some(telemetry_request::Event::PresenceToggled(PresenceToggled {
            is_active: false,
        }))
    ));
}

#[wasm_bindgen_test]
async fn deserialize_profile_selected() {
    let json = r#"{
        "distinctId": "user-7",
        "profileSelected": { "profile": "minimal" }
    }"#;
    let req: TelemetryRequest = serde_json::from_str(json).unwrap();
    match req.event {
        Some(telemetry_request::Event::ProfileSelected(ProfileSelected { profile })) => {
            assert_eq!(profile, "minimal");
        }
        other => panic!("expected ProfileSelected, got {other:?}"),
    }
}

#[wasm_bindgen_test]
async fn deserialize_session_error() {
    let json = r#"{
        "distinctId": "user-8",
        "sessionError": { "error": "refresh_failed" }
    }"#;
    let req: TelemetryRequest = serde_json::from_str(json).unwrap();
    match req.event {
        Some(telemetry_request::Event::SessionError(SessionError { error })) => {
            assert_eq!(error, "refresh_failed");
        }
        other => panic!("expected SessionError, got {other:?}"),
    }
}

#[wasm_bindgen_test]
async fn deserialize_with_plugin_metadata() {
    let json = r#"{
        "distinctId": "user-9",
        "pluginVersion": "1.2.0",
        "pluginChannel": "stable",
        "pluginHash": "abc123",
        "uiOpened": {}
    }"#;
    let req: TelemetryRequest = serde_json::from_str(json).unwrap();
    assert_eq!(req.plugin_version, "1.2.0");
    assert_eq!(req.plugin_channel, "stable");
    assert_eq!(req.plugin_hash, "abc123");
}

// ---------------------------------------------------------------------------
// Validation (reject bad input)
// ---------------------------------------------------------------------------

#[wasm_bindgen_test]
async fn reject_unknown_event_variant() {
    let json = r#"{"distinctId":"u","madeUpEvent":{}}"#;
    let result = serde_json::from_str::<TelemetryRequest>(json);
    assert!(result.is_err(), "unknown event variant should be rejected");
}

#[wasm_bindgen_test]
async fn reject_unknown_fields_on_event() {
    let json = r#"{
        "distinctId": "u",
        "accountLinked": { "accountCount": 1, "isFirstAccount": true, "extra": 42 }
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
        "distinctId": "u",
        "uiOpened": {},
        "extraTopLevel": true
    }"#;
    let result = serde_json::from_str::<TelemetryRequest>(json);
    assert!(result.is_err(), "extra top-level fields should be rejected");
}

#[wasm_bindgen_test]
async fn reject_wrong_property_types() {
    let json = r#"{
        "distinctId": "u",
        "presenceToggled": { "isActive": "yes" }
    }"#;
    let result = serde_json::from_str::<TelemetryRequest>(json);
    assert!(result.is_err(), "wrong property type should be rejected");
}

// ---------------------------------------------------------------------------
// decompose_event (serde-driven name + properties extraction)
// ---------------------------------------------------------------------------

#[wasm_bindgen_test]
async fn decompose_produces_snake_case_name() {
    let event = telemetry_request::Event::PluginLoaded(PluginLoaded {
        account_count: 0,
        is_presence_active: false,
        active_profile: String::new(),
    });
    let (name, _) = decompose_event(&event);
    assert_eq!(name, "plugin_loaded");
}

#[wasm_bindgen_test]
async fn decompose_includes_event_properties() {
    let event = telemetry_request::Event::AccountLinked(AccountLinked {
        account_count: 2,
        is_first_account: false,
        link_flow: 1,
    });
    let (name, props) = decompose_event(&event);
    assert_eq!(name, "account_linked");
    assert_eq!(props["account_count"], 2);
    assert_eq!(props["is_first_account"], false);
    assert_eq!(props["link_flow"], "ACCOUNT_LINK_FLOW_DEVICE_CODE");
}

#[wasm_bindgen_test]
async fn decompose_empty_event() {
    let event = telemetry_request::Event::UiOpened(Default::default());
    let (name, props) = decompose_event(&event);
    assert_eq!(name, "ui_opened");
    assert_eq!(props, serde_json::json!({}));
}

#[wasm_bindgen_test]
async fn decompose_multiword_event_name() {
    let event = telemetry_request::Event::AccountLinkStarted(Default::default());
    let (name, _) = decompose_event(&event);
    assert_eq!(name, "account_link_started");
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
async fn telemetry_missing_content_type_returns_error() {
    let app = test_router();
    let req = inject_edge(
        Request::post("/v1/telemetry")
            .body(Body::from(
                r#"{"distinctId":"u","pluginLoaded":{}}"#,
            ))
            .unwrap(),
        mock_edge_context(),
    );

    let resp = app.oneshot(req).await.unwrap();
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
    assert_ne!(resp.status(), StatusCode::NO_CONTENT);
}

// Note: Tests that exercise rate limiting, KV identity tracking, and PostHog
// forwarding require a live Cloudflare Worker environment. These should be
// validated via `wrangler dev` or a staging deployment.
