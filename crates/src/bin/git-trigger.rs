//! Amend and force push to trigger CI/CD

use anyhow::{Context, Result};
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
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

    banner::header("GIT-TRIGGER");

    let repo = Repository::discover(".").context("Not a git repository")?;

    if args.dry_run {
        banner::info("Dry run - would execute:");
        banner::info("  git commit --amend --no-edit");
        banner::info("  git push --force");
        return Ok(());
    }

    // Get HEAD commit
    let head = repo.head()?;
    let commit = head.peel_to_commit()?;
    let tree = commit.tree()?;

    // Amend with same message and tree
    let signature = repo.signature()?;
    let parents: Vec<_> = commit.parents().collect();
    let parent_refs: Vec<&git2::Commit> = parents.iter().collect();

    let new_commit_oid = repo.commit(
        None,
        &signature,
        &signature,
        commit.message().unwrap_or(""),
        &tree,
        &parent_refs,
    )?;

    repo.head()?.set_target(new_commit_oid, "amend commit")?;

    // Get current branch
    let head = repo.head()?;
    let branch_name = head.shorthand().context("No branch name")?;

    // Push with force
    let mut remote = repo.find_remote("origin")?;
    let refspec = format!("+refs/heads/{0}:refs/heads/{0}", branch_name);

    let mut callbacks = RemoteCallbacks::new();
    callbacks.credentials(|_url, username_from_url, _allowed_types| {
        Cred::ssh_key_from_agent(username_from_url.unwrap_or("git"))
    });

    let mut push_opts = PushOptions::new();
    push_opts.remote_callbacks(callbacks);

    remote.push(&[refspec.as_str()], Some(&mut push_opts))?;

    banner::ok("CI/CD triggered");

    Ok(())
}
