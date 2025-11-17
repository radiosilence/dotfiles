use anyhow::Result;
use clap::Parser;
use colored::Colorize;
use dotfiles_tools::{completions, system::which};
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

    banner::print_banner("SYSTEM UPDATE", "idempotent system orchestrator", "blue");

    // Detect platform and what's available
    let is_macos = cfg!(target_os = "macos");
    let has_brew = which("brew");
    let has_apt = which("apt-get");
    let has_dnf = which("dnf");
    let has_mise = which("mise");
    let has_yt_dlp = which("yt-dlp");
    let has_regen = which("regen-zsh-completions");
    let has_rustup = which("rustup");

    banner::divider("cyan");
    banner::status("□", "DETECTED", "", "cyan");

    if is_macos {
        println!("   {} macOS", "✓".green());
    } else {
        println!("   {} Linux", "✓".green());
    }

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
    if has_rustup {
        println!("   {} rustup", "✓".green());
    }
    if has_yt_dlp {
        println!("   {} yt-dlp", "✓".green());
    }
    if has_regen {
        println!("   {} zsh completions", "✓".green());
    }

    banner::divider("cyan");

    // PHASE 1: Bootstrap missing package managers
    let mut phase = 1;
    if is_macos && !has_brew {
        banner::status("□", &format!("PHASE {}", phase), "install homebrew", "blue");
        install_homebrew()?;
        phase += 1;
        banner::divider("cyan");
    }

    // PHASE: Install fonts (macOS only, if not already done)
    if is_macos && has_brew && which("install-font-macos") {
        let home = std::env::var("HOME")?;
        let fonts_dir = std::path::Path::new(&home).join("Library/Fonts");

        // Only try fonts if the fonts directory is relatively empty
        if fonts_dir.exists() {
            let font_count = std::fs::read_dir(&fonts_dir)?.count();
            if font_count < 10 {
                banner::status("□", &format!("PHASE {}", phase), "install fonts", "magenta");
                install_fonts()?;
                phase += 1;
                banner::divider("cyan");
            }
        }
    }

    // PHASE: Brew bundle (macOS only, if Brewfile exists)
    if is_macos && has_brew {
        let home = std::env::var("HOME")?;
        let brewfile = std::path::Path::new(&home).join("Brewfile");
        if brewfile.exists() {
            banner::status("□", &format!("PHASE {}", phase), "brew bundle", "green");
            brew_bundle()?;
            phase += 1;
            banner::divider("cyan");
        }
    }

    // PHASE: Dotfiles install (always run, but it's idempotent)
    banner::status("□", &format!("PHASE {}", phase), "dotfiles install", "blue");
    dotfiles_tools::install::install_dotfiles()?;
    phase += 1;

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

    // PHASE: mise/rustup setup (only if missing)
    banner::divider("cyan");
    if has_mise || has_rustup {
        banner::status("□", &format!("PHASE {}", phase), "runtime setup", "yellow");
        if has_mise {
            dotfiles_tools::system::install_mise_tools()?;
        }
        if has_rustup {
            dotfiles_tools::system::setup_rustup()?;
        }
        phase += 1;
    }

    // Parallel phase: Update non-sudo package managers
    banner::divider("cyan");
    banner::status(
        "□",
        &format!("PHASE {}", phase),
        "parallel updates",
        "magenta",
    );

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
    banner::divider("cyan");
    if has_regen {
        banner::status(
            "□",
            &format!("PHASE {}", phase + 1),
            "zsh completions",
            "green",
        );
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

fn install_homebrew() -> Result<()> {
    println!("   {} installing Homebrew...", "→".blue());
    let status = Command::new("/bin/bash")
        .args([
            "-c",
            "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)",
        ])
        .stdin(Stdio::inherit())
        .status()?;

    if status.success() {
        println!("   {} Homebrew installed", "✓".green());
        Ok(())
    } else {
        anyhow::bail!("Homebrew installation failed")
    }
}

fn install_fonts() -> Result<()> {
    let fonts = vec![
        (
            "Hack Ligatured",
            "https://github.com/gaplo917/Ligatured-Hack/releases/download/v3.003%2BNv2.1.0%2BFC%2BJBMv2.242/HackLigatured-v3.003+FC3.1+JBMv2.242.zip",
        ),
        (
            "Geist",
            "https://github.com/vercel/geist-font/releases/download/1.3.0/Geist-1.3.0.zip",
        ),
        (
            "Geist Mono",
            "https://github.com/vercel/geist-font/releases/download/1.3.0/GeistMono-1.3.0.zip",
        ),
    ];

    for (name, url) in fonts {
        println!("   {} installing {} font...", "→".magenta(), name);
        let status = Command::new("install-font-macos")
            .arg(url)
            .stdout(Stdio::null())
            .status();

        if status.is_ok() {
            println!("   {} {}", "✓".green(), name);
        } else {
            println!("   {} {} (failed)", "⚠".yellow(), name);
        }
    }
    Ok(())
}

fn brew_bundle() -> Result<()> {
    let home = std::env::var("HOME")?;
    println!("   {} running brew bundle...", "→".green());
    let status = Command::new("brew")
        .arg("bundle")
        .current_dir(&home)
        .status()?;

    if status.success() {
        println!("   {} brew bundle complete", "✓".green());
        Ok(())
    } else {
        println!("   {} brew bundle failed", "⚠".yellow());
        Ok(()) // Don't fail entire update if brew bundle fails
    }
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
