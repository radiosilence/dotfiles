//! Common CLI utilities

use anyhow::Result;
use dialoguer::Confirm;

/// Confirm action with user
///
/// # Errors
/// Returns error if interaction with terminal fails
pub fn confirm(prompt: &str) -> Result<bool> {
    Ok(Confirm::new()
        .with_prompt(prompt)
        .default(false)
        .interact()?)
}

/// Get number of CPU cores
#[must_use]
pub fn num_cpus() -> usize {
    num_cpus::get()
}
