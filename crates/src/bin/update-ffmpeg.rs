//! Update ffmpeg build URLs in mise config
//!
//! Scrapes martin-riedl.de for latest ffmpeg builds and updates
//! the mise config.toml with new download URLs.

use anyhow::{Context, Result};
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use regex::Regex;
use scraper::{Html, Selector};
use std::fs;
use std::io;
use std::path::PathBuf;
use toml_edit::{DocumentMut, Item, Value};

#[derive(Parser)]
#[command(name = "update-ffmpeg")]
#[command(about = "Update ffmpeg build URLs in mise config", long_about = None)]
#[command(version)]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,

    /// Path to mise config.toml
    #[arg(short, long, default_value = "~/.config/mise/config.toml")]
    config: String,

    /// Use snapshot builds instead of release
    #[arg(short, long)]
    snapshot: bool,

    /// Dry run - don't write changes
    #[arg(short = 'n', long)]
    dry_run: bool,
}

#[derive(Subcommand)]
enum Commands {
    /// Generate shell completions
    Completion {
        #[arg(value_enum)]
        shell: Shell,
    },
}

#[derive(Debug)]
struct BuildInfo {
    version: String,
    timestamp: String,
}

fn expand_path(path: &str) -> PathBuf {
    if path.starts_with("~/") {
        dirs::home_dir()
            .map(|h| h.join(&path[2..]))
            .unwrap_or_else(|| PathBuf::from(path))
    } else {
        PathBuf::from(path)
    }
}

fn fetch_build_info(platform: &str, arch: &str, use_snapshot: bool) -> Result<BuildInfo> {
    let url = "https://ffmpeg.martin-riedl.de/";

    let html = reqwest::blocking::get(url)
        .context("Failed to fetch build info page")?
        .text()
        .context("Failed to read response")?;

    let document = Html::parse_document(&html);

    // Find the download link for this platform/arch
    // Links look like: /download/macos/arm64/1766430132_8.0.1/ffmpeg.zip
    let link_selector = Selector::parse("a[href]").unwrap();

    // Pattern for release versions (e.g., 8.0.1) vs snapshots (e.g., N-122320-g38e89fe502)
    let version_pattern = if use_snapshot {
        r"N-[^/]+" // Snapshot versions start with N-
    } else {
        r"\d+\.\d+(?:\.\d+)?" // Release versions like 8.0.1 or 8.0
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

fn build_url(platform: &str, arch: &str, info: &BuildInfo) -> String {
    format!(
        "https://ffmpeg.martin-riedl.de/download/{platform}/{arch}/{}_{}/ffmpeg.zip",
        info.timestamp, info.version
    )
}

fn update_config(
    config_path: &PathBuf,
    builds: &[(String, String, BuildInfo)],
    dry_run: bool,
) -> Result<()> {
    let content = fs::read_to_string(config_path).context("Failed to read config file")?;

    let mut doc = content
        .parse::<DocumentMut>()
        .context("Failed to parse TOML")?;

    // Update version
    if let Some(first_build) = builds.first() {
        if let Some(Item::Table(table)) =
            doc.get_mut("tools").and_then(|t| t.get_mut("http:ffmpeg"))
        {
            table["version"] = toml_edit::value(&first_build.2.version);
        }
    }

    // Update platform URLs
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
        println!("  {} Updated {}", "✓".green(), config_path.display());
    }

    Ok(())
}

fn main() -> Result<()> {
    let args = Args::parse();

    if let Some(Commands::Completion { shell }) = args.command {
        generate(
            shell,
            &mut Args::command(),
            "update-ffmpeg",
            &mut io::stdout(),
        );
        return Ok(());
    }

    let config_path = expand_path(&args.config);

    println!("\n/// {}\n", "UPDATE-FFMPEG".bold());

    let build_type = if args.snapshot { "snapshot" } else { "release" };
    println!("  {} Fetching {} builds...", "→".bright_black(), build_type);

    // Platforms we care about
    let platforms = [("macos", "arm64"), ("linux", "amd64")];

    let mut builds = Vec::new();

    for (platform, arch) in &platforms {
        match fetch_build_info(platform, arch, args.snapshot) {
            Ok(info) => {
                println!(
                    "  {} {}/{}: {} ({})",
                    "·".bright_black(),
                    platform,
                    arch,
                    info.version.cyan(),
                    info.timestamp.bright_black()
                );
                builds.push((platform.to_string(), arch.to_string(), info));
            }
            Err(e) => {
                println!("  {} {}/{}: {}", "!".yellow(), platform, arch, e);
            }
        }
    }

    if builds.is_empty() {
        anyhow::bail!("No builds found");
    }

    println!();
    update_config(&config_path, &builds, args.dry_run)?;

    if !args.dry_run {
        println!(
            "\n  {} Run 'mise install http:ffmpeg' to update",
            "→".bright_black()
        );
    }

    Ok(())
}
