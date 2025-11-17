//! Import music from URLs
//!
//! Downloads music archives, extracts them, and imports to beets library

use anyhow::Result;
use clap::Parser;
use dotfiles_tools::completions;
use dotfiles_tools::banner;
use std::process::Command;
use tempfile::TempDir;

#[derive(Parser)]
#[command(name = "imp")]
#[command(about = "Import music from URLs", long_about = None)]
#[command(version)]
struct Args {
    /// URLs to download and import
    #[arg(value_name = "URLS", required = true)]
    urls: Vec<String>,
}

fn main() -> Result<()> {
    if completions::handle_completion_flag::<Args>() {
        return Ok(());
    }

    let args = Args::parse();

    banner::print_banner(
        "MUSIC IMPORTER",
        "download + extract + beets import",
        "green",
    );

    // Create temp dir
    let temp_dir = TempDir::new()?;
    let dest = temp_dir.path();

    banner::status("□", "DOWNLOAD DIR", &dest.display().to_string(), "green");
    banner::divider("green");
    println!();

    // Download with aria2c
    banner::loading("Downloading archives...");
    for url in &args.urls {
        let status = Command::new("aria2c")
            .args(["-x", "8", "-d", dest.to_str().unwrap(), url])
            .status()?;

        if !status.success() {
            anyhow::bail!("Failed to download {}", url);
        }
    }

    // Extract archives
    banner::loading("Extracting archives...");
    for entry in std::fs::read_dir(dest)? {
        let entry = entry?;
        let path = entry.path();

        if path.extension().and_then(|s| s.to_str()) == Some("zip") {
            let status = Command::new("unzip")
                .args(["-q", path.to_str().unwrap(), "-d", dest.to_str().unwrap()])
                .status()?;

            if status.success() {
                std::fs::remove_file(&path)?;
            }
        }
    }

    // Show tree
    println!();
    let _ = Command::new("lsd")
        .args(["--tree", dest.to_str().unwrap()])
        .status()
        .or_else(|_| Command::new("tree").arg(dest.to_str().unwrap()).status());

    println!();
    banner::loading("Importing to beets...");

    // Import to beets
    let status = Command::new("beet")
        .args(["import", dest.to_str().unwrap()])
        .status()?;

    if !status.success() {
        anyhow::bail!("Beets import failed");
    }

    banner::success("IMPORT COMPLETE");

    Ok(())
}
