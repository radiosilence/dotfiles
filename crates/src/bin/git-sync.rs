//! Clean up local branches whose remotes have been deleted
//!
//! After PRs are merged and remote branches deleted, this cleans up
//! the stale local tracking branches.

use anyhow::{Context, Result};
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use dialoguer::Confirm;
use git2::{BranchType, FetchOptions, Repository};
use std::io;

#[derive(Parser)]
#[command(name = "git-sync")]
#[command(about = "Clean up merged branches", long_about = None)]
#[command(version)]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,

    /// Delete without confirmation
    #[arg(short = 'y', long)]
    yes: bool,
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
        generate(shell, &mut Args::command(), "git-sync", &mut io::stdout());
        return Ok(());
    }

    println!("{}", "═══════════════════════════════════".bright_yellow());
    println!("{}", "  GIT-SYNC // branch cleanup util  ".bright_yellow());
    println!("{}", "═══════════════════════════════════".bright_yellow());
    println!();

    let repo = Repository::open(".").context("Not a git repository")?;

    // Prune and fetch
    println!(
        "{} Pruning and fetching from origin...",
        "→".bright_yellow().bold()
    );

    let mut remote = repo.find_remote("origin")?;
    let mut fetch_opts = FetchOptions::new();
    fetch_opts.prune(git2::FetchPrune::On);

    remote.fetch(
        &["refs/heads/*:refs/remotes/origin/*"],
        Some(&mut fetch_opts),
        None,
    )?;

    // Find branches with deleted remotes
    let mut gone_branches = Vec::new();

    for branch in repo.branches(Some(BranchType::Local))? {
        let (branch, _) = branch?;
        let name = branch.name()?.context("Invalid branch name")?;

        // Check if upstream is gone
        if let Ok(upstream) = branch.upstream() {
            // Check if upstream ref exists
            if repo
                .find_reference(upstream.get().name().context("No upstream name")?)
                .is_err()
            {
                gone_branches.push(name.to_string());
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

    for branch_name in &gone_branches {
        let mut branch = repo.find_branch(branch_name, BranchType::Local)?;
        branch.delete()?;
        println!("  {} {}", "✓".green().bold(), branch_name.bright_black());
    }

    println!();
    println!(
        "{} Deleted {} branches",
        "✓".green().bold(),
        gone_branches.len().to_string().green().bold()
    );

    Ok(())
}
