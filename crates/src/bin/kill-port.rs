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

    use dotfiles_tools::banner;
    banner::print_glitch_header("KILL-PORT", "magenta");
    banner::loading("Scanning for process on port...");

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
            "{} Found process {} on port {}",
            "→".blue().bold(),
            pid.to_string().yellow(),
            port.to_string().cyan()
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

    // Parse signal
    let signal = match args.signal.as_deref() {
        None | Some("TERM") | Some("15") => Signal::SIGTERM,
        Some("KILL") | Some("9") => Signal::SIGKILL,
        Some("INT") | Some("2") => Signal::SIGINT,
        Some("HUP") | Some("1") => Signal::SIGHUP,
        Some("QUIT") | Some("3") => Signal::SIGQUIT,
        Some("USR1") | Some("10") => Signal::SIGUSR1,
        Some("USR2") | Some("12") => Signal::SIGUSR2,
        Some(sig) => bail!("Unsupported signal: {}", sig),
    };

    // Kill the processes
    for pid in &pids {
        if let Some(sig_name) = &args.signal {
            println!(
                "{} Sending signal {} to process {}",
                "→".blue().bold(),
                sig_name.yellow(),
                pid.to_string().yellow()
            );
        }

        let nix_pid = Pid::from_raw(*pid as i32);
        kill(nix_pid, signal)?;

        banner::success(&format!("TERMINATED PROCESS {}", pid));
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_port_range() {
        // Verify u16::MAX for port validation
        assert_eq!(65535, u16::MAX);
    }
}
