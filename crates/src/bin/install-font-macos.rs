//! Install fonts from URLs on macOS

use anyhow::{Context, Result};
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use std::io;
use std::process::Command;
use tempfile::TempDir;

#[derive(Parser)]
#[command(name = "install-font-macos")]
#[command(about = "Install fonts from URLs", long_about = None)]
#[command(version)]
#[command(args_conflicts_with_subcommands = true)]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,

    /// Font archive URLs
    #[arg(value_name = "URLS", required = true)]
    urls: Option<Vec<String>>,
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

    let urls = args
        .urls
        .ok_or_else(|| anyhow::anyhow!(Args::command().render_help()))?;

    println!("\n/// {}\n", "FONT INSTALLER".bold());

    let temp_dir = TempDir::new()?;
    let dest = temp_dir.path();

    println!("  {} temp dir: {}", "→".bright_black(), dest.display());

    // Download
    for url in &urls {
        println!("  {} downloading {}", "·".bright_black(), url);
        let dest_str = dest.to_str().context("Invalid temp dir path")?;
        let status = Command::new("aria2c")
            .args(["-x", "8", "-d", dest_str, url])
            .status()?;

        if !status.success() {
            anyhow::bail!("Failed to download {}", url);
        }
    }

    // Extract
    println!("  {} extracting archives", "·".bright_black());
    for entry in std::fs::read_dir(dest)? {
        let entry = entry?;
        let path = entry.path();

        if path.extension().and_then(|s| s.to_str()) == Some("zip") {
            let path_str = path.to_str().context("Invalid zip path")?;
            let dest_str = dest.to_str().context("Invalid dest path")?;
            Command::new("unzip")
                .args(["-q", path_str, "-d", dest_str])
                .status()?;
            std::fs::remove_file(&path)?;
        }
    }

    // Install fonts
    println!("  {} installing fonts", "·".bright_black());
    let fonts_dir = dirs::home_dir()
        .context("Could not determine home directory")?
        .join("Library/Fonts");

    std::fs::create_dir_all(&fonts_dir)?;

    let mut installed = 0;
    for entry in walkdir::WalkDir::new(dest) {
        let entry = entry?;
        if entry.file_type().is_file() {
            if let Some(ext) = entry.path().extension().and_then(|s| s.to_str()) {
                if is_font_extension(ext) {
                    let dest_path = fonts_dir.join(entry.file_name());
                    std::fs::copy(entry.path(), &dest_path)?;
                    installed += 1;
                }
            }
        }
    }

    println!("  {} installed {} fonts", "✓".green(), installed);

    Ok(())
}

fn is_font_extension(ext: &str) -> bool {
    ext.eq_ignore_ascii_case("otf") || ext.eq_ignore_ascii_case("ttf")
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
}
