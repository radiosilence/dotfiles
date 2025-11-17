use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use std::io::{self, Write};
use std::process::Command;

#[derive(Parser)]
#[command(about = "Install terminfo to remote host via SSH")]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,

    /// Remote host (e.g., user@hostname)
    host: String,
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

    banner::print_glitch_header("INSTALL-TERMINFO", "cyan");
    banner::status("□", "TARGET", &args.host, "cyan");

    let infocmp = Command::new("infocmp").arg("-x").output()?;

    if !infocmp.status.success() {
        anyhow::bail!("infocmp failed");
    }

    let mut child = Command::new("ssh")
        .arg(&args.host)
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

mod banner {
    use colored::Colorize;

    pub fn print_glitch_header(title: &str, color: &str) {
        let color_fn = match color {
            "cyan" => |s: &str| s.cyan().to_string(),
            "magenta" => |s: &str| s.magenta().to_string(),
            _ => |s: &str| s.to_string(),
        };
        println!("\n{}", color_fn(&format!("   ╔═══ {} ═══╗", title)).bold());
    }

    pub fn status(icon: &str, label: &str, value: &str, color: &str) {
        let color_fn = match color {
            "cyan" => |s: &str| s.cyan().to_string(),
            "magenta" => |s: &str| s.magenta().to_string(),
            _ => |s: &str| s.to_string(),
        };
        println!("   {} {} {}", color_fn(icon), label.bold(), value);
    }

    pub fn success(msg: &str) {
        println!("   {} {}\n", "✓".green().bold(), msg.green().bold());
    }
}
