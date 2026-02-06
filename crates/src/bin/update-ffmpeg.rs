//! Update ffmpeg build URLs in mise config
//!
//! Thin CLI wrapper around dotfiles_tools::update_ffmpeg

use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use dotfiles_tools::update_ffmpeg;
use std::io;

#[derive(Parser)]
#[command(name = "update-ffmpeg")]
#[command(about = "Update ffmpeg build URLs in mise config", long_about = None)]
#[command(version)]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,

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

    println!("\n/// {}\n", "UPDATE-FFMPEG".bold());

    let build_type = if args.snapshot { "snapshot" } else { "release" };
    println!("  {} Fetching {} builds...", "→".bright_black(), build_type);

    let config_path = update_ffmpeg::expand_path("~/.config/mise/config.toml");
    let platforms = [("macos", "arm64"), ("macos", "amd64"), ("linux", "amd64")];

    // Fetch once and reuse the HTML
    let html = update_ffmpeg::fetch_build_page()?;

    let mut builds = Vec::new();
    for (platform, arch) in &platforms {
        match update_ffmpeg::parse_build_info(&html, platform, arch, args.snapshot) {
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
    update_ffmpeg::update_config(&config_path, &builds, args.dry_run)?;

    if !args.dry_run {
        println!(
            "\n  {} Run 'mise install http:ffmpeg' to update",
            "→".bright_black()
        );
    }

    Ok(())
}
