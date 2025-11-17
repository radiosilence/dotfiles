//! Install fonts from URLs on macOS

use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use dotfiles_tools::banner;
use std::io;
use std::process::Command;
use tempfile::TempDir;

#[derive(Parser)]
#[command(name = "install-font-macos")]
#[command(about = "Install fonts from URLs", long_about = None)]
#[command(version)]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,

    /// Font archive URLs
    #[arg(value_name = "URLS", required = true)]
    urls: Vec<String>,
}

#[derive(Subcommand)]
enum Commands {
    /// Generate shell completions
    Completion {
        #[arg(value_enum)]
        shell: Shell,
    },
}

fn main() -> Result<()> {
    let args = Args::parse();

    if let Some(Commands::Completion { shell }) = args.command {
        generate(
            shell,
            &mut Args::command(),
            "install-font-macos",
            &mut io::stdout(),
        );
        return Ok(());
    }

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
                if is_font_extension(ext) {
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

fn is_font_extension(ext: &str) -> bool {
    matches!(ext, "otf" | "ttf" | "OTF" | "TTF")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_is_font_extension_otf() {
        assert!(is_font_extension("otf"));
        assert!(is_font_extension("OTF"));
    }

    #[test]
    fn test_is_font_extension_ttf() {
        assert!(is_font_extension("ttf"));
        assert!(is_font_extension("TTF"));
    }

    #[test]
    fn test_is_not_font_extension() {
        assert!(!is_font_extension("txt"));
        assert!(!is_font_extension("zip"));
        assert!(!is_font_extension("pdf"));
        assert!(!is_font_extension("woff"));
    }

    #[test]
    fn test_font_dir_creation() {
        // Test that we can construct the fonts directory path
        if let Some(home) = dirs::home_dir() {
            let fonts_dir = home.join("Library/Fonts");
            assert!(fonts_dir.to_str().is_some());
            assert!(fonts_dir.to_string_lossy().contains("Library"));
            assert!(fonts_dir.to_string_lossy().contains("Fonts"));
        }
    }
}
