//! Amend and force push to trigger CI/CD

use anyhow::{bail, Context, Result};
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use std::io;
use std::process::Command;

#[derive(Parser)]
#[command(name = "git-trigger")]
#[command(about = "Amend and force push to trigger CI", long_about = None)]
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
            "git-trigger",
            &mut io::stdout(),
        );
        return Ok(());
    }

    println!("\n/// {}\n", "GIT-TRIGGER".bold());

    if args.dry_run {
        println!("  {} Dry run - would execute:", "·".bright_black());
        println!("  {}   git commit --amend --no-edit", "·".bright_black());
        println!("  {}   git push --force", "·".bright_black());
        return Ok(());
    }

    // Amend commit
    let amend = Command::new("git")
        .args(["commit", "--amend", "--no-edit"])
        .status()
        .context("Failed to run git commit --amend")?;

    if !amend.success() {
        bail!("git commit --amend failed");
    }

    // Push with force
    let push = Command::new("git")
        .args(["push", "--force"])
        .status()
        .context("Failed to run git push")?;

    if !push.success() {
        bail!("git push --force failed");
    }

    println!("  {} CI/CD triggered", "✓".green());

    Ok(())
}
