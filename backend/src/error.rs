use axum::{
    http::{header::RETRY_AFTER, HeaderValue, StatusCode},
    response::{IntoResponse, Response},
    Json,
};
use serde::Serialize;

#[derive(Debug, thiserror::Error)]
#[allow(unused)]
pub enum AppError {
    #[error("Validation failed: {message}")]
    Validation {
        message: String,       // safe for client
        field: Option<String>, // safe for client
    },

    #[error("Resource not found")]
    NotFound {
        resource_type: String, // safe for client
        resource_id: String,   // safe for client
    },

    #[error("Authentication required")]
    Unauthorized,

    #[error("Insufficient permissions")]
    Forbidden,

    #[error("Request body is too large")]
    PayloadTooLarge { limit_bytes: usize },

    #[error("Too many requests")]
    TooManyRequests { retry_after_seconds: u64 },

    // #[error("Database error: {source}")]
    // Database {
    //     #[source]
    //     source: SomeDbError, // INTERNAL ONLY
    //     operation: String, // for logs
    // },
    #[error("External service error: {service}")]
    ExternalService {
        service: String, // for logs
        #[source]
        source: Box<dyn std::error::Error + Send + Sync>,
        status_hint: Option<StatusCode>, // for logs
    },

    #[error("Internal error: {context}")]
    Internal {
        context: String, // for logs
        #[source]
        source: Option<Box<dyn std::error::Error + Send + Sync>>,
    },
}

/// What the client sees. Never contains stack traces, SQL, or internal IDs.
#[derive(Serialize)]
struct ProblemDetail {
    r#type: &'static str, // URI identifying the error class
    title: &'static str,  // short, stable, human-readable
    status: u16,
    #[serde(skip_serializing_if = "Option::is_none")]
    detail: Option<String>, // per-occurrence explanation
    #[serde(skip_serializing_if = "Option::is_none")]
    instance: Option<String>, // request-specific URI
}

impl IntoResponse for AppError {
    fn into_response(self) -> Response {
        match &self {
            AppError::Validation { .. } => tracing::debug!(error=?self, "validation error"),
            AppError::NotFound { .. } => tracing::debug!(error=?self, "not found"),
            AppError::Unauthorized => tracing::info!(error=?self, "unauthorized"),
            AppError::Forbidden => tracing::info!(error=?self, "forbidden"),
            AppError::PayloadTooLarge { .. } => tracing::info!(error=?self, "payload too large"),
            AppError::TooManyRequests { .. } => tracing::info!(error=?self, "rate limited"),
            _ => tracing::error!(error=?self, "internal error"),
        }

        let retry_after = match &self {
            AppError::TooManyRequests {
                retry_after_seconds,
            } => Some(*retry_after_seconds),
            _ => None,
        };

        #[allow(unused_variables)]
        let (status, problem) = match &self {
            AppError::Validation { message, field } => (
                StatusCode::BAD_REQUEST,
                ProblemDetail {
                    r#type: "/errors/validation",
                    title: "Validation Error",
                    status: 400,
                    detail: Some(message.clone()),
                    instance: None,
                },
            ),
            AppError::NotFound { resource_type, .. } => (
                StatusCode::NOT_FOUND,
                ProblemDetail {
                    r#type: "/errors/not-found",
                    title: "Not Found",
                    status: 404,
                    detail: Some(format!("{resource_type} not found")),
                    instance: None,
                },
            ),
            // Database, ExternalService, Internal → all map to 500
            // with a GENERIC public message
            // AppError::Database { .. }
            AppError::ExternalService { .. } | AppError::Internal { .. } => (
                StatusCode::INTERNAL_SERVER_ERROR,
                ProblemDetail {
                    r#type: "/errors/internal",
                    title: "Internal Server Error",
                    status: 500,
                    detail: None, // intentionally blank
                    instance: None,
                },
            ),
            AppError::Unauthorized => (
                StatusCode::UNAUTHORIZED,
                ProblemDetail {
                    r#type: "/errors/unauthorized",
                    title: "Authentication Required",
                    status: 401,
                    detail: None,
                    instance: None,
                },
            ),
            AppError::Forbidden => (
                StatusCode::FORBIDDEN,
                ProblemDetail {
                    r#type: "/errors/forbidden",
                    title: "Forbidden",
                    status: 403,
                    detail: None,
                    instance: None,
                },
            ),
            AppError::PayloadTooLarge { .. } => (
                StatusCode::PAYLOAD_TOO_LARGE,
                ProblemDetail {
                    r#type: "/errors/payload-too-large",
                    title: "Payload Too Large",
                    status: 413,
                    detail: Some("Request body is too large".into()),
                    instance: None,
                },
            ),
            AppError::TooManyRequests { .. } => (
                StatusCode::TOO_MANY_REQUESTS,
                ProblemDetail {
                    r#type: "/errors/rate-limited",
                    title: "Too Many Requests",
                    status: 429,
                    detail: Some("Too many requests. Slow down.".into()),
                    instance: None,
                },
            ),
        };

        let mut response = (status, Json(problem)).into_response();

        if let Some(retry_after) = retry_after {
            if let Ok(value) = HeaderValue::from_str(&retry_after.to_string()) {
                response.headers_mut().insert(RETRY_AFTER, value);
            }
        }

        response
    }
}
