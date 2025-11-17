//! Squash commits into a single commit for clean PR history

use anyhow::{bail, Context, Result};
use clap::Parser;
use colored::Colorize;
use dialoguer::Editor;
use dotfiles_tools::completions;
use git2::{BranchType, Repository};

#[derive(Parser)]
#[command(name = "git-squash")]
#[command(about = "Squash commits for clean PR history", long_about = None)]
#[command(version)]
struct Args {
    /// Parent branch to squash onto (default: main)
    #[arg(value_name = "PARENT", default_value = "main")]
    parent: String,

    /// Dry run - show what would be squashed
    #[arg(short = 'n', long)]
    dry_run: bool,
}

fn main() -> Result<()> {
    if completions::handle_completion_flag::<Args>() {
        return Ok(());
    }

    let args = Args::parse();

    println!(
        "{}",
        "╔════════════════════════════════════════╗".bright_red()
    );
    println!(
        "{}",
        "║  GIT-SQUASH // commit consolidator    ║".bright_red()
    );
    println!(
        "{}",
        "╚════════════════════════════════════════╝".bright_red()
    );
    println!();

    let repo = Repository::open(".").context("Not a git repository")?;

    // Get current branch
    let head = repo.head().context("Failed to get HEAD")?;
    let current_branch = head
        .shorthand()
        .context("Failed to get current branch name")?;

    if current_branch == args.parent {
        bail!("Already on parent branch '{}'", args.parent);
    }

    println!(
        "{} Current branch: {}",
        "→".bright_red().bold(),
        current_branch.cyan()
    );
    println!(
        "{} Parent branch: {}",
        "→".bright_red().bold(),
        args.parent.yellow()
    );
    println!();

    // Find merge base
    let current_commit = head
        .peel_to_commit()
        .context("Failed to get current commit")?;

    let parent_branch = repo
        .find_branch(&args.parent, BranchType::Local)
        .context(format!("Parent branch '{}' not found", args.parent))?;

    let parent_ref = parent_branch.get();
    let parent_commit = parent_ref
        .peel_to_commit()
        .context("Failed to get parent commit")?;

    let merge_base = repo
        .merge_base(current_commit.id(), parent_commit.id())
        .context("Failed to find merge base")?;

    println!(
        "{} Merge base: {}",
        "→".bright_red().bold(),
        merge_base.to_string().bright_black()
    );

    // Collect commits to squash
    let mut revwalk = repo.revwalk()?;
    revwalk.push(current_commit.id())?;
    revwalk.hide(merge_base)?;

    let mut commits = Vec::new();
    for oid in revwalk {
        let oid = oid?;
        let commit = repo.find_commit(oid)?;
        commits.push((
            commit.id(),
            commit.summary().unwrap_or("").to_string(),
            commit.author().name().unwrap_or("").to_string(),
        ));
    }

    if commits.is_empty() {
        println!("{} No commits to squash", "✓".green().bold());
        return Ok(());
    }

    // Reverse to show oldest first
    commits.reverse();

    println!();
    println!(
        "{} Found {} commits to squash:",
        "!".yellow().bold(),
        commits.len().to_string().bright_white().bold()
    );

    for (i, (oid, msg, author)) in commits.iter().enumerate() {
        println!(
            "  {} {} {} {}",
            format!("{:>2}.", i + 1).bright_black(),
            oid.to_string()[..7].yellow(),
            msg.white(),
            format!("({})", author).bright_black()
        );
    }
    println!();

    if args.dry_run {
        println!("{} Dry run - no changes made", "i".blue().bold());
        return Ok(());
    }

    // Collect all commit messages
    let combined_message = commits
        .iter()
        .map(|(_, msg, _)| msg.as_str())
        .collect::<Vec<&str>>()
        .join("\n");

    // Open editor for final message
    let edited_message = Editor::new()
        .extension(".txt")
        .edit(&combined_message)
        .context("Failed to open editor")?
        .unwrap_or(combined_message);

    println!("{} Squashing commits...", "→".bright_red().bold());

    // Reset to merge base (soft)
    let merge_base_commit = repo.find_commit(merge_base)?;
    repo.reset(merge_base_commit.as_object(), git2::ResetType::Soft, None)
        .context("Failed to reset to merge base")?;

    // Get tree
    let mut index = repo.index()?;
    let tree_oid = index.write_tree()?;
    let tree = repo.find_tree(tree_oid)?;

    // Create new commit
    let signature = repo.signature()?;
    repo.commit(
        Some("HEAD"),
        &signature,
        &signature,
        &edited_message,
        &tree,
        &[&merge_base_commit],
    )
    .context("Failed to create squashed commit")?;

    println!();
    println!(
        "{} Squashed {} commits into one",
        "✓".green().bold(),
        commits.len().to_string().green().bold()
    );
    println!();
    println!(
        "{} Force push required: {}",
        "!".yellow().bold(),
        "git push --force".bright_white().bold()
    );

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_parent_branch() {
        let args = Args::parse_from(&["git-squash"]);
        assert_eq!(args.parent, "main");
    }

    #[test]
    fn test_custom_parent_branch() {
        let args = Args::parse_from(&["git-squash", "develop"]);
        assert_eq!(args.parent, "develop");
    }
}
