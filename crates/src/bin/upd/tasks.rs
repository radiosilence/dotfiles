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

    let stdout_state = state.clone();
    let stdout_idx = task_idx;
    let stdout_name = name.to_string();
    let stdout_handle = child.stdout.take().map(|stdout| {
        thread::spawn(move || {
            for line in BufReader::new(stdout).lines().map_while(Result::ok) {
                let mut s = stdout_state.lock().unwrap();
                s.push_output(stdout_idx, format!("{stdout_name}: {line}"));
            }
        })
    });

    let stderr_state = state.clone();
    let stderr_idx = task_idx;
    let stderr_name = name.to_string();
    let stderr_handle = child.stderr.take().map(|stderr| {
        thread::spawn(move || {
            for line in BufReader::new(stderr).lines().map_while(Result::ok) {
                let mut s = stderr_state.lock().unwrap();
                s.push_output(stderr_idx, format!("{stderr_name}: {line}"));
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

/// Helper to wrap a task body with set_running/set_done/set_failed.
fn spawn_task<F>(state: SharedState, task_idx: usize, initial_step: &str, body: F) -> JoinHandle<()>
where
    F: FnOnce(&SharedState, usize) -> Result<()> + Send + 'static,
{
    let step = initial_step.to_string();
    thread::spawn(move || {
        {
            let mut s = state.lock().unwrap();
            s.set_running(task_idx, &step);
        }

        let result = body(&state, task_idx);

        let mut s = state.lock().unwrap();
        match result {
            Ok(()) => s.set_done(task_idx),
            Err(e) => s.set_failed(task_idx, e.to_string()),
        }
    })
}

// --- Task spawners ---

pub fn spawn_link(state: SharedState, idx: usize) -> JoinHandle<()> {
    spawn_task(state, idx, "linking", |state, idx| {
        let dotfiles_dir = dotfiles_tools::home_dir()?.join(".dotfiles");
        run_cmd(
            "link",
            state,
            idx,
            Command::new("mise")
                .args(["run", "link"])
                .current_dir(&dotfiles_dir),
        )?;
        Ok(())
    })
}

pub fn spawn_auth(state: SharedState, idx: usize) -> JoinHandle<()> {
    spawn_task(state, idx, "checking", |state, idx| {
        let gh_ok = which("gh").is_ok()
            && Command::new("gh")
                .args(["auth", "status"])
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .status()
                .map(|s| s.success())
                .unwrap_or(false);

        let op_ok = which("op").is_ok()
            && Command::new("op")
                .args(["account", "list"])
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .status()
                .map(|s| s.success())
                .unwrap_or(false);

        {
            let mut s = state.lock().unwrap();
            if which("gh").is_ok() {
                if gh_ok {
                    s.push_output(idx, "gh: authenticated".to_string());
                } else {
                    s.push_output(idx, "gh: not authenticated (run gh auth login)".to_string());
                }
            }
            if which("op").is_ok() {
                if op_ok {
                    s.push_output(idx, "op: integrated".to_string());
                } else {
                    s.push_output(
                        idx,
                        "op: not integrated (check 1Password CLI settings)".to_string(),
                    );
                }
            }
            s.auth_gh_ok = gh_ok;
            s.auth_op_ok = op_ok;
        }

        Ok(())
    })
}

pub fn spawn_fonts(state: SharedState, idx: usize) -> JoinHandle<()> {
    spawn_task(state, idx, "checking", |state, idx| {
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
            state
                .lock()
                .unwrap()
                .push_output(idx, "all fonts installed".to_string());
            return Ok(());
        }

        let client = reqwest::blocking::Client::builder()
            .timeout(std::time::Duration::from_secs(120))
            .build()?;

        for font in &missing {
            {
                let mut s = state.lock().unwrap();
                s.set_step(idx, &format!("installing {}", font.name));
            }

            let response = client.get(&font.url).send()?;
            if !response.status().is_success() {
                state
                    .lock()
                    .unwrap()
                    .push_output(idx, format!("{}: HTTP {}", font.name, response.status()));
                continue;
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

            state
                .lock()
                .unwrap()
                .push_output(idx, format!("{}: {} files installed", font.name, count));
        }
        Ok(())
    })
}

pub fn spawn_brew_bundle(state: SharedState, idx: usize) -> JoinHandle<()> {
    spawn_task(state, idx, "bundling", |state, idx| {
        let home = dotfiles_tools::home_dir()?;
        run_cmd(
            "bundle",
            state,
            idx,
            Command::new("brew")
                .args(["bundle", "--quiet"])
                .current_dir(&home),
        )?;
        Ok(())
    })
}

pub fn spawn_brew(state: SharedState, idx: usize) -> JoinHandle<()> {
    spawn_task(state, idx, "brew:update", |state, idx| {
        run_cmd(
            "brew:update",
            state,
            idx,
            Command::new("brew").args(["update", "--quiet"]),
        )?;
        run_cmd(
            "brew:upgrade",
            state,
            idx,
            Command::new("brew").args(["upgrade", "--greedy", "--quiet"]),
        )?;
        run_cmd(
            "brew:cleanup",
            state,
            idx,
            Command::new("brew").args(["cleanup", "--quiet"]),
        )?;
        Ok(())
    })
}

pub fn spawn_apt(state: SharedState, idx: usize) -> JoinHandle<()> {
    spawn_task(state, idx, "apt:update", |state, idx| {
        run_cmd(
            "apt:update",
            state,
            idx,
            Command::new("sudo").args(["apt-get", "update"]),
        )?;
        run_cmd(
            "apt:upgrade",
            state,
            idx,
            Command::new("sudo").args(["apt-get", "upgrade", "-y"]),
        )?;
        run_cmd(
            "apt:autoremove",
            state,
            idx,
            Command::new("sudo").args(["apt-get", "autoremove", "-y"]),
        )?;
        Ok(())
    })
}

pub fn spawn_dnf(state: SharedState, idx: usize) -> JoinHandle<()> {
    spawn_task(state, idx, "dnf:update", |state, idx| {
        run_cmd(
            "dnf:update",
            state,
            idx,
            Command::new("sudo").args(["dnf", "update", "-y"]),
        )?;
        Ok(())
    })
}

pub fn spawn_mise(state: SharedState, idx: usize) -> JoinHandle<()> {
    spawn_task(state, idx, "mise:up", |state, idx| {
        let home = dotfiles_tools::home_dir()?;
        run_cmd(
            "mise:up",
            state,
            idx,
            Command::new("mise").arg("up").current_dir(&home),
        )?;
        run_cmd(
            "mise:reshim",
            state,
            idx,
            Command::new("mise").arg("reshim").current_dir(&home),
        )?;
        Ok(())
    })
}

pub fn spawn_claude(state: SharedState, idx: usize) -> JoinHandle<()> {
    spawn_task(state, idx, "claude:update", |state, idx| {
        run_cmd(
            "claude:update",
            state,
            idx,
            Command::new("claude").arg("--update"),
        )?;
        Ok(())
    })
}

pub fn spawn_tmux_plugins(state: SharedState, idx: usize) -> JoinHandle<()> {
    spawn_task(state, idx, "tmux:plugins", |state, idx| {
        let plugins: Vec<(&str, &str)> = vec![
            (
                "tmux-resurrect",
                "https://github.com/tmux-plugins/tmux-resurrect.git",
            ),
            ("tmux-fzf-url", "https://github.com/wfxr/tmux-fzf-url.git"),
        ];

        let plugins_dir = dotfiles_tools::home_dir()?.join(".tmux/plugins");
        std::fs::create_dir_all(&plugins_dir)?;

        for (name, url) in &plugins {
            let dest = plugins_dir.join(name);
            if dest.exists() {
                run_cmd(
                    &format!("tmux:{name}:pull"),
                    state,
                    idx,
                    Command::new("git")
                        .args(["pull", "--quiet"])
                        .current_dir(&dest),
                )?;
            } else {
                run_cmd(
                    &format!("tmux:{name}:clone"),
                    state,
                    idx,
                    Command::new("git").args(["clone", "--quiet", url, &dest.to_string_lossy()]),
                )?;
            }
        }
        Ok(())
    })
}

pub fn spawn_zsh_completions(state: SharedState, idx: usize) -> JoinHandle<()> {
    spawn_task(state, idx, "generating", |state, idx| {
        let results = dotfiles_tools::regen_completions::regenerate_completions()
            .context("failed to regenerate zsh completions")?;

        let mut s = state.lock().unwrap();
        for r in &results {
            if r.ok {
                let suffix = if r.detail.is_empty() {
                    String::new()
                } else {
                    format!(" ({})", r.detail)
                };
                s.push_output(idx, format!("{}{}", r.name, suffix));
            } else {
                s.push_output(idx, format!("{}: {}", r.name, r.detail));
            }
        }
        Ok(())
    })
}
