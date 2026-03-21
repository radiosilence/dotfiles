use anyhow::Result;
use colored::Colorize;
use indicatif::{MultiProgress, ProgressBar, ProgressStyle};
use std::fs;
use std::path::Path;
use std::process::Command;
use std::thread;
use std::time::Duration;

use crate::config::DotfilesConfig;

/// Regenerate completions silently, returning status lines instead of printing.
pub fn regenerate_completions_quiet() -> Result<Vec<String>> {
    let home = crate::home_dir()?;
    let dotfiles = home.join(".dotfiles");
    let completions_dir = home.join(".config/zsh/completions");
    let mut lines = Vec::new();

    let _ = fs::remove_file(home.join(".zcompdump"));

    if completions_dir.is_symlink() && !completions_dir.exists() {
        let _ = fs::remove_file(&completions_dir);
    }
    if completions_dir.exists() {
        if let Ok(entries) = fs::read_dir(&completions_dir) {
            for entry in entries.flatten() {
                let _ = fs::remove_file(entry.path());
            }
        }
    } else if let Err(e) = fs::create_dir_all(&completions_dir) {
        lines.push(format!(
            "error: cannot create {}: {}",
            completions_dir.display(),
            e
        ));
        return Ok(lines);
    }

    let config = match DotfilesConfig::load() {
        Ok(c) => c,
        Err(e) => {
            lines.push(format!("error: {e}"));
            return Ok(lines);
        }
    };

    if config.completions.tools.is_empty() {
        lines.push("no tools configured".to_string());
        return Ok(lines);
    }

    let mut handles = Vec::new();

    for tool in config.completions.tools {
        if which::which(&tool.name).is_err() {
            continue;
        }

        let tool_type = tool.tool_type.as_deref().unwrap_or("default");

        match tool_type {
            "prebuilt" => {
                let Some(source) = tool.source.as_ref() else {
                    lines.push(format!("{}: prebuilt missing source", tool.name));
                    continue;
                };
                let Ok(bin_path) = which::which(&tool.name) else {
                    continue;
                };
                let src = bin_path.parent().unwrap_or(bin_path.as_path()).join(source);
                if src.exists() {
                    match fs::copy(&src, completions_dir.join(format!("_{}", tool.name))) {
                        Ok(_) => lines.push(format!("{} (pre-built)", tool.name)),
                        Err(e) => lines.push(format!("{}: {}", tool.name, e)),
                    }
                }
            }
            "sourced" => {
                let Some(cmd) = tool.command.as_ref() else {
                    lines.push(format!("{}: sourced missing command", tool.name));
                    continue;
                };
                let Some(output_rel) = tool.output.as_ref() else {
                    lines.push(format!("{}: sourced missing output", tool.name));
                    continue;
                };
                let output_path = dotfiles.join(output_rel);
                if let Some(parent) = output_path.parent() {
                    let _ = fs::create_dir_all(parent);
                }
                match Command::new(&cmd[0]).args(&cmd[1..]).output() {
                    Ok(out) if out.status.success() && !out.stdout.is_empty() => {
                        match fs::write(&output_path, &out.stdout) {
                            Ok(()) => lines.push(format!("{} (sourced)", tool.name)),
                            Err(e) => lines.push(format!("{}: {}", tool.name, e)),
                        }
                    }
                    Ok(out) => {
                        let stderr = String::from_utf8_lossy(&out.stderr);
                        let err = stderr
                            .lines()
                            .next()
                            .filter(|s| !s.is_empty())
                            .unwrap_or("empty output");
                        lines.push(format!("{}: {}", tool.name, err));
                    }
                    Err(e) => lines.push(format!("{}: {}", tool.name, e)),
                }
            }
            _ => {
                let cmd: Vec<String> = tool
                    .command
                    .unwrap_or_else(|| vec![tool.name.clone(), "completion".into(), "zsh".into()]);
                let name = tool.name.clone();
                let dir = completions_dir.clone();
                handles.push(thread::spawn(move || -> String {
                    match Command::new(&cmd[0]).args(&cmd[1..]).output() {
                        Ok(output) if output.status.success() && !output.stdout.is_empty() => {
                            match fs::write(dir.join(format!("_{name}")), output.stdout) {
                                Ok(()) => name,
                                Err(e) => format!("{name}: {e}"),
                            }
                        }
                        Ok(output) => {
                            let stderr = String::from_utf8_lossy(&output.stderr);
                            let err = stderr.lines().next().unwrap_or("").to_string();
                            if err.is_empty() {
                                format!("{name}: empty output")
                            } else {
                                format!("{name}: {err}")
                            }
                        }
                        Err(e) => format!("{name}: {e}"),
                    }
                }));
            }
        }
    }

    for handle in handles {
        if let Ok(line) = handle.join() {
            lines.push(line);
        }
    }

    Ok(lines)
}

pub fn regenerate_completions() -> Result<()> {
    let home = crate::home_dir()?;
    let dotfiles = home.join(".dotfiles");
    let completions_dir = home.join(".config/zsh/completions");

    println!(
        "  {} generating completions to {}",
        "→".cyan(),
        completions_dir.display()
    );

    let _ = fs::remove_file(home.join(".zcompdump"));

    // Ensure completions dir exists (create parents if needed, e.g. on fresh system)
    if completions_dir.is_symlink() && !completions_dir.exists() {
        // Dangling symlink — remove it so create_dir_all works
        let _ = fs::remove_file(&completions_dir);
    }
    if completions_dir.exists() {
        // Clear existing completions but keep the directory
        if let Ok(entries) = fs::read_dir(&completions_dir) {
            for entry in entries.flatten() {
                let _ = fs::remove_file(entry.path());
            }
        }
    } else if let Err(e) = fs::create_dir_all(&completions_dir) {
        println!(
            "  {} cannot create {}: {}",
            "󰅖".red(),
            completions_dir.display(),
            e
        );
        return Ok(());
    }

    let config = match DotfilesConfig::load() {
        Ok(c) => c,
        Err(e) => {
            println!("  {} failed to load dotfiles.toml: {e}", "󰅖".red());
            return Ok(());
        }
    };

    if config.completions.tools.is_empty() {
        println!("  {} no tools configured in dotfiles.toml", "".yellow());
        return Ok(());
    }

    let mp = MultiProgress::new();
    let mut handles = Vec::new();

    for tool in config.completions.tools {
        if which::which(&tool.name).is_err() {
            continue;
        }

        let tool_type = tool.tool_type.as_deref().unwrap_or("default");

        match tool_type {
            "prebuilt" => {
                let Some(source) = tool.source.as_ref() else {
                    println!(
                        "  {} {}: prebuilt missing `source` field",
                        "󰅖".red(),
                        tool.name
                    );
                    continue;
                };
                let Ok(bin_path) = which::which(&tool.name) else {
                    continue;
                };
                let src = bin_path.parent().unwrap_or(bin_path.as_path()).join(source);
                if src.exists() {
                    match fs::copy(&src, completions_dir.join(format!("_{}", tool.name))) {
                        Ok(_) => println!("  {} {} (pre-built)", "󰄬".green(), tool.name),
                        Err(e) => println!("  {} {}: copy failed: {}", "󰅖".red(), tool.name, e),
                    }
                }
            }
            "sourced" => {
                let Some(cmd) = tool.command.as_ref() else {
                    println!(
                        "  {} {}: sourced missing `command` field",
                        "󰅖".red(),
                        tool.name
                    );
                    continue;
                };
                let Some(output_rel) = tool.output.as_ref() else {
                    println!(
                        "  {} {}: sourced missing `output` field",
                        "󰅖".red(),
                        tool.name
                    );
                    continue;
                };
                let output_path = dotfiles.join(output_rel);
                let name = tool.name.clone();

                // Ensure parent dir exists
                if let Some(parent) = output_path.parent() {
                    let _ = fs::create_dir_all(parent);
                }

                match Command::new(&cmd[0]).args(&cmd[1..]).output() {
                    Ok(out) if out.status.success() && !out.stdout.is_empty() => {
                        match fs::write(&output_path, &out.stdout) {
                            Ok(()) => println!("  {} {} (sourced)", "󰄬".green(), name),
                            Err(e) => println!("  {} {}: write failed: {}", "󰅖".red(), name, e),
                        }
                    }
                    Ok(out) => {
                        let stderr = String::from_utf8_lossy(&out.stderr);
                        let err = stderr
                            .lines()
                            .next()
                            .filter(|s| !s.is_empty())
                            .unwrap_or("empty output");
                        println!("  {} {}: {}", "󰅖".red(), name, err);
                    }
                    Err(e) => println!("  {} {}: {}", "󰅖".red(), name, e),
                }
            }
            _ => {
                let cmd: Vec<String> = tool
                    .command
                    .unwrap_or_else(|| vec![tool.name.clone(), "completion".into(), "zsh".into()]);
                let name = tool.name.clone();
                let dir = completions_dir.clone();
                let pb = mp.add(ProgressBar::new_spinner());
                pb.set_style(ProgressStyle::default_spinner());
                pb.enable_steady_tick(Duration::from_millis(80));
                pb.set_message(name.clone());

                handles.push(thread::spawn(move || {
                    run_completion(&cmd, &name, &dir, &pb);
                }));
            }
        }
    }

    for handle in handles {
        let _ = handle.join();
    }

    Ok(())
}

fn run_completion(cmd: &[String], name: &str, completions_dir: &Path, pb: &ProgressBar) {
    let (success, msg) = match Command::new(&cmd[0]).args(&cmd[1..]).output() {
        Ok(output) => {
            if output.status.success() && !output.stdout.is_empty() {
                match fs::write(completions_dir.join(format!("_{name}")), output.stdout) {
                    Ok(()) => (true, format!("󰄬 {name}")),
                    Err(e) => (false, format!("󰅖 {name}: write failed: {e}")),
                }
            } else {
                let stderr = String::from_utf8_lossy(&output.stderr);
                let err = if !stderr.is_empty() {
                    stderr.lines().next().unwrap_or("").to_string()
                } else if output.stdout.is_empty() {
                    "empty output".to_string()
                } else {
                    format!("exit code {}", output.status.code().unwrap_or(-1))
                };
                (false, format!("󰅖 {name}: {err}"))
            }
        }
        Err(e) => (false, format!("󰅖 {name}: {e}")),
    };

    let template = if success {
        "{msg:.green}"
    } else {
        "{msg:.red}"
    };
    if let Ok(style) = ProgressStyle::with_template(template) {
        pb.set_style(style);
    }
    pb.finish_with_message(msg);
}
