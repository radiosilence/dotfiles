//! Amend and force push to trigger CI/CD

use anyhow::{Context, Result};
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use dotfiles_tools::banner;
use git2::{Cred, PushOptions, RemoteCallbacks, Repository};
use std::io;

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

    banner::print_banner("GIT-TRIGGER", "CI/CD re-trigger utility", "magenta");

    let repo = Repository::discover(".").context("Not a git repository")?;

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

    // Amend with same message and tree - keep original parents
    let signature = repo.signature()?;
    let parents: Vec<_> = commit.parents().collect();
    let parent_refs: Vec<&git2::Commit> = parents.iter().collect();

    // Update HEAD reference directly for amend
    let new_commit_oid = repo.commit(
        None, // Don't update HEAD yet
        &signature,
        &signature,
        commit.message().unwrap_or(""),
        &tree,
        &parent_refs,
    )?;

    // Now update HEAD to point to new commit
    repo.head()?.set_target(new_commit_oid, "amend commit")?;

    println!("{} Force pushing...", "→".bright_magenta().bold());

    // Get current branch
    let head = repo.head()?;
    let branch_name = head.shorthand().context("No branch name")?;

    // Push with force
    let mut remote = repo.find_remote("origin")?;
    let refspec = format!("+refs/heads/{0}:refs/heads/{0}", branch_name);

    // Set up callbacks for SSH agent or credentials
    let mut callbacks = RemoteCallbacks::new();
    callbacks.credentials(|_url, username_from_url, _allowed_types| {
        Cred::ssh_key_from_agent(username_from_url.unwrap_or("git"))
    });

    let mut push_opts = PushOptions::new();
    push_opts.remote_callbacks(callbacks);

    remote.push(&[refspec.as_str()], Some(&mut push_opts))?;

    println!();
    println!("{} CI/CD triggered", "✓".green().bold());

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_git2_repository_functions() {
        // Just verify git2 types are usable
        let _result = Repository::open(".");
    }

    #[test]
    fn test_push_options_creation() {
        let _opts = PushOptions::new();
    }
}
