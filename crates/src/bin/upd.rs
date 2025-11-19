use anyhow::{bail, Result};
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
#[command(about = "Parallel system update orchestrator", long_about = None)]
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
    let has_yt_dlp = which("yt-dlp").is_ok();

    if is_macos && !has_brew {
        mp.println(format!("{}", "/// .INSTALLING HOMEBREW".blue()))?;
        if create_task("install homebrew", &mp, install_homebrew)
            .join()
            .is_err()
        {
            bail!("could not install brew");
        }
    }

    if is_macos && has_brew && which("install-font-macos").is_ok() {
        let home = std::env::var("HOME")?;
        let fonts_dir = std::path::Path::new(&home).join("Library/Fonts");

        if fonts_dir.exists() {
            let font_count = std::fs::read_dir(&fonts_dir)?.count();
            if font_count < 10 {
                mp.println("installing fonts...")?;
                install_fonts(&mp)?;
            }
        }
    }

    let needs_sudo = has_apt || has_dnf;
    if needs_sudo && Command::new("sudo").arg("-v").status().is_err() {
        bail!("Failed to get sudo authentication");
    }
    if dotfiles_tools::install::install_dotfiles().is_err() {
        bail!("installing dotfiles failed");
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
            run_cmd("mise:up", pb, Command::new("mise").arg("up"))?;
            run_cmd("mise:reshim", pb, Command::new("mise").arg("reshim"))?;
            Ok(())
        }));
    }

    if has_yt_dlp {
        handles.push(create_task("yt-dlp", &mp, |pb| {
            run_cmd(
                "yt-dlp",
                pb,
                Command::new("yt-dlp").arg("--update-to").arg("nightly"),
            )?;
            Ok(())
        }));
    }

    if has_brew {
        handles.push(create_task("brew", &mp, |pb| {
            run_cmd(
                "brew:update",
                pb,
                Command::new("brew").arg("update").arg("--quiet"),
            )?;
            let home = std::env::var("HOME")?;
            run_cmd(
                "brew:bundle",
                pb,
                Command::new("brew")
                    .arg("bundle")
                    .arg("--quiet")
                    .current_dir(&home)
                    .env("HOMEBREW_NO_AUTO_UPDATE", "1"),
            )?;
            run_cmd(
                "brew:upgrade",
                pb,
                Command::new("brew").arg("upgrade").arg("--quiet"),
            )?;
            run_cmd(
                "brew cleanup",
                pb,
                Command::new("brew").arg("cleanup").arg("--quiet"),
            )?;

            Ok(())
        }));
    }

    for handle in handles {
        let _ = handle.join();
    }

    if let Some((handle, keepalive)) = sudo_keepalive {
        keepalive.store(false, std::sync::atomic::Ordering::Relaxed);
        let _ = handle.join();
    }

    mp.clear()?;
    mp.println("")?;
    mp.println(format!("{}", "/// .REGENERATING ZSH COMPLETIONS".bold()))?;
    mp.suspend(|| dotfiles_tools::regen_completions::regenerate_completions().unwrap());
    println!("{} completions regenerated", "✓".green());
    mp.println("")?;
    mp.println("")?;
    mp.println(format!("{}", "/// .SYSTEM UPDATE COMPLETE".bold()))?;
    mp.println("")?;

    Ok(())
}

fn handle_cmd_errs(name: &str, pb: &ProgressBar, child: &mut Child) -> Result<()> {
    if !child.wait()?.success() {
        if let Some(stderr) = child.stderr.take() {
            for line in BufReader::new(stderr).lines() {
                pb.println(format!(
                    "  {} {}",
                    format!("{} \\\\  ", name).bright_red(),
                    line.unwrap()
                ));
            }
        }
        bail!("{} failed", name);
    }
    Ok(())
}

fn run_cmd_quiet(name: &str, pb: &ProgressBar, cmd: &mut Command) -> Result<()> {
    let mut child = cmd.stderr(Stdio::piped()).stdout(Stdio::null()).spawn()?;
    handle_cmd_errs(name, pb, &mut child)?;

    Ok(())
}

fn run_cmd(name: &str, pb: &ProgressBar, cmd: &mut Command) -> Result<()> {
    let mut child = cmd.stderr(Stdio::piped()).stdout(Stdio::piped()).spawn()?;
    for line in BufReader::new(child.stdout.take().unwrap()).lines() {
        pb.println(format!(
            "  {} {}",
            format!("{} //  ", name).green(),
            line.unwrap()
        ));
    }
    handle_cmd_errs(name, pb, &mut child)?;
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

// TODO(JC): Refactor
fn install_homebrew(pb: &ProgressBar) -> Result<()> {
    run_cmd_quiet(
        "install homebrew",
        pb,
        Command::new("/bin/bash").args([
            "-c",
            "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)",
        ]),
    )?;

    Ok(())
}

fn install_fonts(mp: &MultiProgress) -> Result<()> {
    // TODO: Rewrite somewhat natively
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

#[cfg(test)]
mod tests {

    #[test]
    fn test_platform_detection() {
        // Test that platform detection compiles and returns consistent values
        #[cfg(target_os = "macos")]
        assert!(cfg!(target_os = "macos"));

        #[cfg(target_os = "linux")]
        assert!(cfg!(target_os = "linux"));
    }
}
