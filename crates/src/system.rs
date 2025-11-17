use anyhow::{Context, Result};
use std::process::{Command, Stdio};

/// Check if a command exists in `PATH`
#[must_use]
pub fn which(cmd: &str) -> bool {
    which::which(cmd).is_ok()
}

/// Install mise tools
///
/// # Errors
/// Returns error if mise command fails
pub fn install_mise_tools() -> Result<()> {
    if !which("mise") {
        return Ok(());
    }

    let status = Command::new("mise")
        .args(["install", "-y"])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .context("Failed to run mise install")?;

    if !status.success() {
        anyhow::bail!("mise install failed");
    }

    Ok(())
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
