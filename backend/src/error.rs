use axum::{
    http::StatusCode,
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
        tracing::error!(error=?self, "internal error");

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
        };

        (status, Json(problem)).into_response()
    }
}
