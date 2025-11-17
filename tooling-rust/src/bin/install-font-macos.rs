//! Install fonts from URLs on macOS

use anyhow::Result;
use clap::Parser;
use colored::Colorize;
use dotfiles_tools::banner;
use dotfiles_tools::completions;
use std::process::Command;
use tempfile::TempDir;

#[derive(Parser)]
#[command(name = "install-font-macos")]
#[command(about = "Install fonts from URLs", long_about = None)]
#[command(version)]
struct Args {
    /// Font archive URLs
    #[arg(value_name = "URLS", required = true)]
    urls: Vec<String>,
}

fn main() -> Result<()> {
    if completions::handle_completion_flag::<Args>() {
        return Ok(());
    }

    let args = Args::parse();

    banner::print_banner(
        "FONT INSTALLER",
        "download + extract + install fonts",
        "magenta",
    );

    let temp_dir = TempDir::new()?;
    let dest = temp_dir.path();

    banner::status("□", "TEMP DIR", &dest.display().to_string(), "magenta");
    banner::divider("magenta");
    println!();

    // Download
    banner::loading("Downloading fonts...");
    for url in &args.urls {
        let status = Command::new("aria2c")
            .args(["-x", "8", "-d", dest.to_str().unwrap(), url])
            .status()?;

        if !status.success() {
            anyhow::bail!("Failed to download {}", url);
        }
    }

    // Extract
    banner::loading("Extracting archives...");
    for entry in std::fs::read_dir(dest)? {
        let entry = entry?;
        let path = entry.path();

        if path.extension().and_then(|s| s.to_str()) == Some("zip") {
            Command::new("unzip")
                .args(["-q", path.to_str().unwrap(), "-d", dest.to_str().unwrap()])
                .status()?;
            std::fs::remove_file(&path)?;
        }
    }

    // Install fonts
    banner::loading("Installing fonts...");
    let fonts_dir = dirs::home_dir().unwrap().join("Library/Fonts");

    std::fs::create_dir_all(&fonts_dir)?;

    let mut installed = 0;
    for entry in walkdir::WalkDir::new(dest) {
        let entry = entry?;
        if entry.file_type().is_file() {
            if let Some(ext) = entry.path().extension().and_then(|s| s.to_str()) {
                if matches!(ext, "otf" | "ttf" | "OTF" | "TTF") {
                    let dest_path = fonts_dir.join(entry.file_name());
                    std::fs::copy(entry.path(), &dest_path)?;
                    println!(
                        "   {} {}",
                        "→".bright_black(),
                        entry.file_name().to_string_lossy().white()
                    );
                    installed += 1;
                }
            }
        }
    }

    banner::success(&format!("INSTALLED {} FONTS", installed));

    Ok(())
}
