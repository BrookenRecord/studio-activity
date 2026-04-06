use axum::http::StatusCode;

#[tracing::instrument]
pub async fn health() -> StatusCode {
    StatusCode::OK
}
