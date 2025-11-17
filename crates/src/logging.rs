//! Logging utilities

use tracing_subscriber::{fmt, EnvFilter};

/// Initialize logging with color and level based on RUST_LOG env var
pub fn init() {
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));

    fmt()
        .with_env_filter(filter)
        .with_target(false)
        .without_time()
        .init();
}
