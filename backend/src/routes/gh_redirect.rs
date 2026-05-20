use axum::extract::Request;
use axum::http::{header, HeaderMap, HeaderValue};
use axum::response::{IntoResponse, Redirect, Response};
use worker::send::SendFuture;

use crate::extractors::{Edge, WorkerContext};
use crate::posthog;

const DEFAULT_POSTHOG_HOST: &str = "https://us.i.posthog.com";
const GITHUB_REPO_URL: &str = "https://github.com/BrookenRecord/studio-activity";

#[allow(clippy::must_use_candidate)]
#[tracing::instrument(
    skip(req),
    fields(
        utm_source = tracing::field::Empty,
        referring_domain = tracing::field::Empty
    )
)]
pub fn gh_redirect(
    Edge(edge): Edge,
    req: Request,
) -> SendFuture<impl std::future::Future<Output = Response>> {
    SendFuture::new(async move {
        let mut redirect = Redirect::temporary(GITHUB_REPO_URL).into_response();
        redirect
            .headers_mut()
            .insert(header::CACHE_CONTROL, HeaderValue::from_static("no-store"));

        let headers: HeaderMap = req.headers().clone();
        let env = req.extensions().get::<worker::Env>().cloned();
        let ctx = req.extensions().get::<WorkerContext>().cloned();
        let (Some(env), Some(WorkerContext(ctx_arc))) = (env, ctx) else {
            return redirect;
        };

        let posthog_host = env
            .var("POSTHOG_HOST")
            .map_or_else(|_| DEFAULT_POSTHOG_HOST.to_string(), |v| v.to_string());

        let api_key = match env.secret("POSTHOG_API_KEY") {
            Ok(key) => key.to_string(),
            Err(e) => {
                tracing::error!(error = %e, "POSTHOG_API_KEY secret not configured");
                return redirect;
            }
        };

        let public_url = match env.var("BACKEND_PUBLIC_URL") {
            Ok(url) => url.to_string(),
            Err(e) => {
                tracing::warn!(error = %e, "BACKEND_PUBLIC_URL var not configured");
                return redirect;
            }
        };

        let path_and_query = req.uri().path_and_query().map_or("/", |pq| pq.as_str());
        let current_url = format!("{}{}", public_url.trim_end_matches('/'), path_and_query);

        let referrer = headers
            .get(header::REFERER)
            .and_then(|value| value.to_str().ok())
            .map(ToOwned::to_owned);

        let user_agent = headers
            .get(header::USER_AGENT)
            .and_then(|value| value.to_str().ok())
            .map(ToOwned::to_owned);

        // Optional secret salt for deterministic anonymous distinct ids.
        // If unset, we intentionally use per-request random IDs.
        let distinct_id_salt = match env.secret("POSTHOG_DISTINCT_ID_SALT") {
            Ok(value) => Some(value.to_string()),
            Err(e) => {
                tracing::warn!(
                    error = %e,
                    "POSTHOG_DISTINCT_ID_SALT not configured; using per-request random anonymous distinct_id"
                );
                None
            }
        };

        let client_ip = edge.client_ip;
        let payload = posthog::build_pageview_payload(
            &api_key,
            distinct_id_salt.as_deref(),
            &current_url,
            referrer.as_deref(),
            user_agent.as_deref(),
            client_ip.as_deref(),
        );

        let props = payload
            .get("properties")
            .and_then(|value| value.as_object());
        if let Some(utm_source) = props
            .and_then(|properties| properties.get("utm_source"))
            .and_then(|value| value.as_str())
        {
            tracing::Span::current().record("utm_source", utm_source);
        }
        if let Some(domain) = props
            .and_then(|properties| properties.get("$referring_domain"))
            .and_then(|value| value.as_str())
        {
            tracing::Span::current().record("referring_domain", domain);
        }

        ctx_arc.wait_until(async move {
            posthog::forward_payload(&posthog_host, &payload).await;
        });

        redirect
    })
}
