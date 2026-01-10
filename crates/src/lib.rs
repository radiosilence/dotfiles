//! Shared utilities for dotfiles tools

pub mod audio;
pub mod install;
pub mod parallel;
pub mod regen_completions;
pub mod update_ffmpeg;

pub use anyhow::{Context, Result};
