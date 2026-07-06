//! Lightweight PostHog telemetry proxy.
//!
//! # Privacy
//!
//! This module forwards validated, opt-in telemetry events to PostHog.
//! Users must explicitly consent to telemetry in the plugin settings
//! before any data is sent. Here is what we collect and why:
//!
//! - **Event name + properties**: Which features are used and how often,
//!   so we can prioritize development. Defined in `protos/api/v1/api.proto`.
//! - **Anonymous install ID** (`distinct_id`): A random per-install GUID,
//!   generated client-side after telemetry consent exists. It is not derived
//!   from a Roblox account ID.
//! - **Plugin version/channel/hash**: So we know which versions are in
//!   active use and can deprecate safely.
//! - **IP address**: Forwarded to PostHog *only* for bot detection and
//!   country-level geo enrichment (for future localization). The PostHog
//!   project is configured to discard IPs after processing - they are
//!   **not** stored with events.
//!
//! We do **not** collect: Roblox usernames, place names or IDs, game
//! content, file paths, system information, or any free-form text.

use once_cell::sync::Lazy;
use prost::Message;
use prost_reflect::{DescriptorPool, DynamicMessage, SerializeOptions};
use serde_json::{json, Value};
use url::Url;
use uuid::Uuid;
use worker::wasm_bindgen::JsValue;
use worker::{Fetch, Headers, Method, Request, RequestInit};

use crate::proto::{telemetry_request::Event, PluginBuildTarget, TelemetryRequest};

const POSTHOG_CAPTURE_PATH: &str = "/i/v0/e/";
const LIB_NAME: &str = "studio-activity-backend";
const LIB_VERSION: &str = env!("CARGO_PKG_VERSION");
const TELEMETRY_REQUEST_DESCRIPTOR_NAME: &str = "api.v1.TelemetryRequest";
const UTM_PARAM_KEYS: [&str; 5] = [
    "utm_source",
    "utm_medium",
    "utm_campaign",
    "utm_content",
    "utm_term",
];

static DESCRIPTOR_POOL: Lazy<DescriptorPool> = Lazy::new(|| {
    DescriptorPool::decode(
        include_bytes!(concat!(env!("OUT_DIR"), "/proto_descriptor.bin")).as_ref(),
    )
    .expect("api.v1 descriptor pool")
});

fn posthog_serialize_options() -> SerializeOptions {
    SerializeOptions::new()
        .use_proto_field_name(true)
        // Keep enum values in their canonical proto JSON string form.
        .skip_default_fields(false)
}

/// Decomposes a proto `Event` into its snake_case event name and a flat
/// properties JSON object by using `prost-reflect`'s JSON serializer.
///
/// We serialize via reflection so we can apply PostHog-specific options
/// without changing the plugin-facing pbjson wire format:
/// - `use_proto_field_name(true)` for snake_case keys
/// - `skip_default_fields(false)` so false/0/"" are preserved
///
/// Null values (from unset `optional` proto fields) are stripped so
/// only properties that were actually provided are forwarded.
pub fn decompose_event(event: &Event) -> (String, Value) {
    let descriptor = match DESCRIPTOR_POOL.get_message_by_name(TELEMETRY_REQUEST_DESCRIPTOR_NAME) {
        Some(descriptor) => descriptor,
        None => return (String::new(), json!({})),
    };

    // Wrap in TelemetryRequest so the oneof field name itself gives us
    // the event name in proto snake_case.
    let mut request = TelemetryRequest::default();
    request.event = Some(event.clone());

    let encoded = request.encode_to_vec();
    let dynamic = match DynamicMessage::decode(descriptor.clone(), encoded.as_slice()) {
        Ok(dynamic) => dynamic,
        Err(_) => return (String::new(), json!({})),
    };

    let mut serializer = serde_json::Serializer::new(Vec::new());
    if dynamic
        .serialize_with_options(&mut serializer, &posthog_serialize_options())
        .is_err()
    {
        return (String::new(), json!({}));
    }

    let serialized: Value = serde_json::from_slice(&serializer.into_inner()).unwrap_or_default();
    let Value::Object(mut map) = serialized else {
        return (String::new(), json!({}));
    };

    let Some(event_oneof) = descriptor.oneofs().find(|oneof| oneof.name() == "event") else {
        return (String::new(), json!({}));
    };
    let Some((name, mut properties)) = event_oneof.fields().find_map(|field| {
        map.remove(field.name())
            .map(|value| (field.name().to_owned(), value))
    }) else {
        return (String::new(), json!({}));
    };

    if let Some(props) = properties.as_object_mut() {
        props.retain(|_, v| !v.is_null());
    }

    (name, properties)
}

/// Returns true if this event represents a session start.
///
/// Session-start events trigger two additional PostHog calls:
/// - `$identify`: links the anonymous hash to usage metadata (version,
///   channel) so PostHog can count monthly active users.
/// - `$screen`: signals an "app open" so PostHog's built-in daily/weekly/
///   monthly active user dashboards work.
fn is_session_start(event: &Event) -> bool {
    matches!(event, Event::PluginLoaded(_))
}

/// Returns true if this event needs per-user correlation in PostHog.
///
/// Identified events can be used in funnels (tracking one user across
/// multiple steps) and per-user aggregations (e.g. average accounts per
/// user). They cost more to process, so we only identify events that
/// need these capabilities. All other events stay anonymous — they still
/// count toward aggregate totals but can't be correlated per-user.
fn is_identified(event: &Event) -> bool {
    matches!(
        event,
        Event::PluginLoaded(_)
            | Event::UiOpened(_)
            | Event::OnboardingCompleted(_)
            | Event::AccountLinkStarted(_)
            | Event::AccountLinked(_)
            | Event::PresenceToggled(_)
    )
}

/// Injects the standard set of properties that every PostHog event carries.
fn inject_common_properties(
    props: &mut serde_json::Map<String, Value>,
    req: &TelemetryRequest,
    client_ip: Option<&str>,
) {
    // Identifies this backend as the event source in PostHog.
    props.insert("$lib".into(), json!(LIB_NAME));
    props.insert("$lib_version".into(), json!(LIB_VERSION));

    // Session ID groups all events from one plugin load into a PostHog session.
    if !req.session_id.is_empty() {
        props.insert("$session_id".into(), json!(req.session_id));
    }

    // Plugin build metadata — lets us see which versions are in use.
    if !req.plugin_version.is_empty() {
        props.insert("$app_version".into(), json!(req.plugin_version));
    }
    if !req.plugin_hash.is_empty() {
        props.insert("$app_build".into(), json!(req.plugin_hash));
    }
    if !req.plugin_channel.is_empty() {
        props.insert("plugin_channel".into(), json!(req.plugin_channel));
    }
    if let Ok(target) = PluginBuildTarget::try_from(req.plugin_target) {
        if target != PluginBuildTarget::Unspecified {
            props.insert("$app_namespace".into(), json!(target.as_str_name()));
        }
    }

    // IP is used only for bot detection and country-level geo enrichment.
    // The PostHog project is configured to discard IPs after processing.
    if let Some(ip) = client_ip {
        props.insert("$ip".into(), json!(ip));
    }
}

/// Builds the capture payload for a single telemetry event.
fn build_capture_payload(
    api_key: &str,
    req: &TelemetryRequest,
    event: &Event,
    client_ip: Option<&str>,
) -> Value {
    let (name, mut properties) = decompose_event(event);
    let props = properties.as_object_mut().unwrap();

    inject_common_properties(props, req, client_ip);

    // PostHog charges more for events that update user records. We only
    // do that for events that need per-user correlation (funnels, per-user
    // aggregations). All other events are "anonymous" — they still count
    // toward aggregate totals but don't update any stored user data.
    if !is_identified(event) {
        props.insert("$process_person_profile".into(), json!(false));
    }

    json!({
        "api_key": api_key,
        "event": name,
        "distinct_id": req.distinct_id,
        "properties": properties,
    })
}

/// Builds a `$identify` event that links the anonymous hash to usage
/// metadata (plugin version, channel, current state). This is what lets
/// PostHog count unique active users over time and slice dashboards by
/// user properties. It does **not** identify a real person.
fn build_identify_payload(
    api_key: &str,
    req: &TelemetryRequest,
    event: &Event,
    client_ip: Option<&str>,
) -> Value {
    // $set: overwrite with the latest values each session.
    // $set_once: record the first value ever seen (for retention analysis).
    let mut set = json!({});
    let mut set_once = json!({});

    if !req.plugin_version.is_empty() {
        set["$app_version"] = json!(req.plugin_version);
        set_once["$initial_app_version"] = json!(req.plugin_version);
    }
    if !req.plugin_hash.is_empty() {
        set["$app_build"] = json!(req.plugin_hash);
    }
    if !req.plugin_channel.is_empty() {
        set["plugin_channel"] = json!(req.plugin_channel);
    }

    // PluginLoaded carries current user state so PostHog person properties
    // reflect the user's setup at the start of each session.
    if let Event::PluginLoaded(loaded) = event {
        set["account_count"] = json!(loaded.account_count);
        set["is_presence_active"] = json!(loaded.is_presence_active);
        if !loaded.active_profile.is_empty() {
            set["active_profile"] = json!(loaded.active_profile);
        }
    }

    let mut properties = json!({
        "$lib": LIB_NAME,
        "$lib_version": LIB_VERSION,
        "$set": set,
        "$set_once": set_once,
    });

    if let Some(ip) = client_ip {
        properties["$ip"] = json!(ip);
    }

    json!({
        "api_key": api_key,
        "event": "$identify",
        "distinct_id": req.distinct_id,
        "properties": properties,
    })
}

/// Builds a `$screen` event that signals "the user opened the plugin".
/// This is the mobile-app equivalent of a page view and is what powers
/// PostHog's built-in daily/weekly/monthly active user dashboards.
fn build_screen_payload(api_key: &str, req: &TelemetryRequest, client_ip: Option<&str>) -> Value {
    let mut properties = json!({
        "$screen_name": "studio_activity",
        "$lib": LIB_NAME,
        "$lib_version": LIB_VERSION,
    });

    if !req.plugin_version.is_empty() {
        properties["$app_version"] = json!(req.plugin_version);
    }

    if let Some(ip) = client_ip {
        properties["$ip"] = json!(ip);
    }

    json!({
        "api_key": api_key,
        "event": "$screen",
        "distinct_id": req.distinct_id,
        "properties": properties,
    })
}

/// Extracts UTM parameters from a fully-qualified URL.
fn extract_utm_from_url(current_url: &str) -> serde_json::Map<String, Value> {
    let mut out = serde_json::Map::new();

    let Ok(url) = Url::parse(current_url) else {
        return out;
    };

    for (key, value) in url.query_pairs() {
        let key = key.as_ref();
        if !UTM_PARAM_KEYS.contains(&key) {
            continue;
        }

        let value = value.trim();
        if value.is_empty() {
            continue;
        }

        out.insert(key.to_string(), json!(value));
    }

    out
}

/// Attempts to parse the host from a referrer URL.
fn referring_domain(referrer: &str) -> Option<String> {
    let parsed = Url::parse(referrer).ok()?;
    parsed.host_str().map(ToOwned::to_owned)
}

/// Builds a deterministic, anonymous distinct id for server-side pageviews.
///
/// We hash a fingerprint of `client_ip + user_agent` using UUID v5 with a
/// per-deployment salt, so IDs are stable for attribution but still anonymous.
/// If both inputs are absent we fall back to a random UUID to avoid creating
/// one shared "unknown" identity across many visitors.
fn stable_pageview_distinct_id(
    salt: &str,
    client_ip: Option<&str>,
    user_agent: Option<&str>,
) -> String {
    let ip = client_ip.map(str::trim).filter(|value| !value.is_empty());
    let ua = user_agent.map(str::trim).filter(|value| !value.is_empty());

    if ip.is_none() && ua.is_none() {
        return Uuid::new_v4().to_string();
    }

    let fingerprint = format!(
        "root_pageview_v1|{salt}|{}|{}",
        ip.unwrap_or("unknown_ip"),
        ua.unwrap_or("unknown_ua")
    );
    Uuid::new_v5(&Uuid::NAMESPACE_URL, fingerprint.as_bytes()).to_string()
}

/// Builds an anonymous `$pageview` payload for root-domain attribution.
pub fn build_pageview_payload(
    api_key: &str,
    distinct_id_salt: Option<&str>,
    current_url: &str,
    referrer: Option<&str>,
    user_agent: Option<&str>,
    client_ip: Option<&str>,
) -> Value {
    let mut properties = serde_json::Map::new();
    properties.insert("$current_url".into(), json!(current_url));
    properties.insert("$lib".into(), json!(LIB_NAME));
    properties.insert("$lib_version".into(), json!(LIB_VERSION));
    properties.insert("$process_person_profile".into(), json!(false));

    properties.extend(extract_utm_from_url(current_url));

    if let Some(value) = referrer.map(str::trim).filter(|value| !value.is_empty()) {
        properties.insert("$referrer".into(), json!(value));

        if let Some(domain) = referring_domain(value) {
            properties.insert("$referring_domain".into(), json!(domain));
        }
    }

    if let Some(value) = user_agent.map(str::trim).filter(|value| !value.is_empty()) {
        properties.insert("$useragent".into(), json!(value));
    }

    if let Some(value) = client_ip.map(str::trim).filter(|value| !value.is_empty()) {
        properties.insert("$ip".into(), json!(value));
    }

    let distinct_id = distinct_id_salt
        .map(str::trim)
        .filter(|salt| !salt.is_empty())
        .map_or_else(
            || Uuid::new_v4().to_string(),
            |salt| stable_pageview_distinct_id(salt, client_ip, user_agent),
        );

    json!({
        "api_key": api_key,
        "event": "$pageview",
        "distinct_id": distinct_id,
        "properties": properties,
    })
}

/// Forwards a prebuilt payload to PostHog capture.
pub async fn forward_payload(host: &str, payload: &Value) {
    send_to_posthog(host, payload).await;
}

/// Forwards an anonymous `$pageview` event for root-domain attribution.
pub async fn forward_pageview(
    host: &str,
    api_key: &str,
    distinct_id_salt: Option<&str>,
    current_url: &str,
    referrer: Option<&str>,
    user_agent: Option<&str>,
    client_ip: Option<&str>,
) {
    let payload = build_pageview_payload(
        api_key,
        distinct_id_salt,
        current_url,
        referrer,
        user_agent,
        client_ip,
    );
    forward_payload(host, &payload).await;
}

/// Sends a JSON payload to the PostHog capture API. Errors are logged,
/// not propagated — telemetry forwarding is fire-and-forget.
async fn send_to_posthog(host: &str, payload: &Value) {
    let url = format!("{host}{POSTHOG_CAPTURE_PATH}");

    let result: Result<(), Box<dyn std::error::Error>> = async {
        let headers = Headers::new();
        headers.set("Content-Type", "application/json")?;

        let mut init = RequestInit::new();
        init.with_method(Method::Post)
            .with_headers(headers)
            .with_body(Some(JsValue::from_str(&serde_json::to_string(payload)?)));

        let req = Request::new_with_init(&url, &init)?;
        let resp = Fetch::Request(req).send().await?;

        if resp.status_code() < 200 || resp.status_code() >= 300 {
            tracing::warn!(
                status = resp.status_code(),
                "posthog capture returned non-2xx"
            );
        }

        Ok(())
    }
    .await;

    if let Err(e) = result {
        tracing::warn!(error = %e, "failed to send event to posthog");
    }
}

/// Forwards a validated, opt-in telemetry event to PostHog.
///
/// For session-start events (`PluginLoaded`), also sends `$identify`
/// (with current user state as person properties) and `$screen` so
/// PostHog can count active users over time.
pub async fn forward_event(
    host: &str,
    api_key: &str,
    request: &TelemetryRequest,
    event: &Event,
    client_ip: Option<&str>,
) {
    let capture = build_capture_payload(api_key, request, event, client_ip);
    send_to_posthog(host, &capture).await;

    if is_session_start(event) {
        let identify = build_identify_payload(api_key, request, event, client_ip);
        send_to_posthog(host, &identify).await;

        let screen = build_screen_payload(api_key, request, client_ip);
        send_to_posthog(host, &screen).await;
    }
}
