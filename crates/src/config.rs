use anyhow::Context;
use serde::Deserialize;
use std::fs;

use crate::Result;

#[derive(Deserialize, Default)]
pub struct DotfilesConfig {
    #[serde(default)]
    pub completions: CompletionsConfig,
    #[serde(default)]
    pub fonts: Vec<Font>,
}

#[derive(Deserialize, Clone)]
pub struct Font {
    pub name: String,
    pub url: String,
    pub marker_file: String,
}

#[derive(Deserialize, Default)]
pub struct CompletionsConfig {
    #[serde(default)]
    pub tools: Vec<CompletionTool>,
}

#[derive(Deserialize, Clone)]
pub struct CompletionTool {
    pub name: String,
    pub command: Option<Vec<String>>,
    #[serde(rename = "type")]
    pub tool_type: Option<String>,
    /// For "prebuilt": path relative to binary location
    pub source: Option<String>,
    /// For "sourced": output path relative to ~/.dotfiles
    pub output: Option<String>,
}

impl DotfilesConfig {
    pub fn load() -> Result<Self> {
        let home = crate::home_dir()?;
        let dotfiles = home.join(".dotfiles");
        let path = dotfiles.join("dotfiles.toml");
        let template_path = dotfiles.join("dotfiles.toml.template");

        let content = match fs::read_to_string(&path) {
            Ok(s) => s,
            Err(_) => fs::read_to_string(&template_path)
                .with_context(|| "Failed to read dotfiles.toml or dotfiles.toml.template")?,
        };

        let config: Self =
            toml::from_str(&content).with_context(|| "Failed to parse dotfiles config")?;
        Ok(config)
    }
}
