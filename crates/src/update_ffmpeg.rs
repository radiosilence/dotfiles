//! Update ffmpeg build URLs in mise config
//!
//! Scrapes martin-riedl.de for latest ffmpeg builds and updates
//! the mise config.toml with new download URLs.

use anyhow::{Context, Result};
use colored::Colorize;
use regex::Regex;
use scraper::{Html, Selector};
use std::fs;
use std::path::PathBuf;
use toml_edit::{DocumentMut, Item, Value};

#[derive(Debug)]
pub struct BuildInfo {
    pub version: String,
    pub timestamp: String,
}

pub fn expand_path(path: &str) -> PathBuf {
    if path.starts_with("~/") {
        dirs::home_dir()
            .map(|h| h.join(&path[2..]))
            .unwrap_or_else(|| PathBuf::from(path))
    } else {
        PathBuf::from(path)
    }
}

pub fn fetch_build_info(platform: &str, arch: &str, use_snapshot: bool) -> Result<BuildInfo> {
    let url = "https://ffmpeg.martin-riedl.de/";

    let html = reqwest::blocking::get(url)
        .context("Failed to fetch build info page")?
        .text()
        .context("Failed to read response")?;

    let document = Html::parse_document(&html);

    let link_selector = Selector::parse("a[href]").unwrap();

    let version_pattern = if use_snapshot {
        r"N-[^/]+"
    } else {
        r"\d+\.\d+(?:\.\d+)?"
    };

    let pattern = format!(r"/download/{platform}/{arch}/(\d+)_({version_pattern})/ffmpeg\.zip");
    let re = Regex::new(&pattern).unwrap();

    for element in document.select(&link_selector) {
        if let Some(href) = element.value().attr("href") {
            if let Some(caps) = re.captures(href) {
                return Ok(BuildInfo {
                    timestamp: caps[1].to_string(),
                    version: caps[2].to_string(),
                });
            }
        }
    }

    anyhow::bail!("Could not find build info for {platform}/{arch}")
}

pub fn build_url(platform: &str, arch: &str, info: &BuildInfo) -> String {
    format!(
        "https://ffmpeg.martin-riedl.de/download/{platform}/{arch}/{}_{}/ffmpeg.zip",
        info.timestamp, info.version
    )
}

pub fn update_config(
    config_path: &PathBuf,
    builds: &[(String, String, BuildInfo)],
    dry_run: bool,
) -> Result<()> {
    let content = fs::read_to_string(config_path).context("Failed to read config file")?;

    let mut doc = content
        .parse::<DocumentMut>()
        .context("Failed to parse TOML")?;

    if let Some(first_build) = builds.first() {
        if let Some(Item::Table(table)) =
            doc.get_mut("tools").and_then(|t| t.get_mut("http:ffmpeg"))
        {
            table["version"] = toml_edit::value(&first_build.2.version);
        }
    }

    if let Some(Item::Table(plat_table)) = doc
        .get_mut("tools")
        .and_then(|t| t.get_mut("http:ffmpeg"))
        .and_then(|f| {
            if let Item::Table(t) = f {
                t.get_mut("platforms")
            } else {
                None
            }
        })
    {
        for (platform, arch, info) in builds {
            let mise_platform = match (platform.as_str(), arch.as_str()) {
                ("macos", "arm64") => "macos-arm64",
                ("macos", "amd64") => "macos-x64",
                ("linux", "amd64") => "linux-x64",
                ("linux", "arm64v8") => "linux-arm64",
                _ => continue,
            };

            if let Some(Item::Value(Value::InlineTable(inline))) = plat_table.get_mut(mise_platform)
            {
                let url = build_url(platform, arch, info);
                inline.insert("url", url.into());
            }
        }
    }

    if dry_run {
        println!("\n{}", "Dry run - would write:".yellow());
        println!("{doc}");
    } else {
        fs::write(config_path, doc.to_string()).context("Failed to write config file")?;
    }

    Ok(())
}

/// Update ffmpeg URLs in mise config, returns true if updated
pub fn update_ffmpeg(use_snapshot: bool) -> Result<bool> {
    let config_path = expand_path("~/.config/mise/config.toml");

    let platforms = [("macos", "arm64"), ("linux", "amd64")];

    let mut builds = Vec::new();

    for (platform, arch) in &platforms {
        if let Ok(info) = fetch_build_info(platform, arch, use_snapshot) {
            builds.push((platform.to_string(), arch.to_string(), info));
        }
    }

    if builds.is_empty() {
        return Ok(false);
    }

    update_config(&config_path, &builds, false)?;
    Ok(true)
}
