use anyhow::{Context, Result};
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use std::io::{self, Write};
use std::process::Command;

#[derive(Parser)]
#[command(name = "install-terminfo")]
#[command(about = "Install terminfo to remote host via SSH")]
#[command(args_conflicts_with_subcommands = true)]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,

    /// Remote host (e.g., user@hostname)
    host: Option<String>,
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
            "install-terminfo",
            &mut io::stdout(),
        );
        return Ok(());
    }

    let host = args
        .host
        .ok_or_else(|| anyhow::anyhow!(Args::command().render_help()))?;

    println!("\n/// {}\n", "INSTALL-TERMINFO".bold());
    println!("  {} target: {}", "→".bright_black(), host);

    let infocmp = Command::new("infocmp").arg("-x").output()?;

    if !infocmp.status.success() {
        println!("  {} infocmp failed", "✗".red());
        anyhow::bail!("infocmp failed");
    }

    let mut child = Command::new("ssh")
        .arg(&host)
        .arg("--")
        .arg("tic")
        .arg("-x")
        .arg("-")
        .stdin(std::process::Stdio::piped())
        .spawn()?;

    child
        .stdin
        .as_mut()
        .context("failed to open stdin pipe")?
        .write_all(&infocmp.stdout)?;
    let status = child.wait()?;

    if !status.success() {
        println!("  {} ssh tic failed", "✗".red());
        anyhow::bail!("ssh tic failed");
    }

    println!("  {} terminfo installed", "✓".green());
    Ok(())
}
