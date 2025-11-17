//! Clean up local branches whose remotes have been deleted
//!
//! After PRs are merged and remote branches deleted, this cleans up
//! the stale local tracking branches.

use anyhow::{Context, Result};
use clap::Parser;
use colored::Colorize;
use dialoguer::Confirm;
use std::process::Command;

#[derive(Parser)]
#[command(name = "git-sync")]
#[command(about = "Clean up merged branches", long_about = None)]
#[command(version)]
struct Args {
    /// Delete without confirmation
    #[arg(short = 'y', long)]
    yes: bool,
}

fn main() -> Result<()> {
    let args = Args::parse();

    println!("{}", "═══════════════════════════════════".bright_yellow());
    println!("{}", "  GIT-SYNC // branch cleanup util  ".bright_yellow());
    println!("{}", "═══════════════════════════════════".bright_yellow());
    println!();

    // Prune remote tracking branches
    println!(
        "{} Pruning remote tracking branches...",
        "→".bright_yellow().bold()
    );
    Command::new("git")
        .args(["remote", "prune", "origin"])
        .status()
        .context("Failed to prune remote")?;

    // Fetch updates
    println!("{} Fetching updates...", "→".bright_yellow().bold());
    Command::new("git")
        .args(["fetch", "--all"])
        .status()
        .context("Failed to fetch")?;

    // Find branches with deleted remotes
    let output = Command::new("git")
        .args(["branch", "-vv"])
        .output()
        .context("Failed to list branches")?;

    let branches_output = String::from_utf8_lossy(&output.stdout);
    let mut gone_branches = Vec::new();

    for line in branches_output.lines() {
        if line.contains(": gone]") {
            // Extract branch name (first word after optional *)
            let branch = line
                .trim_start_matches('*')
                .split_whitespace()
                .next()
                .unwrap_or("")
                .to_string();

            if !branch.is_empty() {
                gone_branches.push(branch);
            }
        }
    }

    if gone_branches.is_empty() {
        println!("{} No stale branches found", "✓".green().bold());
        return Ok(());
    }

    println!();
    println!(
        "{} Found {} stale branches:",
        "!".yellow().bold(),
        gone_branches.len().to_string().bright_white().bold()
    );

    for branch in &gone_branches {
        println!("  {} {}", "×".red().bold(), branch.white());
    }

    println!();

    let confirmed = if args.yes {
        true
    } else {
        Confirm::new()
            .with_prompt(format!("{} Delete these branches?", "?".yellow().bold()))
            .default(false)
            .interact()?
    };

    if !confirmed {
        println!("{} Cancelled", "×".red().bold());
        return Ok(());
    }

    println!();
    println!("{} Deleting branches...", "→".bright_yellow().bold());

    for branch in &gone_branches {
        let status = Command::new("git")
            .args(["branch", "-D", branch])
            .status()
            .with_context(|| format!("Failed to delete branch {}", branch))?;

        if status.success() {
            println!("  {} {}", "✓".green().bold(), branch.bright_black());
        }
    }

    println!();
    println!(
        "{} Deleted {} branches",
        "✓".green().bold(),
        gone_branches.len().to_string().green().bold()
    );

    Ok(())
}
