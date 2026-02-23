//! Shared utilities for dotfiles tools

pub mod audio;
pub mod install;
pub mod parallel;
pub mod regen_completions;

pub use anyhow::{Context, Result};
pub use audio::check_command;

use std::path::PathBuf;

/// Returns the user's home directory via `dirs::home_dir()`.
///
/// # Errors
/// Returns error if the home directory cannot be determined.
pub fn home_dir() -> Result<PathBuf> {
    dirs::home_dir().ok_or_else(|| anyhow::anyhow!("could not determine home directory"))
}

/// Returns the number of available CPU cores, defaulting to 1.
#[must_use]
pub fn available_cores() -> usize {
    std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(1)
}

/// Print a summary of parallel processing results.
pub fn print_results(results: &[Result<PathBuf>], verb: &str) {
    let success_count = results.iter().filter(|r| r.is_ok()).count();
    let error_count = results.len() - success_count;

    use colored::Colorize;
    if error_count > 0 {
        println!(
            "  {} {} {} files ({} failed)",
            "!".yellow(),
            verb,
            success_count,
            error_count
        );
        for result in results.iter().filter(|r| r.is_err()) {
            if let Err(e) = result {
                println!("  {} {}", "✗".red(), e);
            }
        }
    } else {
        println!("  {} {} {} files", "✓".green(), verb, success_count);
    }
}
