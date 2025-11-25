//! Shared utilities for dotfiles tools

pub mod audio;
pub mod banner;
pub mod install;
pub mod parallel;
pub mod regen_completions;

pub use anyhow::{Context, Result};
