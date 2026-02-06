//! Kill process listening on specified port

use anyhow::{bail, Result};
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use netstat2::{get_sockets_info, AddressFamilyFlags, ProtocolFlags, ProtocolSocketInfo};
use nix::sys::signal::{kill, Signal};
use nix::unistd::Pid;
use std::collections::HashSet;
use std::io;

#[derive(Parser)]
#[command(name = "kill-port")]
#[command(about = "Kill process listening on specified port", long_about = None)]
#[command(version)]
#[command(args_conflicts_with_subcommands = true)]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,

    /// Port number to kill process on
    #[arg(value_name = "PORT")]
    port: Option<u16>,

    /// Signal to send (default: TERM, also: KILL, INT, HUP, etc)
    #[arg(short, long, value_name = "SIGNAL")]
    signal: Option<String>,

    /// Show what would be killed without doing it
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
        generate(shell, &mut Args::command(), "kill-port", &mut io::stdout());
        return Ok(());
    }

    let port = args
        .port
        .ok_or_else(|| anyhow::anyhow!(Args::command().render_help()))?;

    println!("\n/// {}\n", "KILL-PORT".bold());

    // Get all sockets
    let af_flags = AddressFamilyFlags::IPV4 | AddressFamilyFlags::IPV6;
    let proto_flags = ProtocolFlags::TCP | ProtocolFlags::UDP;
    let sockets = get_sockets_info(af_flags, proto_flags)?;

    let mut pids = HashSet::new();

    // Find processes listening on the target port
    for socket in sockets {
        let matches = match socket.protocol_socket_info {
            ProtocolSocketInfo::Tcp(tcp_info) => tcp_info.local_port == port,
            ProtocolSocketInfo::Udp(udp_info) => udp_info.local_port == port,
        };

        if matches {
            if let Some(pid) = socket.associated_pids.first() {
                pids.insert(*pid);
            }
        }
    }

    if pids.is_empty() {
        bail!("No process found listening on port {}", port);
    }

    // Display found processes
    for pid in &pids {
        println!(
            "  {} found: PID {} on port {}",
            "→".bright_black(),
            pid,
            port
        );
    }

    if args.dry_run {
        for pid in &pids {
            println!(
                "  {} dry-run: would kill PID {} with signal {}",
                "·".bright_black(),
                pid,
                args.signal.as_deref().unwrap_or("TERM")
            );
        }
        return Ok(());
    }

    let signal = parse_signal(args.signal.as_deref())?;

    // Kill the processes
    for pid in &pids {
        let nix_pid = Pid::from_raw(*pid as i32);
        kill(nix_pid, signal)?;
        println!("  {} killed PID {}", "✓".green(), pid);
    }

    Ok(())
}

fn parse_signal(sig: Option<&str>) -> Result<Signal> {
    match sig {
        None | Some("TERM") | Some("15") => Ok(Signal::SIGTERM),
        Some("KILL") | Some("9") => Ok(Signal::SIGKILL),
        Some("INT") | Some("2") => Ok(Signal::SIGINT),
        Some("HUP") | Some("1") => Ok(Signal::SIGHUP),
        Some("QUIT") | Some("3") => Ok(Signal::SIGQUIT),
        Some("USR1") | Some("10") => Ok(Signal::SIGUSR1),
        Some("USR2") | Some("12") => Ok(Signal::SIGUSR2),
        Some(s) => bail!("Unsupported signal: {}", s),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_signal_parsing() {
        assert_eq!(parse_signal(None).unwrap(), Signal::SIGTERM);
        assert_eq!(parse_signal(Some("TERM")).unwrap(), Signal::SIGTERM);
        assert_eq!(parse_signal(Some("15")).unwrap(), Signal::SIGTERM);
        assert_eq!(parse_signal(Some("KILL")).unwrap(), Signal::SIGKILL);
        assert_eq!(parse_signal(Some("9")).unwrap(), Signal::SIGKILL);
        assert_eq!(parse_signal(Some("INT")).unwrap(), Signal::SIGINT);
        assert_eq!(parse_signal(Some("2")).unwrap(), Signal::SIGINT);
        assert_eq!(parse_signal(Some("HUP")).unwrap(), Signal::SIGHUP);
        assert_eq!(parse_signal(Some("USR1")).unwrap(), Signal::SIGUSR1);
        assert!(parse_signal(Some("BOGUS")).is_err());
    }
}
