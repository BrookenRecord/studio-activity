use backend::posthog::build_pageview_payload;
use wasm_bindgen_test::*;

#[wasm_bindgen_test]
async fn pageview_payload_includes_all_utm_parameters() {
    let current_url = "https://activity.brooke.sh/?utm_source=twitter&utm_medium=social&utm_campaign=launch&utm_content=hero&utm_term=plugin";
    let payload = build_pageview_payload(
        "test-key",
        None,
        current_url,
        Some("https://t.co/example"),
        Some("Mozilla/5.0"),
        Some("192.0.2.1"),
    );

    let props = payload["properties"].as_object().unwrap();
    assert_eq!(payload["event"], "$pageview");
    assert_eq!(props["$current_url"], current_url);
    assert_eq!(props["utm_source"], "twitter");
    assert_eq!(props["utm_medium"], "social");
    assert_eq!(props["utm_campaign"], "launch");
    assert_eq!(props["utm_content"], "hero");
    assert_eq!(props["utm_term"], "plugin");
}

#[wasm_bindgen_test]
async fn pageview_payload_omits_utm_keys_when_absent() {
    let payload = build_pageview_payload(
        "test-key",
        None,
        "https://activity.brooke.sh/",
        Some("https://example.com/landing"),
        None,
        None,
    );

    let props = payload["properties"].as_object().unwrap();
    for key in [
        "utm_source",
        "utm_medium",
        "utm_campaign",
        "utm_content",
        "utm_term",
    ] {
        assert!(!props.contains_key(key));
    }
}

#[wasm_bindgen_test]
async fn pageview_payload_sets_referrer_and_domain() {
    let payload = build_pageview_payload(
        "test-key",
        None,
        "https://activity.brooke.sh/?utm_source=discord",
        Some("https://twitter.com/someone/status/123"),
        Some("Mozilla/5.0"),
        Some("198.51.100.2"),
    );

    let props = payload["properties"].as_object().unwrap();
    assert_eq!(props["$referrer"], "https://twitter.com/someone/status/123");
    assert_eq!(props["$referring_domain"], "twitter.com");
    assert_eq!(props["$process_person_profile"], false);
    assert_eq!(props["$useragent"], "Mozilla/5.0");
    assert_eq!(props["$ip"], "198.51.100.2");
    assert!(payload["distinct_id"]
        .as_str()
        .is_some_and(|distinct_id| !distinct_id.is_empty()));
}

#[wasm_bindgen_test]
async fn pageview_payload_omits_referrer_fields_when_missing() {
    let payload = build_pageview_payload(
        "test-key",
        None,
        "https://activity.brooke.sh/?utm_source=discord",
        None,
        None,
        None,
    );

    let props = payload["properties"].as_object().unwrap();
    assert!(!props.contains_key("$referrer"));
    assert!(!props.contains_key("$referring_domain"));
    assert_eq!(props["$process_person_profile"], false);
    assert_eq!(
        props["$current_url"],
        "https://activity.brooke.sh/?utm_source=discord"
    );
}

#[wasm_bindgen_test]
async fn pageview_payload_distinct_id_is_stable_for_same_visitor_fingerprint() {
    let payload_a = build_pageview_payload(
        "test-key",
        Some("pepper"),
        "https://activity.brooke.sh/?utm_source=discord",
        None,
        Some("Mozilla/5.0"),
        Some("203.0.113.7"),
    );
    let payload_b = build_pageview_payload(
        "test-key",
        Some("pepper"),
        "https://activity.brooke.sh/?utm_source=discord",
        None,
        Some("Mozilla/5.0"),
        Some("203.0.113.7"),
    );

    assert_eq!(payload_a["distinct_id"], payload_b["distinct_id"]);
}

#[wasm_bindgen_test]
async fn pageview_payload_distinct_id_changes_when_fingerprint_changes() {
    let payload_a = build_pageview_payload(
        "test-key",
        Some("pepper"),
        "https://activity.brooke.sh/?utm_source=discord",
        None,
        Some("Mozilla/5.0"),
        Some("203.0.113.7"),
    );
    let payload_b = build_pageview_payload(
        "test-key",
        Some("pepper"),
        "https://activity.brooke.sh/?utm_source=discord",
        None,
        Some("Mozilla/5.0"),
        Some("203.0.113.8"),
    );

    assert_ne!(payload_a["distinct_id"], payload_b["distinct_id"]);
}
