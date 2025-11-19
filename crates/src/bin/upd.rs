use anyhow::{bail, Result};
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use dotfiles_tools::system::which;
use indicatif::{MultiProgress, ProgressBar, ProgressStyle};
use std::io::{self, BufRead, BufReader};
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex};
use std::thread::{self, JoinHandle};
use std::time::Duration;

type UpdateResult = (&'static str, bool, f32);

#[derive(Parser)]
#[command(name = "upd")]
#[command(about = "Parallel system update orchestrator", long_about = None)]
#[command(version)]
struct Args {
    /// Show verbose output from all commands
    #[arg(short, long)]
    verbose: bool,

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

    // Create MultiProgress FIRST - use for ALL output
    let mp = MultiProgress::new();

    mp.println("[SYSTEM UPDATE]")?;

    // Detect platform and what's available
    let is_macos = cfg!(target_os = "macos");
    let has_brew = which("brew");
    let has_apt = which("apt-get");
    let has_dnf = which("dnf");
    let has_mise = which("mise");
    let has_yt_dlp = which("yt-dlp");
    let has_regen = which("regen-zsh-completions");
    let has_rustup = which("rustup");

    // PHASE 1: Bootstrap missing package managers
    if is_macos && !has_brew {
        install_homebrew(&mp)?;
    }

    // PHASE: Install fonts (macOS only, if not already done)
    if is_macos && has_brew && which("install-font-macos") {
        let home = std::env::var("HOME")?;
        let fonts_dir = std::path::Path::new(&home).join("Library/Fonts");

        // Only try fonts if the fonts directory is relatively empty
        if fonts_dir.exists() {
            let font_count = std::fs::read_dir(&fonts_dir)?.count();
            if font_count < 10 {
                mp.println("installing fonts...")?;
                install_fonts(&mp)?;
            }
        }
    }

    // Check if Brewfile exists
    let has_brewfile = is_macos && has_brew && {
        let home = std::env::var("HOME")?;
        std::path::Path::new(&home).join("Brewfile").exists()
    };

    let needs_sudo = has_apt || has_dnf;
    if needs_sudo {
        let status = Command::new("sudo").arg("-v").status()?;
        if !status.success() {
            bail!("Failed to get sudo authentication");
        }
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

    let spinner_style = ProgressStyle::default_spinner();
    let spinner_success = ProgressStyle::with_template("{spinner:.green} {msg}")
        .unwrap()
        .tick_strings(&["✓"]);
    let spinner_failure = ProgressStyle::with_template("{spinner:.red} {msg}")
        .unwrap()
        .tick_strings(&["✗"]);

    let mut handles = vec![];

    // Dotfiles install
    {
        let success_style = spinner_success.clone();
        let failure_style = spinner_failure.clone();
        let pb = mp.add(ProgressBar::new_spinner());
        pb.set_style(spinner_style.clone());
        pb.set_message("dotfiles");
        pb.enable_steady_tick(Duration::from_millis(80));

        handles.push(create_task("install_dotfiles", &mp, install_dotfiles));
    }

    // apt-get (with sudo)
    if has_apt {
        let success_style = spinner_success.clone();
        let failure_style = spinner_failure.clone();
        let pb = mp.add(ProgressBar::new_spinner());
        pb.set_style(spinner_style.clone());
        pb.set_message("apt-get");
        pb.enable_steady_tick(Duration::from_millis(80));

        handles.push(thread::spawn(move || {
            let result = update_apt();
            let ok = result.is_ok();

            if ok {
                pb.set_style(success_style);
            } else {
                pb.set_style(failure_style);
            }
            pb.finish();
        }));
    }

    // dnf (with sudo)
    if has_dnf {
        let success_style = spinner_success.clone();
        let failure_style = spinner_failure.clone();
        let pb = mp.add(ProgressBar::new_spinner());
        pb.set_style(spinner_style.clone());
        pb.set_message("dnf");
        pb.enable_steady_tick(Duration::from_millis(80));

        handles.push(thread::spawn(move || {
            let result = update_dnf();
            let ok = result.is_ok();

            if ok {
                pb.set_style(success_style);
            } else {
                pb.set_style(failure_style);
            }
            pb.finish();
        }));
    }

    // mise (install + upgrade)
    if has_mise {
        handles.push(create_task("mise", &mp, &update_mise));
    }

    // brew (bundle + update)
    if has_brew {
        let success_style = spinner_success.clone();
        let failure_style = spinner_failure.clone();
        let pb = mp.add(ProgressBar::new_spinner());
        pb.set_style(spinner_style.clone());
        pb.set_message("brew");
        pb.enable_steady_tick(Duration::from_millis(80));

        handles.push(thread::spawn(move || {
            let bundle_result = if has_brewfile {
                brew_bundle(&pb).map(|_| ())
            } else {
                Ok(())
            };
            let update_result = if bundle_result.is_ok() {
                update_brew()
            } else {
                bundle_result
            };
            let ok = update_result.is_ok();

            if ok {
                pb.set_style(success_style);
            } else {
                pb.set_style(failure_style);
            }
            pb.finish();
        }));
    }

    // yt-dlp
    if has_yt_dlp {
        let success_style = spinner_success.clone();
        let failure_style = spinner_failure.clone();
        let pb = mp.add(ProgressBar::new_spinner());
        pb.set_style(spinner_style.clone());
        pb.set_message("yt-dlp");
        pb.enable_steady_tick(Duration::from_millis(80));

        handles.push(create_task("yt-dlp", &mp, &update_yt_dlp));
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

    // Clear MultiProgress to remove all spinners and return to normal output
    mp.clear()?;

    // Generate completions (after everything is updated)
    if has_regen {
        dotfiles_tools::regen_completions::regenerate_completions()?;
        println!("{} completions regenerated", "✓".green());
    }

    mp.println("SYSTEM UPDATE COMPLETE / システム更新完了")?;

    Ok(())
}

fn install_homebrew(mp: &MultiProgress) -> Result<()> {
    mp.println(format!("{} installing Homebrew...", "→".blue()))?;
    Command::new("/bin/bash")
        .args([
            "-c",
            "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)",
        ])
        .stdin(Stdio::inherit())
        .status()
        .expect("Homebrew installation failed!");
    Ok(())
}

fn install_fonts(mp: &MultiProgress) -> Result<()> {
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
        mp.println(format!("{} installing {} font...", "→".magenta(), name,))?;
        let status = Command::new("install-font-macos")
            .arg(url)
            .stdout(Stdio::null())
            .status();

        if status.is_ok() {
            mp.println(format!("{} {} / 完了", "✓".green(), name))?;
        } else {
            mp.println(format!("{} {} (failed / 失敗)", "⚠".yellow(), name))?;
        }
    }
    Ok(())
}

fn install_dotfiles(_pb: &ProgressBar) -> Result<()> {
    if !dotfiles_tools::install::install_dotfiles().is_ok() {
        bail!("installing dotfiles failed");
    }
    Ok(())
}

fn brew_bundle(pb: &ProgressBar) -> Result<()> {
    let home = std::env::var("HOME")?;

    // Set HOMEBREW_NO_AUTO_UPDATE to prevent the "Updating Homebrew..." message
    let mut child = Command::new("brew")
        .arg("bundle")
        .arg("--quiet")
        .current_dir(&home)
        .env("HOMEBREW_NO_AUTO_UPDATE", "1")
        .stdin(Stdio::inherit()) // Allow interactive prompts (sudo, etc)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()?;

    let stdout = child.stdout.take().unwrap();
    let reader = BufReader::new(stdout);
    for line in reader.lines() {
        pb.println(line.unwrap());
    }
    child.wait()?;

    Ok(())
}

fn create_task<F>(name: &str, mp: &MultiProgress, cb: F) -> JoinHandle<()>
where
    F: Fn(&ProgressBar) -> Result<(), anyhow::Error> + Send + 'static,
{
    let pb = mp.add(ProgressBar::new_spinner());
    pb.set_style(ProgressStyle::default_spinner());
    pb.enable_steady_tick(Duration::from_millis(80));
    pb.set_message(String::from(name));
    thread::spawn(move || {
        pb.set_style(match cb(&pb) {
            Ok(_) => ProgressStyle::with_template("{spinner:.green} {msg}")
                .unwrap()
                .tick_strings(&["✓"]),
            Err(_) => ProgressStyle::with_template("{spinner:.red} {msg}")
                .unwrap()
                .tick_strings(&["✗"]),
        });
        pb.finish();
    })
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
        .stderr(Stdio::null())
        .status()?;

    Command::new("brew")
        .arg("upgrade")
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()?;

    Command::new("brew")
        .arg("cleanup")
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()?;

    Ok(())
}

fn update_mise(pb: &ProgressBar) -> Result<()> {
    let mut child = Command::new("mise")
        .arg("up")
        .stdout(Stdio::null())
        .stderr(Stdio::piped())
        .spawn()?;

    if !child.wait()?.success() {
        for line in BufReader::new(child.stderr.take().unwrap()).lines() {
            pb.println(line.unwrap());
        }
        bail!("mise up failed");
    }

    if !Command::new("mise").arg("reshim").status()?.success() {
        bail!("mise reshim failed");
    }

    Ok(())
}

fn update_yt_dlp(_pb: &ProgressBar) -> Result<()> {
    if !Command::new("yt-dlp")
        .args(["--update-to", "nightly"])
        .stdout(Stdio::null())
        .stderr(Stdio::inherit())
        .status()?
        .success()
    {
        bail!("yt-dlp update failed");
    }

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
