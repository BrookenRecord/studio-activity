#![forbid(unsafe_code)]

mod app;
mod error;
mod extractors;
mod middleware;
mod models;
mod proto;
mod routes;

use tracing_subscriber::fmt::format::Pretty;
use tracing_subscriber::fmt::time::UtcTime;
use tracing_subscriber::prelude::*;
use tracing_web::{performance_layer, MakeConsoleWriter};

use worker::*;

use crate::models::edge_context::EdgeContext;

// Multiple calls to `init` will cause a panic as a tracing subscriber is
// already set, so we use the `start` event to initialize our tracing subscriber
// when the worker starts.
#[event(start)]
fn start() {
    let fmt_layer = tracing_subscriber::fmt::layer()
        .json()
        .with_ansi(false) // Only partially supported across JavaScript runtimes
        .with_timer(UtcTime::rfc_3339()) // std::time is not available in browsers
        .with_writer(MakeConsoleWriter); // write events to the console

    let perf_layer = performance_layer().with_details_from_fields(Pretty::default());

    tracing_subscriber::registry()
        .with(fmt_layer)
        .with(perf_layer)
        .init();
}

#[event(fetch)]
async fn fetch(req: Request, env: Env, ctx: Context) -> Result<http::Response<axum::body::Body>> {
    let edge = EdgeContext::from_worker_request(&req);

    let mut http_req: http::Request<worker::Body> = req.try_into()?;
    http_req.extensions_mut().insert(edge);

    app::handle(http_req, env, ctx).await
}
