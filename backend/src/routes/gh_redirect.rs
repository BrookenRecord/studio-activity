use axum::response::Redirect;

#[tracing::instrument]
pub async fn gh_redirect() -> Redirect {
    Redirect::permanent("https://github.com/grilme99/studio-activity")
}
