use anyhow::Result;
use clap::Parser;
use colored::Colorize;
use dotfiles_tools::completions;
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex};
use std::thread;

#[derive(Parser)]
#[command(name = "upd")]
#[command(about = "Parallel system update orchestrator", long_about = None)]
#[command(version)]
struct Args {}

fn main() -> Result<()> {
    if completions::handle_completion_flag::<Args>() {
        return Ok(());
    }

    let _args = Args::parse();

    banner::print_banner("SYSTEM UPDATE", "parallel update orchestrator", "blue");

    // Check what's available on the system
    let has_brew = which("brew");
    let has_apt = which("apt-get");
    let has_dnf = which("dnf");
    let has_mise = which("mise");
    let has_yt_dlp = which("yt-dlp");
    let has_regen = which("regen-zsh-completions");

    banner::divider("cyan");
    banner::status("□", "DETECTED SYSTEMS", "", "cyan");

    if has_brew {
        println!("   {} brew", "✓".green());
    }
    if has_apt {
        println!("   {} apt-get", "✓".green());
    }
    if has_dnf {
        println!("   {} dnf", "✓".green());
    }
    if has_mise {
        println!("   {} mise", "✓".green());
    }
    if has_yt_dlp {
        println!("   {} yt-dlp", "✓".green());
    }
    if has_regen {
        println!("   {} zsh completions", "✓".green());
    }

    banner::divider("cyan");

    // Run install script first (sequential, required)
    banner::status("□", "PHASE 1", "dotfiles install", "blue");
    run_install()?;

    // Phase 2: sudo updates (sequential - need password input)
    banner::divider("cyan");
    banner::status("□", "PHASE 2", "system package updates", "red");

    let mut sudo_results = Vec::new();

    if has_apt {
        println!("   {} updating apt-get...", "→".red());
        let result = update_apt();
        sudo_results.push(("apt-get", result.is_ok()));
        if result.is_ok() {
            println!("   {} apt-get", "✓".green());
        } else {
            println!("   {} apt-get", "✗".red());
        }
    }

    if has_dnf {
        println!("   {} updating dnf...", "→".red());
        let result = update_dnf();
        sudo_results.push(("dnf", result.is_ok()));
        if result.is_ok() {
            println!("   {} dnf", "✓".green());
        } else {
            println!("   {} dnf", "✗".red());
        }
    }

    // Parallel phase: Update non-sudo package managers
    banner::divider("cyan");
    banner::status("□", "PHASE 3", "parallel updates", "magenta");

    let results = Arc::new(Mutex::new(Vec::new()));
    let mut handles = vec![];

    if has_brew {
        let results = results.clone();
        handles.push(thread::spawn(move || {
            let result = update_brew();
            results.lock().unwrap().push(("brew", result.is_ok()));
        }));
    }

    if has_mise {
        let results = results.clone();
        handles.push(thread::spawn(move || {
            let result = update_mise();
            results.lock().unwrap().push(("mise", result.is_ok()));
        }));
    }

    if has_yt_dlp {
        let results = results.clone();
        handles.push(thread::spawn(move || {
            let result = update_yt_dlp();
            results.lock().unwrap().push(("yt-dlp", result.is_ok()));
        }));
    }

    // Wait for all parallel updates
    for handle in handles {
        handle.join().unwrap();
    }

    // Print results
    for (name, success) in results.lock().unwrap().iter() {
        if *success {
            println!("   {} {}", "✓".green(), name);
        } else {
            println!("   {} {}", "✗".red(), name);
        }
    }

    banner::divider("cyan");

    // Generate completions
    if has_regen {
        banner::status("□", "PHASE 4", "zsh completions", "green");
        regen_completions()?;
    }

    banner::divider("cyan");
    banner::success("SYSTEM UPDATE COMPLETE");

    // Print summary - merge sudo and parallel results
    let mut results = results.lock().unwrap().clone();
    results.extend(sudo_results);
    let success_count = results.iter().filter(|(_, ok)| *ok).count();
    let total_count = results.len();

    println!(
        "\n   {} UPDATED  {} FAILED\n",
        success_count.to_string().green().bold(),
        (total_count - success_count).to_string().red().bold()
    );

    Ok(())
}

fn which(cmd: &str) -> bool {
    Command::new("which")
        .arg(cmd)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

fn run_install() -> Result<()> {
    let home = std::env::var("HOME")?;
    let status = Command::new("sh")
        .arg(format!("{}/.dotfiles/install", home))
        .current_dir(&home)
        .stdout(Stdio::null())
        .status()?;

    if !status.success() {
        anyhow::bail!("install script failed");
    }
    Ok(())
}

fn update_apt() -> Result<()> {
    Command::new("sudo")
        .args(["apt-get", "update"])
        .stdout(Stdio::null())
        .stdin(Stdio::inherit())
        .status()?;

    Command::new("sudo")
        .args(["apt-get", "upgrade", "-y"])
        .stdout(Stdio::null())
        .stdin(Stdio::inherit())
        .status()?;

    Command::new("sudo")
        .args(["apt-get", "autoremove", "-y"])
        .stdout(Stdio::null())
        .stdin(Stdio::inherit())
        .status()?;

    Ok(())
}

fn update_dnf() -> Result<()> {
    Command::new("sudo")
        .args(["dnf", "update", "-y"])
        .stdout(Stdio::null())
        .stdin(Stdio::inherit())
        .status()?;
    Ok(())
}

fn update_brew() -> Result<()> {
    Command::new("brew")
        .arg("update")
        .stdout(Stdio::null())
        .status()?;

    Command::new("brew")
        .arg("upgrade")
        .stdout(Stdio::null())
        .status()?;

    Command::new("brew")
        .arg("cleanup")
        .stdout(Stdio::null())
        .status()?;

    Ok(())
}

fn update_mise() -> Result<()> {
    Command::new("mise")
        .arg("up")
        .stdout(Stdio::null())
        .status()?;

    let home = std::env::var("HOME")?;
    let shims_path = format!("{}/.local/share/mise/shims", home);
    if std::path::Path::new(&shims_path).exists() {
        std::fs::remove_dir_all(&shims_path)?;
    }

    Command::new("mise")
        .arg("reshim")
        .stdout(Stdio::null())
        .status()?;

    Ok(())
}

fn update_yt_dlp() -> Result<()> {
    Command::new("yt-dlp")
        .args(["--update-to", "nightly"])
        .stdout(Stdio::null())
        .status()?;
    Ok(())
}

fn regen_completions() -> Result<()> {
    Command::new("regen-zsh-completions")
        .stdout(Stdio::null())
        .status()?;
    Ok(())
}

mod banner {
    use colored::Colorize;

    pub fn print_banner(title: &str, subtitle: &str, color: &str) {
        let color_fn = match color {
            "red" => |s: &str| s.red().to_string(),
            "green" => |s: &str| s.green().to_string(),
            "yellow" => |s: &str| s.yellow().to_string(),
            "blue" => |s: &str| s.blue().to_string(),
            "magenta" => |s: &str| s.magenta().to_string(),
            "cyan" => |s: &str| s.cyan().to_string(),
            _ => |s: &str| s.to_string(),
        };

        println!(
            "\n{}",
            color_fn("   ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄")
        );
        println!(
            "{}",
            color_fn("   ██░▀██████░▄▄▀█░▄▄▀█░▄▄█░██░▄▄▄░█░▄▄▀█░▄▄▀█▄░▄██")
        );
        println!(
            "{}",
            color_fn("   ██░█░██░██░▀▀░█░▀▀░█▄▄▀█░██░███░█░▀▀░█░▀▀▄██░███")
        );
        println!(
            "{}",
            color_fn("   ██▄▀▄██▄██░██░█░██░█▄▄▄█▄▄█░▀▀▀░█░██░█▄█▄▄██▄███")
        );
        println!(
            "{}",
            color_fn("   ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀")
        );
        println!(
            "   {} {}\n",
            color_fn(&format!("▸ {}", title)).bold(),
            subtitle.dimmed()
        );
    }

    pub fn status(icon: &str, label: &str, value: &str, color: &str) {
        let color_fn = match color {
            "red" => |s: &str| s.red().to_string(),
            "green" => |s: &str| s.green().to_string(),
            "yellow" => |s: &str| s.yellow().to_string(),
            "blue" => |s: &str| s.blue().to_string(),
            "magenta" => |s: &str| s.magenta().to_string(),
            "cyan" => |s: &str| s.cyan().to_string(),
            _ => |s: &str| s.to_string(),
        };

        if value.is_empty() {
            println!("   {} {}", color_fn(icon), label.bold());
        } else {
            println!("   {} {} {}", color_fn(icon), label.bold(), value);
        }
    }

    pub fn success(msg: &str) {
        println!("   {} {}", "✓".green().bold(), msg.green().bold());
    }

    pub fn divider(color: &str) {
        let color_fn = match color {
            "red" => |s: &str| s.red().to_string(),
            "green" => |s: &str| s.green().to_string(),
            "yellow" => |s: &str| s.yellow().to_string(),
            "blue" => |s: &str| s.blue().to_string(),
            "magenta" => |s: &str| s.magenta().to_string(),
            "cyan" => |s: &str| s.cyan().to_string(),
            _ => |s: &str| s.to_string(),
        };
        println!(
            "{}",
            color_fn("   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        );
    }
}
