use anyhow::{Context, Result};
use clap::Parser;
use colored::Colorize;
use dotfiles_tools::{banner, completions};
use std::process::{Command, Stdio};

#[derive(Parser)]
#[command(name = "setup-macos")]
#[command(about = "Initial macOS setup with Homebrew, fonts, and tools", long_about = None)]
#[command(version)]
struct Args {}

fn main() -> Result<()> {
    if completions::handle_completion_flag::<Args>() {
        return Ok(());
    }

    let _args = Args::parse();

    banner::print_banner("MACOS SETUP", "homebrew + fonts + dotfiles + tools", "blue");

    // Check if Homebrew is installed
    banner::divider("cyan");
    banner::status("□", "PHASE 1", "homebrew", "blue");

    if !which("brew") {
        println!("   {} installing Homebrew...", "→".blue());
        let status = Command::new("/bin/bash")
            .args([
                "-c",
                "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)",
            ])
            .stdin(Stdio::inherit())
            .status()
            .context("Failed to install Homebrew")?;

        if !status.success() {
            anyhow::bail!("Homebrew installation failed");
        }
        println!("   {} Homebrew installed", "✓".green());
    } else {
        println!("   {} Homebrew already installed", "✓".green());
    }

    // Install fonts
    banner::divider("cyan");
    banner::status("□", "PHASE 2", "fonts", "magenta");

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
        if which("install-font-macos") {
            let status = Command::new("install-font-macos")
                .arg(url)
                .stdout(Stdio::null())
                .status();

            if status.is_ok() {
                println!("   {} {}", "✓".green(), name);
            } else {
                println!("   {} {} (failed)", "⚠".yellow(), name);
            }
        } else {
            println!(
                "   {} {} (install-font-macos not found)",
                "⚠".yellow(),
                name
            );
        }
    }

    // Run brew bundle
    banner::divider("cyan");
    banner::status("□", "PHASE 3", "brew bundle", "green");

    let home = std::env::var("HOME")?;
    let brewfile = std::path::Path::new(&home).join("Brewfile");

    if brewfile.exists() {
        println!("   {} installing Homebrew packages...", "→".green());
        let status = Command::new("brew")
            .arg("bundle")
            .current_dir(&home)
            .status()
            .context("Failed to run brew bundle")?;

        if status.success() {
            println!("   {} brew bundle complete", "✓".green());
        } else {
            println!("   {} brew bundle failed", "⚠".yellow());
        }
    } else {
        println!("   {} Brewfile not found, skipping", "⚠".yellow());
    }

    // Run install script
    banner::divider("cyan");
    banner::status("□", "PHASE 4", "dotfiles install", "cyan");

    let dotfiles = std::path::Path::new(&home).join(".dotfiles");
    let install_script = dotfiles.join("install");

    if install_script.exists() {
        println!("   {} running install script...", "→".cyan());
        let status = Command::new("sh")
            .arg(&install_script)
            .current_dir(&home)
            .status()
            .context("Failed to run install script")?;

        if status.success() {
            println!("   {} install complete", "✓".green());
        } else {
            anyhow::bail!("Install script failed");
        }
    } else {
        println!("   {} install script not found", "⚠".yellow());
    }

    // Install mise tools
    banner::divider("cyan");
    banner::status("□", "PHASE 5", "mise install", "yellow");

    if which("mise") {
        println!("   {} installing mise tools...", "→".yellow());
        let status = Command::new("mise")
            .args(["install", "-y"])
            .stdin(Stdio::inherit())
            .status()
            .context("Failed to run mise install")?;

        if status.success() {
            println!("   {} mise tools installed", "✓".green());
        } else {
            println!("   {} mise install failed", "⚠".yellow());
        }
    } else {
        println!("   {} mise not found, skipping", "⚠".yellow());
    }

    // Set default Rust toolchain
    banner::divider("cyan");
    banner::status("□", "PHASE 6", "rustup default stable", "red");

    if which("rustup") {
        println!("   {} setting default Rust toolchain...", "→".red());
        let status = Command::new("rustup")
            .args(["default", "stable"])
            .stdout(Stdio::null())
            .status()
            .context("Failed to run rustup")?;

        if status.success() {
            println!("   {} rustup default stable", "✓".green());
        } else {
            println!("   {} rustup failed", "⚠".yellow());
        }
    } else {
        println!("   {} rustup not found, skipping", "⚠".yellow());
    }

    banner::divider("cyan");
    banner::success("MACOS SETUP COMPLETE");
    println!();

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
