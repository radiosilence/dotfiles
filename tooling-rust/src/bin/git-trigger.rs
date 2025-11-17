//! Amend and force push to trigger CI/CD

use anyhow::{Context, Result};
use clap::Parser;
use colored::Colorize;
use dotfiles_tools::completions;
use git2::{PushOptions, Repository};

#[derive(Parser)]
#[command(name = "git-trigger")]
#[command(about = "Amend and force push to trigger CI", long_about = None)]
#[command(version)]
struct Args {
    /// Dry run - show what would be done
    #[arg(short = 'n', long)]
    dry_run: bool,
}

fn main() -> Result<()> {
    if completions::handle_completion_flag::<Args>() {
        return Ok(());
    }

    let args = Args::parse();

    println!("{}", "┌──[ GIT-TRIGGER ]─────────────┐".bright_magenta());
    println!("{}", "│  CI/CD re-trigger utility     │".bright_magenta());
    println!("{}", "└───────────────────────────────┘".bright_magenta());
    println!();

    let repo = Repository::open(".").context("Not a git repository")?;

    if args.dry_run {
        println!("{} Would run:", "i".blue().bold());
        println!("  git commit --amend --no-edit");
        println!("  git push --force");
        return Ok(());
    }

    println!("{} Amending last commit...", "→".bright_magenta().bold());

    // Get HEAD commit
    let head = repo.head()?;
    let commit = head.peel_to_commit()?;
    let tree = commit.tree()?;

    // Amend with same message and tree
    let signature = repo.signature()?;
    let parents = commit.parents().collect::<Vec<_>>();
    let parent_refs: Vec<&git2::Commit> = parents.iter().collect();

    repo.commit(
        Some("HEAD"),
        &signature,
        &signature,
        commit.message().unwrap_or(""),
        &tree,
        &parent_refs,
    )?;

    println!("{} Force pushing...", "→".bright_magenta().bold());

    // Get current branch
    let head = repo.head()?;
    let branch_name = head.shorthand().context("No branch name")?;

    // Push with force
    let mut remote = repo.find_remote("origin")?;
    let refspec = format!("+refs/heads/{0}:refs/heads/{0}", branch_name);

    let mut push_opts = PushOptions::new();
    remote.push(&[refspec.as_str()], Some(&mut push_opts))?;

    println!();
    println!("{} CI/CD triggered", "✓".green().bold());

    Ok(())
}
