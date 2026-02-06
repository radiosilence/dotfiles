//! Clean up local branches whose remotes have been deleted
//!
//! After PRs are merged and remote branches deleted, this cleans up
//! the stale local tracking branches.

use anyhow::{bail, Context, Result};
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use dialoguer::Confirm;
use git2::{BranchType, Repository};
use std::io;
use std::process::Command;

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

    println!("\n/// {}\n", "GIT-SYNC".bold());

    let repo = Repository::open(".").context("Not a git repository")?;

    // Prune and fetch (shelling out for auth compatibility)
    println!("  {} Pruning and fetching from origin", "·".bright_black());

    let fetch = Command::new("git")
        .args(["fetch", "--prune", "origin"])
        .status()
        .context("Failed to run git fetch")?;

    if !fetch.success() {
        bail!("git fetch --prune failed");
    }

    // Find branches with deleted remotes
    let gone_branches = find_gone_branches(&repo)?;

    if gone_branches.is_empty() {
        println!("  {} No stale branches found", "✓".green());
        return Ok(());
    }

    println!(
        "  {} Found stale branches: {}",
        "→".bright_black(),
        gone_branches.len()
    );
    println!();
    for branch in &gone_branches {
        println!("    {}", branch);
    }
    println!();

    let confirmed = if args.yes {
        true
    } else {
        Confirm::new()
            .with_prompt("Delete these branches?")
            .default(false)
            .interact()?
    };

    if !confirmed {
        println!("  {} Cancelled", "!".yellow());
        return Ok(());
    }

    println!("  {} Deleting branches", "·".bright_black());
    for branch_name in &gone_branches {
        let mut branch = repo.find_branch(branch_name, BranchType::Local)?;
        branch.delete()?;
        println!("    {}", branch_name);
    }

    println!("  {} Deleted {} branches", "✓".green(), gone_branches.len());

    Ok(())
}

/// Find local branches whose upstream remotes no longer exist
///
/// After `git fetch --prune`, remote-tracking refs are deleted but the local
/// branch config (`branch.<name>.remote` / `branch.<name>.merge`) remains.
/// A branch is "gone" when it has upstream config but the remote-tracking ref
/// no longer exists — i.e. `branch.upstream()` returns an error.
fn find_gone_branches(repo: &Repository) -> Result<Vec<String>> {
    let mut gone_branches = Vec::new();

    for branch in repo.branches(Some(BranchType::Local))? {
        let (branch, _) = branch?;
        let name = branch.name()?.context("Invalid branch name")?;

        // Check if this branch has upstream tracking config
        let has_upstream_config = repo
            .config()?
            .get_string(&format!("branch.{name}.remote"))
            .is_ok();

        if has_upstream_config {
            // If it has config but upstream() fails, the remote-tracking ref is gone
            if branch.upstream().is_err() {
                gone_branches.push(name.to_string());
            }
        }
    }

    Ok(gone_branches)
}

#[cfg(test)]
mod tests {
    use super::*;
    use git2::{Repository, Signature};
    use tempfile::TempDir;

    fn create_test_repo() -> (TempDir, Repository) {
        let dir = TempDir::new().unwrap();
        let repo = Repository::init(dir.path()).unwrap();

        // Create initial commit so HEAD exists
        {
            let sig = Signature::now("Test", "test@test.com").unwrap();
            let tree_id = repo.index().unwrap().write_tree().unwrap();
            let tree = repo.find_tree(tree_id).unwrap();
            repo.commit(Some("HEAD"), &sig, &sig, "init", &tree, &[])
                .unwrap();
        }

        (dir, repo)
    }

    #[test]
    fn test_find_gone_branches_no_upstream() {
        let (_dir, repo) = create_test_repo();

        // Create a branch with no upstream config — should NOT be reported as gone
        let head = repo.head().unwrap().peel_to_commit().unwrap();
        repo.branch("feature", &head, false).unwrap();

        let gone = find_gone_branches(&repo).unwrap();
        assert!(
            gone.is_empty(),
            "Branch without upstream config should not be gone"
        );
    }

    fn add_origin_remote(repo: &Repository) {
        repo.remote("origin", "https://example.com/dummy.git")
            .unwrap();
    }

    #[test]
    fn test_find_gone_branches_with_valid_upstream() {
        let (_dir, repo) = create_test_repo();
        add_origin_remote(&repo);

        // Create a remote-tracking ref
        let head = repo.head().unwrap().peel_to_commit().unwrap();
        repo.reference(
            "refs/remotes/origin/feature",
            head.id(),
            true,
            "create remote tracking",
        )
        .unwrap();

        // Create local branch with upstream config pointing to it
        let mut branch = repo.branch("feature", &head, false).unwrap();
        branch.set_upstream(Some("origin/feature")).unwrap();

        let gone = find_gone_branches(&repo).unwrap();
        assert!(
            gone.is_empty(),
            "Branch with valid upstream should not be gone"
        );
    }

    #[test]
    fn test_find_gone_branches_detects_gone() {
        let (_dir, repo) = create_test_repo();
        add_origin_remote(&repo);

        let head = repo.head().unwrap().peel_to_commit().unwrap();

        // Create remote-tracking ref, set upstream, then delete the ref
        repo.reference(
            "refs/remotes/origin/feature",
            head.id(),
            true,
            "create remote tracking",
        )
        .unwrap();

        let mut branch = repo.branch("feature", &head, false).unwrap();
        branch.set_upstream(Some("origin/feature")).unwrap();

        // Simulate `git fetch --prune` by deleting the remote-tracking ref
        let mut remote_ref = repo.find_reference("refs/remotes/origin/feature").unwrap();
        remote_ref.delete().unwrap();

        let gone = find_gone_branches(&repo).unwrap();
        assert_eq!(
            gone,
            vec!["feature"],
            "Should detect branch with deleted upstream"
        );
    }
}
