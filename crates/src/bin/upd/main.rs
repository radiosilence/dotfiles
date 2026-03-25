use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use std::io;
use std::os::unix::process::CommandExt;
use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::Duration;
use which::which;

#[derive(Parser)]
#[command(name = "upd")]
#[command(about = "Update the system (delegates to mise tasks)", long_about = None)]
#[command(version)]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    Completion {
        #[arg(value_enum)]
        shell: Shell,
    },
}

fn main() -> Result<()> {
    let args = Args::parse();

    if let Some(Commands::Completion { shell }) = args.command {
        generate(shell, &mut Args::command(), "upd", &mut io::stdout());
        return Ok(());
    }

    let is_macos = cfg!(target_os = "macos");
    let has_brew = which("brew").is_ok();
    let has_apt = which("apt-get").is_ok();
    let has_dnf = which("dnf").is_ok();

    // Acquire sudo before mise takes over (needs real stdin for password prompt)
    let needs_sudo = has_apt || has_dnf || (is_macos && has_brew);
    let has_sudo = if needs_sudo {
        match Command::new("sudo").arg("-v").status() {
            Ok(s) if s.success() => true,
            _ => {
                if has_apt || has_dnf {
                    eprintln!("Failed to get sudo authentication");
                    std::process::exit(1);
                }
                false
            }
        }
    } else {
        false
    };

    // Spawn sudo keepalive in background
    let keepalive = Arc::new(AtomicBool::new(true));
    if has_sudo {
        let flag = keepalive.clone();
        thread::spawn(move || {
            while flag.load(Ordering::Relaxed) {
                let _ = Command::new("sudo").arg("-v").status();
                thread::sleep(Duration::from_secs(60));
            }
        });
    }

    // Find mise
    let mise = which("mise").expect("mise not found — install it first");

    // Locate dotfiles root (where mise.toml lives)
    let dotfiles_dir = dirs::home_dir()
        .expect("could not determine home directory")
        .join(".dotfiles");

    // exec into mise — replaces this process
    let err = Command::new(mise)
        .args(["run", "upd"])
        .current_dir(&dotfiles_dir)
        .exec();

    // exec() only returns on error
    keepalive.store(false, Ordering::Relaxed);
    Err(err.into())
}
