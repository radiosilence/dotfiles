use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use dotfiles_tools::banner;
use dotfiles_tools::system::which;
use indicatif::{MultiProgress, ProgressBar, ProgressStyle};
use std::io::{self, BufRead, BufReader};
use std::process::{Command, Stdio};
use std::sync::{Arc, Mutex};
use std::thread;
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

    mp.suspend(|| {
        banner::print_banner(
            "SYSTEM UPDATE / システム更新",
            "idempotent system orchestrator / 冪等性システムオーケストレーター",
            "blue",
        );
    });

    // Detect platform and what's available
    let is_macos = cfg!(target_os = "macos");
    let has_brew = which("brew");
    let has_apt = which("apt-get");
    let has_dnf = which("dnf");
    let has_mise = which("mise");
    let has_yt_dlp = which("yt-dlp");
    let has_regen = which("regen-zsh-completions");
    let has_rustup = which("rustup");

    mp.suspend(|| {
        banner::divider("cyan");
        banner::status("□", "DETECTED / 検出", "", "cyan");

        if is_macos {
            println!("   {} macOS / マック", "✓".green());
        } else {
            println!("   {} Linux / リナックス", "✓".green());
        }

        if has_brew {
            println!("   {} brew / ブリュー", "✓".green());
        }
        if has_apt {
            println!("   {} apt-get / アプトゲット", "✓".green());
        }
        if has_dnf {
            println!("   {} dnf / ディーエヌエフ", "✓".green());
        }
        if has_mise {
            println!("   {} mise / ミーズ", "✓".green());
        }
        if has_rustup {
            println!("   {} rustup / ラストアップ", "✓".green());
        }
        if has_yt_dlp {
            println!("   {} yt-dlp / ワイティーディーエルピー", "✓".green());
        }
        if has_regen {
            println!("   {} zsh completions / 補完", "✓".green());
        }

        banner::divider("cyan");
    });

    // PHASE 1: Bootstrap missing package managers
    let mut phase = 1;
    if is_macos && !has_brew {
        mp.suspend(|| {
            banner::status(
                "□",
                &format!("PHASE {} / フェーズ {}", phase, phase),
                "install homebrew / ホームブリューインストール",
                "blue",
            );
        });
        install_homebrew(&mp)?;
        phase += 1;
        mp.suspend(|| {
            banner::divider("cyan");
        });
    }

    // PHASE: Install fonts (macOS only, if not already done)
    if is_macos && has_brew && which("install-font-macos") {
        let home = std::env::var("HOME")?;
        let fonts_dir = std::path::Path::new(&home).join("Library/Fonts");

        // Only try fonts if the fonts directory is relatively empty
        if fonts_dir.exists() {
            let font_count = std::fs::read_dir(&fonts_dir)?.count();
            if font_count < 10 {
                mp.suspend(|| {
                    banner::status(
                        "□",
                        &format!("PHASE {} / フェーズ {}", phase, phase),
                        "install fonts / フォントインストール",
                        "magenta",
                    );
                });
                install_fonts(&mp)?;
                phase += 1;
                mp.suspend(|| {
                    banner::divider("cyan");
                });
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
        mp.suspend(|| {
            banner::status(
                "□",
                &format!("PHASE {} / フェーズ {}", phase, phase),
                "sudo authentication / スード認証",
                "red",
            );
        });
        let status = Command::new("sudo").arg("-v").status()?;
        if !status.success() {
            anyhow::bail!("Failed to get sudo authentication / スード認証失敗");
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
    mp.suspend(|| {
        banner::divider("cyan");
        banner::status(
            "□",
            &format!("PHASE {} / フェーズ {}", phase, phase),
            "parallel updates / 並列更新",
            "magenta",
        );
    });
    mp.println("").unwrap(); // Blank line before spinners start

    let spinner_style = ProgressStyle::default_spinner();

    let results: Arc<Mutex<Vec<UpdateResult>>> = Arc::new(Mutex::new(Vec::new()));
    let mut handles = vec![];

    // Dotfiles install
    {
        let results = results.clone();
        let pb = mp.add(ProgressBar::new_spinner());
        pb.set_style(spinner_style.clone());
        pb.set_message("dotfiles / ドットファイル");
        pb.enable_steady_tick(Duration::from_millis(80));

        handles.push(thread::spawn(move || {
            let start = std::time::Instant::now();
            let result = dotfiles_tools::install::install_dotfiles();
            let duration = start.elapsed();
            let ok = result.is_ok();
            pb.finish_with_message(if ok {
                "✓ dotfiles / ドットファイル".green().to_string()
            } else {
                "✗ dotfiles / ドットファイル".red().to_string()
            });
            results
                .lock()
                .unwrap()
                .push(("dotfiles", ok, duration.as_secs_f32()));
        }));
    }

    // apt-get (with sudo)
    if has_apt {
        let results = results.clone();
        let pb = mp.add(ProgressBar::new_spinner());
        pb.set_style(spinner_style.clone());
        pb.set_message("apt-get / アプトゲット");
        pb.enable_steady_tick(Duration::from_millis(80));

        handles.push(thread::spawn(move || {
            let start = std::time::Instant::now();
            let result = update_apt();
            let duration = start.elapsed();
            let ok = result.is_ok();
            pb.finish_with_message(if ok {
                "✓ apt-get / アプトゲット".green().to_string()
            } else {
                "✗ apt-get / アプトゲット".red().to_string()
            });
            results
                .lock()
                .unwrap()
                .push(("apt-get", ok, duration.as_secs_f32()));
        }));
    }

    // dnf (with sudo)
    if has_dnf {
        let results = results.clone();
        let pb = mp.add(ProgressBar::new_spinner());
        pb.set_style(spinner_style.clone());
        pb.set_message("dnf / ディーエヌエフ");
        pb.enable_steady_tick(Duration::from_millis(80));

        handles.push(thread::spawn(move || {
            let start = std::time::Instant::now();
            let result = update_dnf();
            let duration = start.elapsed();
            let ok = result.is_ok();
            pb.finish_with_message(if ok {
                "✓ dnf / ディーエヌエフ".green().to_string()
            } else {
                "✗ dnf / ディーエヌエフ".red().to_string()
            });
            results
                .lock()
                .unwrap()
                .push(("dnf", ok, duration.as_secs_f32()));
        }));
    }

    // mise (install + upgrade)
    if has_mise {
        let results = results.clone();
        let pb = mp.add(ProgressBar::new_spinner());
        pb.set_style(spinner_style.clone());
        pb.set_message("mise / ミーズ");
        pb.enable_steady_tick(Duration::from_millis(80));

        handles.push(thread::spawn(move || {
            let start = std::time::Instant::now();
            // First install missing tools, then upgrade
            let install_result = dotfiles_tools::system::install_mise_tools();
            let result = if install_result.is_ok() {
                update_mise()
            } else {
                install_result
            };
            let duration = start.elapsed();
            let ok = result.is_ok();
            pb.finish_with_message(if ok {
                "✓ mise / ミーズ".green().to_string()
            } else {
                "✗ mise / ミーズ".red().to_string()
            });
            results
                .lock()
                .unwrap()
                .push(("mise", ok, duration.as_secs_f32()));
        }));
    }

    // rustup setup
    if has_rustup {
        let results = results.clone();
        let pb = mp.add(ProgressBar::new_spinner());
        pb.set_style(spinner_style.clone());
        pb.set_message("rustup-setup / ラストアップセットアップ");
        pb.enable_steady_tick(Duration::from_millis(80));

        handles.push(thread::spawn(move || {
            let start = std::time::Instant::now();
            let result = dotfiles_tools::system::setup_rustup();
            let duration = start.elapsed();
            let ok = result.is_ok();
            pb.finish_with_message(if ok {
                "✓ rustup-setup / ラストアップセットアップ"
                    .green()
                    .to_string()
            } else {
                "✗ rustup-setup / ラストアップセットアップ"
                    .red()
                    .to_string()
            });
            results
                .lock()
                .unwrap()
                .push(("rustup-setup", ok, duration.as_secs_f32()));
        }));
    }

    // brew (bundle + update)
    if has_brew {
        let results = results.clone();
        let pb = mp.add(ProgressBar::new_spinner());
        pb.set_style(spinner_style.clone());
        pb.set_message("brew / ブリュー");
        pb.enable_steady_tick(Duration::from_millis(80));

        handles.push(thread::spawn(move || {
            let start = std::time::Instant::now();
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
            let duration = start.elapsed();
            let ok = update_result.is_ok();
            pb.finish_with_message(if ok {
                "✓ brew / ブリュー".green().to_string()
            } else {
                "✗ brew / ブリュー".red().to_string()
            });
            results
                .lock()
                .unwrap()
                .push(("brew", ok, duration.as_secs_f32()));
        }));
    }

    // yt-dlp
    if has_yt_dlp {
        let results = results.clone();
        let pb = mp.add(ProgressBar::new_spinner());
        pb.set_style(spinner_style.clone());
        pb.set_message("yt-dlp / ワイティーディーエルピー");
        pb.enable_steady_tick(Duration::from_millis(80));

        handles.push(thread::spawn(move || {
            let start = std::time::Instant::now();
            let result = update_yt_dlp();
            let duration = start.elapsed();
            let ok = result.is_ok();
            pb.finish_with_message(if ok {
                "✓ yt-dlp / ワイティーディーエルピー".green().to_string()
            } else {
                "✗ yt-dlp / ワイティーディーエルピー".red().to_string()
            });
            results
                .lock()
                .unwrap()
                .push(("yt-dlp", ok, duration.as_secs_f32()));
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

    // Clear MultiProgress to remove all spinners and return to normal output
    mp.clear()?;

    banner::divider("cyan");

    // Generate completions (after everything is updated)
    if has_regen {
        banner::status(
            "□",
            &format!("PHASE {} / フェーズ {}", phase + 1, phase + 1),
            "zsh completions / 補完",
            "green",
        );
        dotfiles_tools::regen_completions::regenerate_completions()?;
        println!(
            "   {} completions regenerated / 補完再生成完了",
            "✓".green()
        );
    }

    banner::divider("cyan");

    // Print results
    let results = results.lock().unwrap().clone();
    for (name, ok, duration) in &results {
        let status = if *ok { "✓".green() } else { "✗".red() };
        println!("   {} {} ({:.1}s)", status, name, duration);
    }

    banner::divider("cyan");
    banner::success("SYSTEM UPDATE COMPLETE / システム更新完了");

    // Print summary
    let success_count = results.iter().filter(|(_, ok, _)| *ok).count();
    let total_count = results.len();

    println!(
        "\n   {} UPDATED / 更新  {} FAILED / 失敗\n",
        success_count.to_string().green().bold(),
        (total_count - success_count).to_string().red().bold()
    );

    Ok(())
}

fn install_homebrew(mp: &MultiProgress) -> Result<()> {
    mp.println(format!("   {} installing Homebrew...", "→".blue()))?;
    let status = Command::new("/bin/bash")
        .args([
            "-c",
            "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)",
        ])
        .stdin(Stdio::inherit())
        .status()?;

    if status.success() {
        mp.println(format!("   {} Homebrew installed", "✓".green()))?;
        Ok(())
    } else {
        anyhow::bail!("Homebrew installation failed")
    }
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
        mp.println(format!("   {} installing {} font...", "→".magenta(), name))?;
        let status = Command::new("install-font-macos")
            .arg(url)
            .stdout(Stdio::null())
            .status();

        if status.is_ok() {
            mp.println(format!("   {} {}", "✓".green(), name))?;
        } else {
            mp.println(format!("   {} {} (failed)", "⚠".yellow(), name))?;
        }
    }
    Ok(())
}

fn brew_bundle(pb: &ProgressBar) -> Result<Vec<String>> {
    let home = std::env::var("HOME")?;

    // Set HOMEBREW_NO_AUTO_UPDATE to prevent the "Updating Homebrew..." message
    let mut child = Command::new("brew")
        .arg("bundle")
        .arg("--verbose")
        .current_dir(&home)
        .env("HOMEBREW_NO_AUTO_UPDATE", "1")
        .stdin(Stdio::inherit()) // Allow interactive prompts (sudo, etc)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()?;

    let installed = Arc::new(Mutex::new(Vec::new()));

    // Spawn thread to consume stderr and only surface important messages
    let stderr_errors = Arc::new(Mutex::new(Vec::new()));
    if let Some(stderr) = child.stderr.take() {
        let errors = stderr_errors.clone();
        thread::spawn(move || {
            let reader = BufReader::new(stderr);
            for line in reader.lines().map_while(Result::ok) {
                // Surface errors, warnings, and sudo prompts - ignore noise like "Updating Homebrew..."
                if line.contains("Error")
                    || line.contains("error")
                    || line.contains("Warning")
                    || line.contains("warning")
                    || line.contains("Password")
                    || line.contains("password")
                    || line.contains("sudo")
                {
                    errors.lock().unwrap().push(line);
                }
            }
        });
    }

    // Spawn thread to parse stdout - NEVER block main thread on I/O
    if let Some(stdout) = child.stdout.take() {
        let installed_clone = installed.clone();
        let pb_clone = pb.clone();
        thread::spawn(move || {
            let reader = BufReader::new(stdout);
            for line in reader.lines().map_while(Result::ok) {
                // Parse brew bundle output: "Installing foo" or "Upgrading bar"
                if line.contains("Installing") {
                    if let Some(pkg) = line.split_whitespace().nth(1) {
                        pb_clone.set_message(format!("brew: installing {}", pkg));
                        installed_clone
                            .lock()
                            .unwrap()
                            .push(format!("installed {}", pkg));
                    }
                } else if line.contains("Upgrading") {
                    if let Some(pkg) = line.split_whitespace().nth(1) {
                        pb_clone.set_message(format!("brew: upgrading {}", pkg));
                        installed_clone
                            .lock()
                            .unwrap()
                            .push(format!("upgraded {}", pkg));
                    }
                }
            }
        });
    }

    let status = child.wait()?;

    // If brew bundle failed, bail with error message (don't print directly - would mess up spinners)
    if !status.success() {
        anyhow::bail!("brew bundle failed");
    }

    let installed_vec = installed.lock().unwrap().clone();
    Ok(installed_vec)
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

fn update_mise() -> Result<()> {
    let output = Command::new("mise").arg("up").output()?;

    let home = std::env::var("HOME")?;
    let shims_path = format!("{}/.local/share/mise/shims", home);
    if std::path::Path::new(&shims_path).exists() {
        std::fs::remove_dir_all(&shims_path)?;
    }

    Command::new("mise")
        .arg("reshim")
        .stdout(Stdio::null())
        .status()?;

    if !output.status.success() {
        anyhow::bail!("mise up failed");
    }

    Ok(())
}

fn update_yt_dlp() -> Result<()> {
    Command::new("yt-dlp")
        .args(["--update-to", "nightly"])
        .stdout(Stdio::null())
        .stderr(Stdio::null())
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
