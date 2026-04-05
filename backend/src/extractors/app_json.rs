use axum::extract::rejection::JsonRejection;
use axum::{
    extract::{FromRequest, Request},
    response::IntoResponse,
    Json,
};

use crate::error::AppError;

/// Drop-in replacement for `axum::Json` that returns structured errors.
pub struct AppJson<T>(pub T);

impl<S, T> FromRequest<S> for AppJson<T>
where
    Json<T>: FromRequest<S, Rejection = JsonRejection>,
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request(req: Request, state: &S) -> Result<Self, Self::Rejection> {
        let Json(value) = Json::<T>::from_request(req, state)
            .await
            .map_err(|rejection| {
                // Map each rejection variant to a client-safe message
                let message = match &rejection {
                    JsonRejection::MissingJsonContentType(_) => {
                        "Expected request with `Content-Type: application/json`".into()
                    }
                    JsonRejection::JsonDataError(e) => {
                        format!("Invalid JSON fields: {e}")
                    }
                    JsonRejection::JsonSyntaxError(_) => {
                        "Request body contains invalid JSON".into()
                    }
                    JsonRejection::BytesRejection(_) => "Failed to read request body".into(),
                    _ => "Unknown request error".into(),
                };

                AppError::Validation {
                    message,
                    field: None,
                }
            })?;

        Ok(AppJson(value))
    }
}

// So handlers can return AppJson the same way they return Json
impl<T: serde::Serialize> IntoResponse for AppJson<T> {
    fn into_response(self) -> axum::response::Response {
        Json(self.0).into_response()
    }
}
