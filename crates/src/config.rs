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

        let base_path = dotfiles.join("dotfiles.toml");
        let local_path = dotfiles.join("dotfiles.local.toml");

        let mut base: toml::Value = toml::from_str(
            &fs::read_to_string(&base_path).with_context(|| "Failed to read dotfiles.toml")?,
        )
        .with_context(|| "Failed to parse dotfiles.toml")?;

        // Merge local overrides if present
        if let Ok(local_str) = fs::read_to_string(&local_path) {
            let local: toml::Value = toml::from_str(&local_str)
                .with_context(|| "Failed to parse dotfiles.local.toml")?;
            merge_toml(&mut base, local);
        }

        let config: Self = base
            .try_into()
            .with_context(|| "Failed to deserialize merged dotfiles config")?;
        Ok(config)
    }
}

/// Deep-merge `override_val` into `base`. Arrays are concatenated, tables are recursively merged.
fn merge_toml(base: &mut toml::Value, override_val: toml::Value) {
    match (base, override_val) {
        (toml::Value::Table(base_table), toml::Value::Table(override_table)) => {
            for (key, val) in override_table {
                if let Some(existing) = base_table.get_mut(&key) {
                    merge_toml(existing, val);
                } else {
                    base_table.insert(key, val);
                }
            }
        }
        (toml::Value::Array(base_arr), toml::Value::Array(override_arr)) => {
            base_arr.extend(override_arr);
        }
        (base, override_val) => {
            *base = override_val;
        }
    }
}
