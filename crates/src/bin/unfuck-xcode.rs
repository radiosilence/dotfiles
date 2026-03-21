//! Fix Xcode Command Line Tools issues
//!
//! Removes corrupt CLT installation and triggers reinstall

use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
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

    println!("\n  {} {}\n", "⟢".magenta().bold(), "xcode unfucker".bold());

    if std::env::var("USER").unwrap_or_default() == "root" {
        println!("  {} Already running as root", "".yellow());
    } else {
        println!(
            "  {} Requires sudo - you'll be prompted",
            "→".cyan()
        );
    }

    if args.dry_run {
        println!("  {} DRY RUN - no changes made", "→".cyan());
        println!(
            "  {} Remove: /Library/Developer/CommandLineTools",
            "→".cyan()
        );
        println!("  {} Reset: xcode-select", "→".cyan());
        return Ok(());
    }

    // Remove CommandLineTools
    println!(
        "  {} Removing: /Library/Developer/CommandLineTools",
        "→".cyan()
    );
    let status = Command::new("sudo")
        .args(["rm", "-rf", "/Library/Developer/CommandLineTools"])
        .status()?;

    if !status.success() {
        println!("  {} Failed to remove CommandLineTools", "󰅖".red());
        anyhow::bail!("rm command failed");
    }

    // Reset xcode-select
    println!("  {} Resetting: xcode-select", "→".cyan());
    let status = Command::new("sudo")
        .args(["xcode-select", "--reset"])
        .status()?;

    if !status.success() {
        println!("  {} Failed to reset xcode-select", "󰅖".red());
        anyhow::bail!("xcode-select command failed");
    }

    println!(
        "  {} Xcode unfucked - GUI installer will prompt for CLI Tools",
        "󰄬".green()
    );

    Ok(())
}
