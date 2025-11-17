//! Shared utilities for dotfiles tools

pub mod audio;
pub mod banner;
pub mod cli;
pub mod install;
pub mod logging;
pub mod parallel;
pub mod process;
pub mod regen_completions;
pub mod system;

pub use anyhow::{Context, Result};
