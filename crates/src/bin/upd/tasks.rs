use anyhow::{bail, Context, Result};
use std::io::{BufRead, BufReader};
use std::process::{Command, Stdio};
use std::thread::{self, JoinHandle};
use which::which;

use super::app::SharedState;

/// Run a command, streaming stdout/stderr lines into the shared state.
fn run_cmd(name: &str, state: &SharedState, task_idx: usize, cmd: &mut Command) -> Result<()> {
    {
        let mut s = state.lock().unwrap();
        s.set_step(task_idx, name);
    }

    let mut child = cmd.stderr(Stdio::piped()).stdout(Stdio::piped()).spawn()?;

    // Read stdout in a thread
    let stdout_state = state.clone();
    let stdout_idx = task_idx;
    let stdout_name = name.to_string();
    let stdout_handle = child.stdout.take().map(|stdout| {
        thread::spawn(move || {
            for line in BufReader::new(stdout).lines().map_while(Result::ok) {
                let mut s = stdout_state.lock().unwrap();
                s.push_output(stdout_idx, format!("{}: {}", stdout_name, line));
            }
        })
    });

    // Read stderr
    let stderr_state = state.clone();
    let stderr_idx = task_idx;
    let stderr_name = name.to_string();
    let stderr_handle = child.stderr.take().map(|stderr| {
        thread::spawn(move || {
            for line in BufReader::new(stderr).lines().map_while(Result::ok) {
                let mut s = stderr_state.lock().unwrap();
                s.push_output(stderr_idx, format!("{}: {}", stderr_name, line));
            }
        })
    });

    let status = child.wait()?;

    if let Some(h) = stdout_handle {
        let _ = h.join();
    }
    if let Some(h) = stderr_handle {
        let _ = h.join();
    }

    if !status.success() {
        bail!("{} failed (exit {})", name, status.code().unwrap_or(-1));
    }

    Ok(())
}

pub fn spawn_brew(state: SharedState, task_idx: usize) -> JoinHandle<()> {
    thread::spawn(move || {
        {
            let mut s = state.lock().unwrap();
            s.set_running(task_idx, "brew:update");
        }

        let result = (|| -> Result<()> {
            run_cmd(
                "brew:update",
                &state,
                task_idx,
                Command::new("brew").args(["update", "--quiet"]),
            )?;
            run_cmd(
                "brew:upgrade",
                &state,
                task_idx,
                Command::new("brew").args(["upgrade", "--greedy", "--quiet"]),
            )?;
            run_cmd(
                "brew:cleanup",
                &state,
                task_idx,
                Command::new("brew").args(["cleanup", "--quiet"]),
            )?;
            Ok(())
        })();

        let mut s = state.lock().unwrap();
        match result {
            Ok(()) => s.set_done(task_idx),
            Err(e) => s.set_failed(task_idx, e.to_string()),
        }
    })
}

pub fn spawn_apt(state: SharedState, task_idx: usize) -> JoinHandle<()> {
    thread::spawn(move || {
        {
            let mut s = state.lock().unwrap();
            s.set_running(task_idx, "apt:update");
        }

        let result = (|| -> Result<()> {
            run_cmd(
                "apt:update",
                &state,
                task_idx,
                Command::new("sudo").args(["apt-get", "update"]),
            )?;
            run_cmd(
                "apt:upgrade",
                &state,
                task_idx,
                Command::new("sudo").args(["apt-get", "upgrade", "-y"]),
            )?;
            run_cmd(
                "apt:autoremove",
                &state,
                task_idx,
                Command::new("sudo").args(["apt-get", "autoremove", "-y"]),
            )?;
            Ok(())
        })();

        let mut s = state.lock().unwrap();
        match result {
            Ok(()) => s.set_done(task_idx),
            Err(e) => s.set_failed(task_idx, e.to_string()),
        }
    })
}

pub fn spawn_dnf(state: SharedState, task_idx: usize) -> JoinHandle<()> {
    thread::spawn(move || {
        {
            let mut s = state.lock().unwrap();
            s.set_running(task_idx, "dnf:update");
        }

        let result = run_cmd(
            "dnf:update",
            &state,
            task_idx,
            Command::new("sudo").args(["dnf", "update", "-y"]),
        );

        let mut s = state.lock().unwrap();
        match result {
            Ok(()) => s.set_done(task_idx),
            Err(e) => s.set_failed(task_idx, e.to_string()),
        }
    })
}

pub fn spawn_mise(state: SharedState, task_idx: usize) -> JoinHandle<()> {
    thread::spawn(move || {
        {
            let mut s = state.lock().unwrap();
            s.set_running(task_idx, "mise:up");
        }

        let result = (|| -> Result<()> {
            let home = dotfiles_tools::home_dir()?;
            run_cmd(
                "mise:up",
                &state,
                task_idx,
                Command::new("mise").arg("up").current_dir(&home),
            )?;
            run_cmd(
                "mise:reshim",
                &state,
                task_idx,
                Command::new("mise").arg("reshim").current_dir(&home),
            )?;
            Ok(())
        })();

        let mut s = state.lock().unwrap();
        match result {
            Ok(()) => s.set_done(task_idx),
            Err(e) => s.set_failed(task_idx, e.to_string()),
        }
    })
}

pub fn spawn_claude(state: SharedState, task_idx: usize) -> JoinHandle<()> {
    thread::spawn(move || {
        {
            let mut s = state.lock().unwrap();
            s.set_running(task_idx, "claude:update");
        }

        let result = run_cmd(
            "claude:update",
            &state,
            task_idx,
            Command::new("claude").arg("--update"),
        );

        let mut s = state.lock().unwrap();
        match result {
            Ok(()) => s.set_done(task_idx),
            Err(e) => s.set_failed(task_idx, e.to_string()),
        }
    })
}

pub fn spawn_tmux_plugins(state: SharedState, task_idx: usize) -> JoinHandle<()> {
    thread::spawn(move || {
        {
            let mut s = state.lock().unwrap();
            s.set_running(task_idx, "tmux:plugins");
        }

        let plugins: Vec<(&str, &str)> = vec![
            (
                "tmux-resurrect",
                "https://github.com/tmux-plugins/tmux-resurrect.git",
            ),
            ("tmux-fzf-url", "https://github.com/wfxr/tmux-fzf-url.git"),
        ];

        let result = (|| -> Result<()> {
            let plugins_dir = dotfiles_tools::home_dir()?.join(".tmux/plugins");
            std::fs::create_dir_all(&plugins_dir)?;

            for (name, url) in &plugins {
                let dest = plugins_dir.join(name);
                if dest.exists() {
                    run_cmd(
                        &format!("tmux:{name}:pull"),
                        &state,
                        task_idx,
                        Command::new("git")
                            .args(["pull", "--quiet"])
                            .current_dir(&dest),
                    )?;
                } else {
                    run_cmd(
                        &format!("tmux:{name}:clone"),
                        &state,
                        task_idx,
                        Command::new("git").args([
                            "clone",
                            "--quiet",
                            url,
                            &dest.to_string_lossy(),
                        ]),
                    )?;
                }
            }
            Ok(())
        })();

        let mut s = state.lock().unwrap();
        match result {
            Ok(()) => s.set_done(task_idx),
            Err(e) => s.set_failed(task_idx, e.to_string()),
        }
    })
}

/// Run pre-TUI steps that need stdout (link, auth checks, fonts, brew bundle).
/// Returns (auth_status, has_sudo).
pub fn run_pre_tui() -> Result<(AuthStatus, bool)> {
    let is_macos = cfg!(target_os = "macos");
    let has_brew = which("brew").is_ok();
    let has_apt = which("apt-get").is_ok();
    let has_dnf = which("dnf").is_ok();

    println!();
    println!("  {} {}", "⟢".magenta().bold(), "system update".bold());
    println!();

    // Link dotfiles
    let dotfiles_dir = dotfiles_tools::home_dir()?.join(".dotfiles");
    let link_status = Command::new("mise")
        .args(["run", "link"])
        .current_dir(&dotfiles_dir)
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit())
        .status()
        .context("failed to run mise run link")?;
    if !link_status.success() {
        bail!("mise run link failed");
    }

    let auth_status = if is_macos {
        check_auth_status()?
    } else {
        AuthStatus::default()
    };

    if is_macos {
        install_fonts()?;
    }

    let needs_sudo = has_apt || has_dnf || (is_macos && has_brew);
    let has_sudo = if needs_sudo {
        match Command::new("sudo").arg("-v").status() {
            Ok(s) if s.success() => true,
            _ => {
                if has_apt || has_dnf {
                    bail!("Failed to get sudo authentication");
                }
                println!(
                    "    {} sudo auth failed, brew bundle/casks may be skipped",
                    "".yellow()
                );
                false
            }
        }
    } else {
        false
    };

    // brew bundle interactive
    if has_brew {
        println!("  {} {}", "⟢".magenta().bold(), "brew bundle".bold());
        let bundle_result = Command::new("brew")
            .args(["bundle", "--quiet"])
            .current_dir(dotfiles_tools::home_dir()?)
            .stdin(Stdio::inherit())
            .stdout(Stdio::inherit())
            .stderr(Stdio::inherit())
            .status();
        match bundle_result {
            Ok(status) if status.success() => {
                println!("    {} brew bundle complete", "󰄬".green());
            }
            Ok(_) => {
                println!("    {} brew bundle failed (continuing)", "󰅖".red());
            }
            Err(e) => {
                println!(
                    "    {} brew bundle error: {} (continuing)",
                    "󰅖".red(),
                    e
                );
            }
        }
        println!();
    }

    Ok((auth_status, has_sudo))
}

/// Run post-TUI steps (zsh completions, summary).
pub fn run_post_tui(auth_status: &AuthStatus, any_failed: bool) -> Result<()> {
    println!();
    println!("  {} {}", "⟢".magenta().bold(), "zsh completions".bold());
    println!();
    dotfiles_tools::regen_completions::regenerate_completions()?;

    println!();
    println!("  {} {}", "⟢".magenta().bold(), "status".bold());
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
        println!("    {} all good", "󰄬".green());
    } else {
        println!("    {} remaining manual steps:", "".yellow());
        for step in &manual_steps {
            println!("      {} {}", "·".bright_black(), step);
        }
    }

    println!();
    if any_failed {
        println!(
            "  {} {}",
            "".yellow(),
            "system update complete (with errors)".bold().yellow()
        );
    } else {
        println!(
            "  {} {}",
            "󰄬".green(),
            "system update complete".bold()
        );
    }
    println!();

    Ok(())
}

// --- Private helpers ---

use colored::Colorize;

#[derive(Default)]
pub struct AuthStatus {
    pub gh_ok: bool,
    pub op_ok: bool,
}

fn check_auth_status() -> Result<AuthStatus> {
    println!("  {} {}", "⟢".magenta().bold(), "auth status".bold());

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
            println!("    {} gh", "󰄬".green());
        } else {
            println!("    {} gh not authenticated", "".yellow());
            println!("       run: {}", "gh auth login".cyan());
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
            println!("    {} 1password cli", "󰄬".green());
        } else {
            println!("    {} 1password cli not integrated", "".yellow());
            println!("       1. open 1Password -> Settings -> Developer -> CLI Integration");
            println!("       2. run: {}", "op plugin init".cyan());
        }
    }

    println!();
    Ok(AuthStatus { gh_ok, op_ok })
}

fn install_fonts() -> Result<()> {
    let config = dotfiles_tools::config::DotfilesConfig::load()?;

    if config.fonts.is_empty() {
        return Ok(());
    }

    let fonts_dir = dotfiles_tools::home_dir()?.join("Library/Fonts");
    std::fs::create_dir_all(&fonts_dir)?;

    let missing: Vec<_> = config
        .fonts
        .iter()
        .filter(|f| !fonts_dir.join(&f.marker_file).exists())
        .collect();

    if missing.is_empty() {
        return Ok(());
    }

    let client = reqwest::blocking::Client::builder()
        .timeout(std::time::Duration::from_secs(120))
        .build()?;

    for font in &missing {
        println!("    {} installing {}...", "→".cyan(), font.name);

        match install_font(&client, &font.url, &fonts_dir) {
            Ok(count) => {
                println!(
                    "    {} {} ({} files)",
                    "󰄬".green(),
                    font.name,
                    count
                );
            }
            Err(e) => {
                println!("    {} {} ({})", "".yellow(), font.name, e);
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

        let lower = name.to_lowercase();
        if !lower.ends_with(".otf") && !lower.ends_with(".ttf") {
            continue;
        }

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
