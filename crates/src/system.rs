use anyhow::{Context, Result};
use std::process::{Command, Stdio};

/// Check if a command exists in `PATH`
#[must_use]
pub fn which(cmd: &str) -> bool {
    which::which(cmd).is_ok()
}

/// Set rustup default to stable (only if mise isn't managing Rust)
///
/// # Errors
/// Returns error if rustup command fails
pub fn setup_rustup() -> Result<()> {
    if !which("rustup") {
        return Ok(());
    }

    // If mise is managing Rust via RUSTUP_TOOLCHAIN, don't mess with defaults
    if std::env::var("RUSTUP_TOOLCHAIN").is_ok() {
        return Ok(());
    }

    let status = Command::new("rustup")
        .args(["default", "stable"])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .context("Failed to run rustup")?;

    if !status.success() {
        anyhow::bail!("rustup failed");
    }

    Ok(())
}
