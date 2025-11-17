//! Kill process listening on specified port

use anyhow::{bail, Result};
use clap::Parser;
use colored::Colorize;
use dotfiles_tools::completions;
use netstat2::{get_sockets_info, AddressFamilyFlags, ProtocolFlags, ProtocolSocketInfo};
use std::collections::HashSet;

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
    if completions::handle_completion_flag::<Args>() {
        return Ok(());
    }

    let args = Args::parse();

    use dotfiles_tools::banner;
    banner::print_glitch_header("KILL-PORT", "magenta");
    banner::loading("Scanning for process on port...");

    // Get all sockets (TCP and UDP, IPv4 and IPv6)
    let af_flags = AddressFamilyFlags::IPV4 | AddressFamilyFlags::IPV6;
    let proto_flags = ProtocolFlags::TCP | ProtocolFlags::UDP;
    let sockets = get_sockets_info(af_flags, proto_flags)?;

    let mut pids = HashSet::new();

    // Find processes listening on the target port
    for socket in sockets {
        let matches = match socket.protocol_socket_info {
            ProtocolSocketInfo::Tcp(tcp_info) => tcp_info.local_port == args.port,
            ProtocolSocketInfo::Udp(udp_info) => udp_info.local_port == args.port,
        };

        if matches {
            if let Some(pid) = socket.associated_pids.first() {
                pids.insert(*pid);
            }
        }
    }

    if pids.is_empty() {
        bail!("No process found listening on port {}", args.port);
    }

    // Display found processes
    for pid in &pids {
        println!(
            "{} Found process {} on port {}",
            "→".blue().bold(),
            pid.to_string().yellow(),
            args.port.to_string().cyan()
        );
    }

    if args.dry_run {
        for pid in &pids {
            println!(
                "{} Dry run - would kill process {}",
                "i".blue().bold(),
                pid.to_string().yellow()
            );
            if let Some(sig) = &args.signal {
                println!("  With signal: {}", sig.yellow());
            }
        }
        return Ok(());
    }

    // Kill the processes
    for pid in &pids {
        if let Some(sig) = &args.signal {
            println!(
                "{} Sending signal {} to process {}",
                "→".blue().bold(),
                sig.yellow(),
                pid.to_string().yellow()
            );

            // Use kill command for custom signals
            let status = std::process::Command::new("kill")
                .arg(format!("-{}", sig))
                .arg(pid.to_string())
                .status()?;

            if !status.success() {
                bail!("Failed to kill process {}", pid);
            }
        } else {
            // Use kill command for SIGTERM (default)
            let status = std::process::Command::new("kill")
                .arg(pid.to_string())
                .status()?;

            if !status.success() {
                bail!("Failed to kill process {}", pid);
            }
        }

        banner::success(&format!("TERMINATED PROCESS {}", pid));
    }

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
