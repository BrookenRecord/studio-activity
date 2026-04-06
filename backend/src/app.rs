use std::sync::Arc;

use axum::{
    middleware,
    routing::{get, post},
    Router,
};
use once_cell::sync::OnceCell;
use tower_service::Service;
use worker::{Context, Env, HttpRequest};

use crate::{error::AppError, extractors::WorkerContext, middleware as mw, routes};

static APP: OnceCell<App> = OnceCell::new();

#[derive(Clone)]
#[allow(unused)]
pub struct AppState {}

#[allow(unused)]
pub struct App {
    pub state: AppState,
    pub router: Router,
}

impl App {
    pub fn try_new(_env: &Env) -> Result<Self, AppError> {
        let state = AppState {};

        let router = build_router()
            .layer(middleware::from_fn_with_state(
                state.clone(),
                mw::request_context::layer,
            ))
            .with_state(state.clone());

        Ok(Self { state, router })
    }
}

pub fn build_router() -> Router<AppState> {
    Router::new()
        .route("/", get(routes::gh_redirect))
        .route("/health", get(routes::health))
        .route("/v1/telemetry", post(routes::telemetry))
}

pub async fn handle(
    mut req: HttpRequest,
    env: Env,
    ctx: Context,
) -> worker::Result<axum::http::Response<axum::body::Body>> {
    let app = APP.get_or_try_init(|| {
        App::try_new(&env).map_err(|e| worker::Error::JsError(e.to_string()))
    })?;

    req.extensions_mut().insert(env);
    req.extensions_mut().insert(WorkerContext(Arc::new(ctx)));
    Ok(app.router.clone().call(req).await?)
}
