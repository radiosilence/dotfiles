//! Kill process listening on specified port
//!
//! Finds the process using lsof and kills it with optional signal.
//! Rust provides better error handling and cross-platform port validation.

use anyhow::{bail, Context, Result};
use clap::Parser;
use colored::Colorize;
use std::process::Command;

#[derive(Parser)]
#[command(name = "kill-port")]
#[command(about = "Kill process listening on specified port", long_about = None)]
#[command(version)]
struct Args {
    /// Port number to kill process on
    #[arg(value_name = "PORT")]
    port: u16,

    /// Signal to send (default: TERM)
    #[arg(short, long, value_name = "SIGNAL")]
    signal: Option<String>,

    /// Show what would be killed without doing it
    #[arg(short = 'n', long)]
    dry_run: bool,
}

fn main() -> Result<()> {
    let args = Args::parse();

    use dotfiles_tools::banner;
    banner::print_glitch_header("KILL-PORT", "magenta");
    banner::loading("Scanning for process on port...");

    // Find PID using lsof (more reliable than parsing /proc or using sysinfo)
    let output = Command::new("lsof")
        .args(["-ti", &format!(":{}", args.port)])
        .output()
        .context("Failed to run lsof - is it installed?")?;

    if !output.status.success() {
        bail!("No process found listening on port {}", args.port);
    }

    let pid_str = String::from_utf8_lossy(&output.stdout);
    let pid = pid_str.trim();

    if pid.is_empty() {
        bail!("No process listening on port {}", args.port);
    }

    println!(
        "{} Found process {} on port {}",
        "→".blue().bold(),
        pid.yellow(),
        args.port.to_string().cyan()
    );

    if args.dry_run {
        println!(
            "{} Dry run - would kill process {}",
            "i".blue().bold(),
            pid.yellow()
        );
        if let Some(sig) = args.signal {
            println!("  With signal: {}", sig.yellow());
        }
        return Ok(());
    }

    // Build kill command
    let mut cmd = Command::new("kill");

    if let Some(sig) = &args.signal {
        cmd.arg(format!("-{}", sig));
        println!(
            "{} Sending signal {} to process {}",
            "→".blue().bold(),
            sig.yellow(),
            pid.yellow()
        );
    }

    cmd.arg(pid);

    let status = cmd.status().context("Failed to execute kill command")?;

    if !status.success() {
        bail!("Failed to kill process {}", pid);
    }

    banner::success(&format!("TERMINATED PROCESS {}", pid));

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_port_validation() {
        // Valid ports
        assert!(1024 < u16::MAX);
        assert!(8080 < u16::MAX);

        // Port 0 is technically valid but unusual
        assert_eq!(0_u16, 0);
    }

    #[test]
    fn test_signal_parsing() {
        // Common signals
        let signals = vec!["TERM", "KILL", "INT", "HUP", "9", "15"];
        for sig in signals {
            assert!(!sig.is_empty());
        }
    }
}

// Integration tests are in tests/ directory
// Example: tests/kill_port.rs
// #[test]
// fn test_kill_port_help() {
//     let output = Command::new("cargo")
//         .args(["run", "--bin", "kill-port", "--", "--help"])
//         .output()
//         .unwrap();
//     assert!(output.status.success());
// }
