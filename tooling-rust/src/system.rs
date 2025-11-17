use anyhow::{Context, Result};
use colored::Colorize;
use std::process::{Command, Stdio};

/// Check if a command exists in PATH
pub fn which(cmd: &str) -> bool {
    Command::new("which")
        .arg(cmd)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

/// Install mise tools
pub fn install_mise_tools() -> Result<()> {
    if !which("mise") {
        println!("   {} mise not found, skipping", "⚠".yellow());
        return Ok(());
    }

    println!("   {} installing mise tools...", "→".yellow());
    let status = Command::new("mise")
        .args(["install", "-y"])
        .stdin(Stdio::inherit())
        .status()
        .context("Failed to run mise install")?;

    if status.success() {
        println!("   {} mise tools installed", "✓".green());
    } else {
        println!("   {} mise install failed", "⚠".yellow());
    }

    Ok(())
}

/// Set rustup default to stable (only if mise isn't managing Rust)
pub fn setup_rustup() -> Result<()> {
    if !which("rustup") {
        println!("   {} rustup not found, skipping", "⚠".yellow());
        return Ok(());
    }

    // If mise is managing Rust via RUSTUP_TOOLCHAIN, don't mess with defaults
    if std::env::var("RUSTUP_TOOLCHAIN").is_ok() {
        println!("   {} rustup managed by mise, skipping", "✓".green());
        return Ok(());
    }

    println!("   {} setting default Rust toolchain...", "→".red());
    let status = Command::new("rustup")
        .args(["default", "stable"])
        .stdout(Stdio::null())
        .status()
        .context("Failed to run rustup")?;

    if status.success() {
        println!("   {} rustup default stable", "✓".green());
    } else {
        println!("   {} rustup failed", "⚠".yellow());
    }

    Ok(())
}
