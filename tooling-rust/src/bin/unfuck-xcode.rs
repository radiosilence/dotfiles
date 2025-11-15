//! Fix Xcode Command Line Tools issues
//!
//! Removes corrupt CLT installation and triggers reinstall

use anyhow::Result;
use clap::Parser;
use colored::Colorize;
use dotfiles_tools::banner;
use std::process::Command;

#[derive(Parser)]
#[command(name = "unfuck-xcode")]
#[command(about = "Fix Xcode CLI Tools", long_about = None)]
#[command(version)]
struct Args {
    /// Dry run - show what would be done
    #[arg(short = 'n', long)]
    dry_run: bool,
}

fn main() -> Result<()> {
    let args = Args::parse();

    banner::print_banner("XCODE UNFUCKER", "remove corrupt CLI tools", "red");

    if std::env::var("USER").unwrap_or_default() == "root" {
        banner::warning("Already running as root");
    } else {
        banner::warning("Requires sudo - you'll be prompted");
    }

    println!();
    banner::status(
        "□",
        "ACTION",
        "Remove /Library/Developer/CommandLineTools",
        "red",
    );
    banner::status("□", "ACTION", "Reset xcode-select", "red");
    banner::status("□", "RESULT", "Triggers GUI reinstall prompt", "yellow");
    banner::divider("red");
    println!();

    if args.dry_run {
        banner::loading("DRY RUN - no changes made");
        return Ok(());
    }

    // Remove CommandLineTools
    banner::loading("Removing CommandLineTools...");
    let status = Command::new("sudo")
        .args(["rm", "-rf", "/Library/Developer/CommandLineTools"])
        .status()?;

    if !status.success() {
        anyhow::bail!("Failed to remove CommandLineTools");
    }

    // Reset xcode-select
    banner::loading("Resetting xcode-select...");
    let status = Command::new("sudo")
        .args(["xcode-select", "--reset"])
        .status()?;

    if !status.success() {
        anyhow::bail!("Failed to reset xcode-select");
    }

    banner::success("XCODE UNFUCKED");
    println!();
    println!(
        "   {} GUI installer will prompt for CLI Tools",
        "!".yellow().bold()
    );

    Ok(())
}
