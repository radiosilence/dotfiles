use anyhow::{Context, Result};
use colored::Colorize;
use std::process::{Command, Stdio};

use crate::{banner, system::which};

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Platform {
    MacOS,
    Linux,
}

impl Platform {
    pub fn detect() -> Option<Self> {
        if cfg!(target_os = "macos") {
            Some(Platform::MacOS)
        } else if cfg!(target_os = "linux") {
            Some(Platform::Linux)
        } else {
            None
        }
    }

    pub fn name(&self) -> &'static str {
        match self {
            Platform::MacOS => "macOS",
            Platform::Linux => "Linux",
        }
    }
}

pub fn setup(platform: Platform) -> Result<()> {
    banner::print_banner(
        "SYSTEM SETUP",
        &format!("{} bootstrap + dotfiles", platform.name()),
        "blue",
    );

    match platform {
        Platform::MacOS => setup_macos(),
        Platform::Linux => setup_linux(),
    }
}

fn setup_macos() -> Result<()> {
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

    run_common_setup()
}

fn setup_linux() -> Result<()> {
    // Detect package manager
    banner::divider("cyan");
    banner::status("□", "PHASE 1", "package manager", "blue");

    if which("apt-get") {
        println!("   {} detected apt-get", "✓".green());
        println!("   {} updating packages...", "→".blue());
        let status = Command::new("sudo")
            .args(["apt-get", "update"])
            .stdin(Stdio::inherit())
            .status()?;

        if status.success() {
            println!("   {} packages updated", "✓".green());
        }
    } else if which("dnf") {
        println!("   {} detected dnf", "✓".green());
    } else {
        println!("   {} no supported package manager found", "⚠".yellow());
    }

    run_common_setup()
}

fn run_common_setup() -> Result<()> {
    let home = std::env::var("HOME")?;

    // Run brew bundle if on macOS
    if cfg!(target_os = "macos") {
        banner::divider("cyan");
        banner::status("□", "PHASE 3", "brew bundle", "green");

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
    }

    // Run install-dotfiles
    banner::divider("cyan");
    banner::status("□", "PHASE 4", "dotfiles install", "cyan");
    println!();

    crate::install::install_dotfiles()?;

    // Install mise tools
    banner::divider("cyan");
    banner::status("□", "PHASE 5", "mise install", "yellow");
    crate::system::install_mise_tools()?;

    // Set default Rust toolchain
    banner::divider("cyan");
    banner::status("□", "PHASE 6", "rustup default stable", "red");
    crate::system::setup_rustup()?;

    banner::divider("cyan");
    banner::success("SYSTEM SETUP COMPLETE");
    println!();

    Ok(())
}
