use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use dotfiles_tools::banner;
use dotfiles_tools::system::which;
use std::io;
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex};
use std::thread;

#[derive(Parser)]
#[command(name = "upd")]
#[command(about = "Parallel system update orchestrator", long_about = None)]
#[command(version)]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    /// Generate shell completions
    Completion {
        /// Shell to generate completions for
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

    // Check if Brewfile exists
    let has_brewfile = if is_macos && has_brew {
        let home = std::env::var("HOME")?;
        std::path::Path::new(&home).join("Brewfile").exists()
    } else {
        false
    };

    // PHASE 1: Get sudo authentication if needed
    let needs_sudo = has_apt || has_dnf;
    if needs_sudo {
        banner::status(
            "□",
            &format!("PHASE {}", phase),
            "sudo authentication",
            "red",
        );
        let status = Command::new("sudo").arg("-v").status()?;
        if !status.success() {
            anyhow::bail!("Failed to get sudo authentication");
        }
        phase += 1;
    }

    // Spawn background thread to keep sudo alive
    let sudo_keepalive = if needs_sudo {
        let keepalive = Arc::new(std::sync::atomic::AtomicBool::new(true));
        let keepalive_clone = keepalive.clone();
        Some((
            thread::spawn(move || {
                while keepalive_clone.load(std::sync::atomic::Ordering::Relaxed) {
                    thread::sleep(std::time::Duration::from_secs(60));
                    let _ = Command::new("sudo").arg("-v").status();
                }
            }),
            keepalive,
        ))
    } else {
        None
    };

    // PHASE 2: Everything in parallel
    banner::divider("cyan");
    banner::status(
        "□",
        &format!("PHASE {}", phase),
        "parallel updates",
        "magenta",
    );

    let results = Arc::new(Mutex::new(Vec::new()));
    let mut handles = vec![];

    // Dotfiles install
    {
        let results = results.clone();
        handles.push(thread::spawn(move || {
            println!("   {} dotfiles install", "→".cyan());
            let start = std::time::Instant::now();
            let result = dotfiles_tools::install::install_dotfiles();
            let duration = start.elapsed();
            let status = if result.is_ok() {
                "✓".green()
            } else {
                "✗".red()
            };
            println!("   {} dotfiles ({:.1}s)", status, duration.as_secs_f32());
            results.lock().unwrap().push(("dotfiles", result.is_ok()));
        }));
    }

    // apt-get (with sudo)
    if has_apt {
        let results = results.clone();
        handles.push(thread::spawn(move || {
            println!("   {} apt-get", "→".cyan());
            let start = std::time::Instant::now();
            let result = update_apt();
            let duration = start.elapsed();
            let status = if result.is_ok() {
                "✓".green()
            } else {
                "✗".red()
            };
            println!("   {} apt-get ({:.1}s)", status, duration.as_secs_f32());
            results.lock().unwrap().push(("apt-get", result.is_ok()));
        }));
    }

    // dnf (with sudo)
    if has_dnf {
        let results = results.clone();
        handles.push(thread::spawn(move || {
            println!("   {} dnf", "→".cyan());
            let start = std::time::Instant::now();
            let result = update_dnf();
            let duration = start.elapsed();
            let status = if result.is_ok() {
                "✓".green()
            } else {
                "✗".red()
            };
            println!("   {} dnf ({:.1}s)", status, duration.as_secs_f32());
            results.lock().unwrap().push(("dnf", result.is_ok()));
        }));
    }

    // mise setup
    if has_mise {
        let results = results.clone();
        handles.push(thread::spawn(move || {
            println!("   {} mise setup", "→".cyan());
            let start = std::time::Instant::now();
            let result = dotfiles_tools::system::install_mise_tools();
            let duration = start.elapsed();
            let status = if result.is_ok() {
                "✓".green()
            } else {
                "✗".red()
            };
            println!("   {} mise setup ({:.1}s)", status, duration.as_secs_f32());
            results.lock().unwrap().push(("mise-setup", result.is_ok()));
        }));
    }

    // rustup setup
    if has_rustup {
        let results = results.clone();
        handles.push(thread::spawn(move || {
            println!("   {} rustup setup", "→".cyan());
            let start = std::time::Instant::now();
            let result = dotfiles_tools::system::setup_rustup();
            let duration = start.elapsed();
            let status = if result.is_ok() {
                "✓".green()
            } else {
                "✗".red()
            };
            println!(
                "   {} rustup setup ({:.1}s)",
                status,
                duration.as_secs_f32()
            );
            results
                .lock()
                .unwrap()
                .push(("rustup-setup", result.is_ok()));
        }));
    }

    // brew (bundle + update)
    if has_brew {
        let results = results.clone();
        handles.push(thread::spawn(move || {
            println!("   {} brew", "→".cyan());
            let start = std::time::Instant::now();

            // Run bundle first if Brewfile exists
            let bundle_result = if has_brewfile { brew_bundle() } else { Ok(()) };

            // Then run updates
            let update_result = if bundle_result.is_ok() {
                update_brew()
            } else {
                bundle_result
            };

            let duration = start.elapsed();
            let status = if update_result.is_ok() {
                "✓".green()
            } else {
                "✗".red()
            };
            println!("   {} brew ({:.1}s)", status, duration.as_secs_f32());
            results
                .lock()
                .unwrap()
                .push(("brew", update_result.is_ok()));
        }));
    }

    // mise upgrade
    if has_mise {
        let results = results.clone();
        handles.push(thread::spawn(move || {
            println!("   {} mise upgrade", "→".cyan());
            let start = std::time::Instant::now();
            let result = update_mise();
            let duration = start.elapsed();
            let status = if result.is_ok() {
                "✓".green()
            } else {
                "✗".red()
            };
            println!(
                "   {} mise upgrade ({:.1}s)",
                status,
                duration.as_secs_f32()
            );
            results.lock().unwrap().push(("mise", result.is_ok()));
        }));
    }

    // yt-dlp
    if has_yt_dlp {
        let results = results.clone();
        handles.push(thread::spawn(move || {
            println!("   {} yt-dlp", "→".cyan());
            let start = std::time::Instant::now();
            let result = update_yt_dlp();
            let duration = start.elapsed();
            let status = if result.is_ok() {
                "✓".green()
            } else {
                "✗".red()
            };
            println!("   {} yt-dlp ({:.1}s)", status, duration.as_secs_f32());
            results.lock().unwrap().push(("yt-dlp", result.is_ok()));
        }));
    }

    // Wait for all parallel updates
    for handle in handles {
        handle.join().unwrap();
    }

    // Stop sudo keepalive
    if let Some((handle, keepalive)) = sudo_keepalive {
        keepalive.store(false, std::sync::atomic::Ordering::Relaxed);
        let _ = handle.join();
    }

    banner::divider("cyan");

    // Generate completions (after everything is updated)
    if has_regen {
        banner::status(
            "□",
            &format!("PHASE {}", phase + 1),
            "zsh completions",
            "green",
        );
        dotfiles_tools::regen_completions::regenerate_completions()?;
        println!("   {} completions regenerated", "✓".green());
    }

    banner::divider("cyan");
    banner::success("SYSTEM UPDATE COMPLETE");

    // Print summary
    let results = results.lock().unwrap().clone();
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
        .stdout(Stdio::inherit())
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_platform_detection() {
        // Test that platform detection compiles and returns consistent values
        #[cfg(target_os = "macos")]
        assert!(cfg!(target_os = "macos"));

        #[cfg(target_os = "linux")]
        assert!(cfg!(target_os = "linux"));
    }

    #[test]
    fn test_which_returns_bool() {
        let result = which("sh");
        // sh should exist on unix systems
        #[cfg(unix)]
        assert!(result);
    }
}
