//! Common CLI utilities

use dialoguer::Confirm;
use anyhow::Result;

/// Confirm action with user
pub fn confirm(prompt: &str) -> Result<bool> {
    Ok(Confirm::new()
        .with_prompt(prompt)
        .default(false)
        .interact()?)
}

/// Get number of CPU cores
pub fn num_cpus() -> usize {
    num_cpus::get()
}
