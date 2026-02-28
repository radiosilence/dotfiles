use anyhow::{bail, Context, Result};
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use indicatif::{MultiProgress, ProgressBar, ProgressStyle};
use std::io::{self, BufRead, BufReader};
use std::process::{Child, Command, Stdio};
use std::sync::Arc;
use std::thread::{self, JoinHandle};
use std::time::Duration;
use which::which;

#[derive(Parser)]
#[command(name = "upd")]
#[command(about = "Update the system", long_about = None)]
#[command(version)]
struct Args {
    #[arg(short, long)]
    verbose: bool,

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

    let mp = MultiProgress::new();

    mp.println("")?;
    mp.println(format!("{}", "/// .SYSTEM UPDATE".bold()))?;
    mp.println("")?;

    let is_macos = cfg!(target_os = "macos");
    let has_brew = which("brew").is_ok();
    let has_apt = which("apt-get").is_ok();
    let has_dnf = which("dnf").is_ok();
    let has_mise = which("mise").is_ok();
    let has_claude = which("claude").is_ok();

    dotfiles_tools::install::install_dotfiles().context("installing dotfiles failed")?;

    let auth_status = if is_macos {
        check_auth_status(&mp)?
    } else {
        AuthStatus::default()
    };

    if is_macos {
        install_fonts(&mp)?;
    }

    let needs_sudo = has_apt || has_dnf || (is_macos && has_brew);
    let has_sudo = if needs_sudo {
        match Command::new("sudo").arg("-v").status() {
            Ok(s) if s.success() => true,
            _ => {
                // Hard requirement for apt/dnf - can't do much without sudo there
                if has_apt || has_dnf {
                    bail!("Failed to get sudo authentication");
                }
                // Brew can mostly work without sudo, just skip cask installs
                mp.println(format!(
                    "  {} sudo auth failed, brew bundle/casks may be skipped",
                    "!".yellow()
                ))?;
                false
            }
        }
    } else {
        false
    };

    // Spawn background thread to keep sudo alive
    let sudo_keepalive = if has_sudo {
        let keepalive = Arc::new(std::sync::atomic::AtomicBool::new(true));
        let keepalive_clone = keepalive.clone();
        Some((
            thread::spawn(move || {
                while keepalive_clone.load(std::sync::atomic::Ordering::Relaxed) {
                    let _ = Command::new("sudo").arg("-v").status();
                    thread::sleep(std::time::Duration::from_secs(60));
                }
            }),
            keepalive,
        ))
    } else {
        None
    };

    let mut handles = vec![];

    if has_apt {
        handles.push(create_task("apt", &mp, |pb| {
            run_cmd(
                "apt:update",
                pb,
                Command::new("sudo").args(["apt-get", "update"]),
            )?;
            run_cmd(
                "apt:upgrade",
                pb,
                Command::new("sudo").args(["apt-get", "upgrade", "-y"]),
            )?;
            run_cmd(
                "apt:autoremove",
                pb,
                Command::new("sudo").args(["apt-get", "autoremove", "-y"]),
            )?;
            Ok(())
        }));
    }

    if has_dnf {
        handles.push(create_task("dnf", &mp, |pb| {
            run_cmd(
                "dnf:update",
                pb,
                Command::new("sudo").args(["dnf", "update", "-y"]),
            )?;
            Ok(())
        }));
    }
    if has_mise {
        handles.push(create_task("mise", &mp, |pb| {
            let home = dotfiles_tools::home_dir()?;

            run_cmd(
                "mise:up",
                pb,
                Command::new("mise").arg("up").current_dir(&home),
            )?;
            run_cmd(
                "mise:reshim",
                pb,
                Command::new("mise").arg("reshim").current_dir(&home),
            )?;
            Ok(())
        }));
    }

    if has_claude {
        handles.push(create_task("claude", &mp, |pb| {
            run_cmd(
                "claude:update",
                pb,
                Command::new("claude").arg("--update"),
            )?;
            Ok(())
        }));
    }

    // brew bundle may require sudo for casks, run it interactively before parallel tasks
    if has_brew {
        let home = dotfiles_tools::home_dir()?;
        mp.println(format!(
            "{}",
            "/// .BREW BUNDLE (may prompt for sudo)".blue()
        ))?;
        let bundle_result = mp.suspend(|| {
            Command::new("brew")
                .args(["bundle", "--quiet"])
                .current_dir(&home)
                .stdin(Stdio::inherit())
                .stdout(Stdio::inherit())
                .stderr(Stdio::inherit())
                .status()
        });
        match bundle_result {
            Ok(status) if status.success() => {
                mp.println(format!("{} brew bundle complete", "✓".green()))?;
            }
            Ok(_) => {
                mp.println(format!("{} brew bundle failed (continuing)", "✗".red()))?;
            }
            Err(e) => {
                mp.println(format!(
                    "{} brew bundle error: {} (continuing)",
                    "✗".red(),
                    e
                ))?;
            }
        }
        mp.println("")?;

        handles.push(create_task("brew", &mp, |pb| {
            let update_ok = run_cmd(
                "brew:update",
                pb,
                Command::new("brew").arg("update").arg("--quiet"),
            )
            .is_ok();
            let upgrade_ok = run_cmd(
                "brew:upgrade",
                pb,
                Command::new("brew").args(["upgrade", "--greedy", "--quiet"]),
            )
            .is_ok();
            let cleanup_ok = run_cmd(
                "brew cleanup",
                pb,
                Command::new("brew").arg("cleanup").arg("--quiet"),
            )
            .is_ok();

            if !update_ok {
                bail!("Failed to update brew")
            }
            if !upgrade_ok {
                bail!("Failed to upgrade brew")
            }
            if !cleanup_ok {
                bail!("Failed to cleanup brew")
            }
            Ok(())
        }));
    }

    let mut any_failed = false;
    for handle in handles {
        if let Ok(false) = handle.join() {
            any_failed = true;
        }
    }

    if let Some((handle, keepalive)) = sudo_keepalive {
        keepalive.store(false, std::sync::atomic::Ordering::Relaxed);
        let _ = handle.join();
    }

    mp.clear()?;

    println!();
    println!("{}", "/// .REGENERATING ZSH COMPLETIONS".bold());
    println!();
    dotfiles_tools::regen_completions::regenerate_completions()?;

    // Summary
    println!();
    println!("{}", "/// .STATUS".bold());
    println!();

    let mut manual_steps: Vec<String> = vec![];

    if !auth_status.gh_ok && which("gh").is_ok() {
        manual_steps.push("gh auth login".to_string());
    }

    if !auth_status.op_ok && which("op").is_ok() {
        manual_steps.push(
            "1Password: Settings -> Developer -> CLI Integration, then 'op plugin init'"
                .to_string(),
        );
    }

    if manual_steps.is_empty() {
        println!("  {} all good", "✓".green());
    } else {
        println!("  {} remaining manual steps:", "→".yellow());
        for step in &manual_steps {
            println!("    {} {}", "·".bright_black(), step);
        }
    }

    println!();
    if any_failed {
        println!(
            "{}",
            "/// .SYSTEM UPDATE COMPLETE (with errors)".yellow().bold()
        );
    } else {
        println!("{}", "/// .SYSTEM UPDATE COMPLETE".bold());
    }
    println!();

    Ok(())
}

#[derive(Default)]
struct AuthStatus {
    gh_ok: bool,
    op_ok: bool,
}

fn check_auth_status(mp: &MultiProgress) -> Result<AuthStatus> {
    mp.println(format!("{}", "/// .AUTH STATUS".bold()))?;

    let gh_ok = which("gh").is_ok()
        && Command::new("gh")
            .args(["auth", "status"])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
            .map(|s| s.success())
            .unwrap_or(false);

    if which("gh").is_ok() {
        if gh_ok {
            mp.println(format!("  {} gh", "✓".green()))?;
        } else {
            mp.println(format!("  {} gh not authenticated", "!".yellow()))?;
            mp.println(format!("     run: {}", "gh auth login".cyan()))?;
        }
    }

    let op_ok = which("op").is_ok()
        && Command::new("op")
            .args(["account", "list"])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
            .map(|s| s.success())
            .unwrap_or(false);

    if which("op").is_ok() {
        if op_ok {
            mp.println(format!("  {} 1password cli", "✓".green()))?;
        } else {
            mp.println(format!("  {} 1password cli not integrated", "!".yellow()))?;
            mp.println("     1. open 1Password -> Settings -> Developer -> CLI Integration")?;
            mp.println(format!("     2. run: {}", "op plugin init".cyan()))?;
        }
    }

    mp.println("")?;
    Ok(AuthStatus { gh_ok, op_ok })
}

fn handle_cmd_errs(name: &str, pb: &ProgressBar, child: &mut Child) -> Result<()> {
    if !child.wait()?.success() {
        if let Some(stderr) = child.stderr.take() {
            for line in BufReader::new(stderr).lines().map_while(Result::ok) {
                pb.println(format!("  {} {}", format!("{}  ", name).bright_red(), line));
            }
        }
        bail!("{} failed", name);
    }
    Ok(())
}

fn run_cmd(name: &str, pb: &ProgressBar, cmd: &mut Command) -> Result<()> {
    let mut child = cmd.stderr(Stdio::piped()).stdout(Stdio::piped()).spawn()?;
    if let Some(stdout) = child.stdout.take() {
        for line in BufReader::new(stdout).lines().map_while(Result::ok) {
            pb.println(format!("  {} {}", format!("{}  ", name).green(), line));
        }
    }
    handle_cmd_errs(name, pb, &mut child)?;
    Ok(())
}

fn create_task<F>(name: &str, mp: &MultiProgress, cb: F) -> JoinHandle<bool>
where
    F: Fn(&ProgressBar) -> Result<(), anyhow::Error> + Send + 'static,
{
    let pb = mp.add(ProgressBar::new_spinner());
    pb.set_style(ProgressStyle::default_spinner());
    pb.enable_steady_tick(Duration::from_millis(80));
    pb.set_message(String::from(name));
    thread::spawn(move || {
        let success = cb(&pb).is_ok();
        pb.set_style(if success {
            ProgressStyle::with_template("{spinner:.green} {msg}")
                .unwrap()
                .tick_strings(&["✓"])
        } else {
            ProgressStyle::with_template("{spinner:.red} {msg}")
                .unwrap()
                .tick_strings(&["✗"])
        });
        pb.finish();
        success
    })
}

fn install_fonts(mp: &MultiProgress) -> Result<()> {
    // (name, url, marker file to check if already installed)
    let fonts: &[(&str, &str, &str)] = &[
        (
            "Hack Ligatured",
            "https://github.com/gaplo917/Ligatured-Hack/releases/download/v3.003%2BNv2.1.0%2BFC%2BJBMv2.242/HackLigatured-v3.003+FC3.1+JBMv2.242.zip",
            "HackNerdFontJBMLigatured-Regular.ttf",
        ),
        (
            "Geist",
            "https://github.com/vercel/geist-font/releases/download/1.6.0/Geist-1.6.0.zip",
            "Geist-Regular.otf",
        ),
        (
            "Geist Mono",
            "https://github.com/vercel/geist-font/releases/download/1.6.0/GeistMono-1.6.0.zip",
            "GeistMono-Regular.otf",
        ),
        (
            "Geist Mono Nerd Font",
            "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/GeistMono.zip",
            "GeistMonoNerdFont-Regular.otf",
        ),
    ];

    let fonts_dir = dotfiles_tools::home_dir()?.join("Library/Fonts");
    std::fs::create_dir_all(&fonts_dir)?;

    let missing: Vec<_> = fonts
        .iter()
        .filter(|(_, _, marker)| !fonts_dir.join(marker).exists())
        .collect();

    if missing.is_empty() {
        return Ok(());
    }

    let client = reqwest::blocking::Client::builder()
        .timeout(std::time::Duration::from_secs(120))
        .build()?;

    for (name, url, _) in missing {
        mp.println(format!("{} installing {}...", "→".magenta(), name))?;

        match install_font(&client, url, &fonts_dir) {
            Ok(count) => {
                mp.println(format!("{} {} ({} files)", "✓".green(), name, count))?;
            }
            Err(e) => {
                mp.println(format!("{} {} ({})", "⚠".yellow(), name, e))?;
            }
        }
    }
    Ok(())
}

fn install_font(
    client: &reqwest::blocking::Client,
    url: &str,
    fonts_dir: &std::path::Path,
) -> Result<usize> {
    let response = client.get(url).send()?;
    if !response.status().is_success() {
        bail!("HTTP {}", response.status());
    }

    let bytes = response.bytes()?;
    let cursor = std::io::Cursor::new(bytes);
    let mut archive = zip::ZipArchive::new(cursor)?;

    let mut count = 0;
    for i in 0..archive.len() {
        let mut file = archive.by_index(i)?;
        let name = file.name().to_string();

        // Only install .otf and .ttf files
        let lower = name.to_lowercase();
        if !lower.ends_with(".otf") && !lower.ends_with(".ttf") {
            continue;
        }

        // Extract just the filename, not the full path
        let filename = std::path::Path::new(&name)
            .file_name()
            .map(|s| s.to_string_lossy().to_string())
            .unwrap_or(name);

        let dest = fonts_dir.join(&filename);
        let mut outfile = std::fs::File::create(&dest)?;
        std::io::copy(&mut file, &mut outfile)?;
        count += 1;
    }

    Ok(count)
}
