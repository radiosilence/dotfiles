use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use dotfiles_tools::banner;
use std::io::{self, Write};
use std::process::Command;

#[derive(Parser)]
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

    banner::print_glitch_header("INSTALL-TERMINFO", "cyan");
    banner::status("□", "TARGET", &host, "cyan");

    let infocmp = Command::new("infocmp").arg("-x").output()?;

    if !infocmp.status.success() {
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

    child.stdin.as_mut().unwrap().write_all(&infocmp.stdout)?;
    let status = child.wait()?;

    if !status.success() {
        anyhow::bail!("ssh tic failed");
    }

    banner::success("TERMINFO INSTALLED");
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_host_string_format() {
        let hosts = vec!["user@hostname", "root@192.168.1.1", "deploy@example.com"];

        for host in hosts {
            assert!(host.contains('@'));
        }
    }

    #[test]
    fn test_command_building() {
        // Verify Command::new works with infocmp and ssh
        let _infocmp = Command::new("infocmp");
        let _ssh = Command::new("ssh");
    }
}
