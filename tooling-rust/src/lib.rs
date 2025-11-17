//! Shared utilities for dotfiles tools

pub mod audio;
pub mod banner;
pub mod cli;
pub mod completions;
pub mod logging;
pub mod parallel;
pub mod process;

pub use anyhow::{Context, Result};
