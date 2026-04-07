use axum::extract::rejection::BytesRejection;
use axum::{
    extract::{FromRequest, Request},
    response::IntoResponse,
    Json,
};
use serde::de::DeserializeOwned;
use serde_json::Value;

use crate::error::AppError;

/// Drop-in replacement for [`axum::Json`] that returns structured errors
/// and normalizes Luau JSON encoding quirks before deserialization.
///
/// # Luau empty-table workaround
///
/// Luau's `HttpService:JSONEncode` cannot distinguish between an empty
/// array and an empty dictionary — both `{}` tables serialize as `[]`.
/// This means any protobuf message whose fields are all at their proto3
/// default values (e.g. `PresenceToggled { is_active: false }`) arrives
/// as `"presenceToggled": []` instead of `"presenceToggled": {}`, which
/// serde rightly rejects as a type mismatch.
///
/// To work around this, `AppJson` deserializes the body into a raw
/// [`serde_json::Value`] first, recursively replaces every empty `[]`
/// with `{}`, and only then deserializes into `T`. This is safe because
/// the protobuf JSON schema never uses empty arrays as a meaningful
/// value — an empty `repeated` field is simply omitted.
pub struct AppJson<T>(pub T);

/// Recursively replaces empty JSON arrays with empty objects to work
/// around Luau's `jsonEncode` encoding empty tables as `[]`.
fn normalize_empty_arrays(value: &mut Value) {
    match value {
        Value::Array(arr) if arr.is_empty() => {
            *value = Value::Object(serde_json::Map::new());
        }
        Value::Array(arr) => arr.iter_mut().for_each(normalize_empty_arrays),
        Value::Object(map) => map.values_mut().for_each(normalize_empty_arrays),
        _ => {}
    }
}

impl<S, T> FromRequest<S> for AppJson<T>
where
    T: DeserializeOwned,
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request(req: Request, state: &S) -> Result<Self, Self::Rejection> {
        // Validate content type
        let content_type = req
            .headers()
            .get(axum::http::header::CONTENT_TYPE)
            .and_then(|v| v.to_str().ok())
            .unwrap_or("");

        if !content_type.starts_with("application/json") {
            return Err(AppError::Validation {
                message: "Expected request with `Content-Type: application/json`".into(),
                field: None,
            });
        }

        // Extract raw bytes
        let bytes =
            axum::body::Bytes::from_request(req, state)
                .await
                .map_err(|_: BytesRejection| AppError::Validation {
                    message: "Failed to read request body".into(),
                    field: None,
                })?;

        // Parse into a generic Value, normalize, then deserialize into T
        let mut value: Value =
            serde_json::from_slice(&bytes).map_err(|err| AppError::Validation {
                message: "Request body contains invalid JSON".into(),
                field: Some(err.to_string()),
            })?;

        normalize_empty_arrays(&mut value);

        let result: T = serde_json::from_value(value).map_err(|_| AppError::Validation {
            message: "Invalid JSON fields".into(),
            field: None,
        })?;

        Ok(AppJson(result))
    }
}

impl<T: serde::Serialize> IntoResponse for AppJson<T> {
    fn into_response(self) -> axum::response::Response {
        Json(self.0).into_response()
    }
}
