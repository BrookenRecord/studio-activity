#![cfg(target_arch = "wasm32")]

#[path = "wasm/helpers.rs"]
pub mod helpers;

#[path = "wasm/error.rs"]
pub mod error;

#[path = "wasm/extractors.rs"]
pub mod extractors;

#[path = "wasm/middleware.rs"]
pub mod middleware;

#[path = "wasm/ping.rs"]
pub mod ping;

#[path = "wasm/redirect.rs"]
pub mod redirect;

#[path = "wasm/routing.rs"]
pub mod routing;
