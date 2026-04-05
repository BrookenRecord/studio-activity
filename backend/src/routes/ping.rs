use axum::{http::StatusCode, response::IntoResponse};

use crate::{
    extractors::AppJson,
    proto::api::v1::ping::{PingRequest, PingResponse},
};

#[tracing::instrument]
pub async fn ping(AppJson(payload): AppJson<PingRequest>) -> impl IntoResponse {
    let response = PingResponse {
        message: payload.message.unwrap_or_else(|| "pong".to_string()),
        timestamp: worker::Date::now().as_millis() as i64,
    };

    (StatusCode::OK, AppJson(response))
}
