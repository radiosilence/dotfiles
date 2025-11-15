//! Alias for git-trigger (same functionality)

use anyhow::{Context, Result};
use clap::Parser;
use colored::Colorize;
use std::process::Command;

#[derive(Parser)]
#[command(name = "git-update")]
#[command(about = "Amend and force push (alias for git-trigger)", long_about = None)]
#[command(version)]
struct Args {
    /// Dry run - show what would be done
    #[arg(short = 'n', long)]
    dry_run: bool,
}

fn main() -> Result<()> {
    let args = Args::parse();

    println!("{}", "┌──[ GIT-UPDATE ]──────────────┐".bright_magenta());
    println!("{}", "│  force push utility           │".bright_magenta());
    println!("{}", "└───────────────────────────────┘".bright_magenta());
    println!();

    if args.dry_run {
        println!("{} Would run:", "i".blue().bold());
        println!("  git commit --amend --no-edit");
        println!("  git push --force");
        return Ok(());
    }

    println!("{} Amending last commit...", "→".bright_magenta().bold());
    let status = Command::new("git")
        .args(["commit", "--amend", "--no-edit"])
        .status()
        .context("Failed to amend commit")?;

    if !status.success() {
        anyhow::bail!("Failed to amend commit");
    }

    println!("{} Force pushing...", "→".bright_magenta().bold());
    let status = Command::new("git")
        .args(["push", "--force"])
        .status()
        .context("Failed to push")?;

    if !status.success() {
        anyhow::bail!("Failed to push");
    }

    println!();
    println!("{} Force pushed", "✓".green().bold());

    Ok(())
}
