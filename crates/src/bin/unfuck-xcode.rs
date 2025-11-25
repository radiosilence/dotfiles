//! Fix Xcode Command Line Tools issues
//!
//! Removes corrupt CLT installation and triggers reinstall

use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use dotfiles_tools::banner;
use std::io;
use std::process::Command;

#[derive(Parser)]
#[command(name = "unfuck-xcode")]
#[command(about = "Fix Xcode CLI Tools", long_about = None)]
#[command(version)]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,

    /// Dry run - show what would be done
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
            "unfuck-xcode",
            &mut io::stdout(),
        );
        return Ok(());
    }

    banner::header("XCODE UNFUCKER");

    if std::env::var("USER").unwrap_or_default() == "root" {
        banner::warn("Already running as root");
    } else {
        banner::info("Requires sudo - you'll be prompted");
    }

    if args.dry_run {
        banner::info("DRY RUN - no changes made");
        banner::status("Remove", "/Library/Developer/CommandLineTools");
        banner::status("Reset", "xcode-select");
        return Ok(());
    }

    // Remove CommandLineTools
    banner::status("Removing", "/Library/Developer/CommandLineTools");
    let status = Command::new("sudo")
        .args(["rm", "-rf", "/Library/Developer/CommandLineTools"])
        .status()?;

    if !status.success() {
        banner::err("Failed to remove CommandLineTools");
        anyhow::bail!("rm command failed");
    }

    // Reset xcode-select
    banner::status("Resetting", "xcode-select");
    let status = Command::new("sudo")
        .args(["xcode-select", "--reset"])
        .status()?;

    if !status.success() {
        banner::err("Failed to reset xcode-select");
        anyhow::bail!("xcode-select command failed");
    }

    banner::ok("Xcode unfucked - GUI installer will prompt for CLI Tools");

    Ok(())
}
