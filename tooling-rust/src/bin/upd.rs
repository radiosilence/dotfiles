use anyhow::Result;
use colored::Colorize;
use indicatif::{MultiProgress, ProgressBar, ProgressStyle};
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex};
use std::thread;

fn main() -> Result<()> {
    banner::print_banner("SYSTEM UPDATE", "parallel update orchestrator", "blue");

    // Check what's available on the system
    let has_brew = which("brew");
    let has_apt = which("apt-get");
    let has_dnf = which("dnf");
    let has_mise = which("mise");
    let has_yt_dlp = which("yt-dlp");
    let has_regen = which("regen-zsh-completions");
    let has_rust = std::path::Path::new(&format!(
        "{}/.dotfiles/tooling-rust",
        std::env::var("HOME")?
    ))
    .exists();

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
    if has_rust {
        println!("   {} rust tooling", "✓".green());
    }

    banner::divider("cyan");

    // Run install script first (sequential, required)
    banner::status("□", "PHASE 1", "dotfiles install", "blue");
    run_install()?;

    // Parallel phase: Update all package managers
    banner::status("□", "PHASE 2", "parallel package updates", "magenta");

    let mp = MultiProgress::new();
    let results = Arc::new(Mutex::new(Vec::new()));
    let mut handles = vec![];

    // Spawn parallel updates
    if has_apt {
        let mp = mp.clone();
        let results = results.clone();
        handles.push(thread::spawn(move || {
            let pb = create_spinner(&mp, "apt-get");
            let result = update_apt();
            results.lock().unwrap().push(("apt-get", result.is_ok()));
            pb.finish_with_message(format_result("apt-get", result.is_ok()));
        }));
    }

    if has_dnf {
        let mp = mp.clone();
        let results = results.clone();
        handles.push(thread::spawn(move || {
            let pb = create_spinner(&mp, "dnf");
            let result = update_dnf();
            results.lock().unwrap().push(("dnf", result.is_ok()));
            pb.finish_with_message(format_result("dnf", result.is_ok()));
        }));
    }

    if has_brew {
        let mp = mp.clone();
        let results = results.clone();
        handles.push(thread::spawn(move || {
            let pb = create_spinner(&mp, "brew");
            let result = update_brew();
            results.lock().unwrap().push(("brew", result.is_ok()));
            pb.finish_with_message(format_result("brew", result.is_ok()));
        }));
    }

    if has_mise {
        let mp = mp.clone();
        let results = results.clone();
        handles.push(thread::spawn(move || {
            let pb = create_spinner(&mp, "mise");
            let result = update_mise();
            results.lock().unwrap().push(("mise", result.is_ok()));
            pb.finish_with_message(format_result("mise", result.is_ok()));
        }));
    }

    if has_yt_dlp {
        let mp = mp.clone();
        let results = results.clone();
        handles.push(thread::spawn(move || {
            let pb = create_spinner(&mp, "yt-dlp");
            let result = update_yt_dlp();
            results.lock().unwrap().push(("yt-dlp", result.is_ok()));
            pb.finish_with_message(format_result("yt-dlp", result.is_ok()));
        }));
    }

    // Wait for all parallel updates
    for handle in handles {
        handle.join().unwrap();
    }

    banner::divider("cyan");

    // Sequential cleanup phase
    if has_regen {
        banner::status("□", "PHASE 3", "zsh completions", "green");
        regen_completions()?;
    }

    if has_rust {
        banner::status("□", "PHASE 4", "rust tooling rebuild", "yellow");
        rebuild_rust()?;
    }

    banner::divider("cyan");
    banner::success("SYSTEM UPDATE COMPLETE");

    // Print summary
    let results = results.lock().unwrap();
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

fn create_spinner(mp: &MultiProgress, name: &str) -> ProgressBar {
    let pb = mp.add(ProgressBar::new_spinner());
    pb.set_style(
        ProgressStyle::default_spinner()
            .template("{spinner:.cyan} {msg}")
            .unwrap()
            .tick_strings(&["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]),
    );
    pb.set_message(format!("updating {}", name));
    pb.enable_steady_tick(std::time::Duration::from_millis(100));
    pb
}

fn format_result(name: &str, success: bool) -> String {
    if success {
        format!("{} {}", "✓".green(), name)
    } else {
        format!("{} {}", "✗".red(), name)
    }
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
        .status()?;

    Command::new("sudo")
        .args(["apt-get", "upgrade", "-y"])
        .stdout(Stdio::null())
        .status()?;

    Command::new("sudo")
        .args(["apt-get", "autoremove", "-y"])
        .stdout(Stdio::null())
        .status()?;

    Ok(())
}

fn update_dnf() -> Result<()> {
    Command::new("sudo")
        .args(["dnf", "update", "-y"])
        .stdout(Stdio::null())
        .status()?;
    Ok(())
}

fn update_brew() -> Result<()> {
    Command::new("brew")
        .arg("update")
        .stdout(Stdio::null())
        .status()?;

    Command::new("brew")
        .args(["bundle", "--global", "--upgrade"])
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

fn rebuild_rust() -> Result<()> {
    let home = std::env::var("HOME")?;
    let rust_dir = format!("{}/.dotfiles/tooling-rust", home);

    let status = Command::new("cargo")
        .args(["install", "--path", ".", "--root", ".."])
        .current_dir(&rust_dir)
        .status()?;

    if !status.success() {
        anyhow::bail!("rust rebuild failed");
    }
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
