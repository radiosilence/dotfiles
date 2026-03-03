use anyhow::Result;
use indicatif::{MultiProgress, ProgressBar, ProgressStyle};
use std::fs;
use std::path::Path;
use std::process::Command;
use std::thread;
use std::time::Duration;

use crate::config::DotfilesConfig;

pub fn regenerate_completions() -> Result<()> {
    let home = crate::home_dir()?;
    let dotfiles = home.join(".dotfiles");
    let completions_dir = home.join(".config/zsh/completions");

    println!(
        "Generating completions for zsh... to {}",
        completions_dir.display()
    );

    let _ = fs::remove_file(home.join(".zcompdump"));
    let _ = fs::remove_dir_all(&completions_dir);
    fs::create_dir_all(&completions_dir)?;

    let config = match DotfilesConfig::load() {
        Ok(c) => c,
        Err(_) => {
            println!("No dotfiles.toml found, skipping");
            return Ok(());
        }
    };

    if config.completions.tools.is_empty() {
        println!("No tools configured in dotfiles.toml");
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
                let source = tool
                    .source
                    .as_ref()
                    .expect("prebuilt tool missing `source`");
                let bin_path = which::which(&tool.name).unwrap();
                let src = bin_path
                    .parent()
                    .unwrap_or(bin_path.as_path())
                    .join(source);
                if src.exists() {
                    if let Err(e) = fs::copy(&src, completions_dir.join(format!("_{}", tool.name)))
                    {
                        println!("✗ {}: copy failed: {}", tool.name, e);
                    } else {
                        println!("✓ {} (pre-built)", tool.name);
                    }
                }
            }
            "sourced" => {
                let cmd = tool
                    .command
                    .as_ref()
                    .expect("sourced tool missing `command`");
                let output_rel = tool
                    .output
                    .as_ref()
                    .expect("sourced tool missing `output`");
                let output_path = dotfiles.join(output_rel);
                let name = tool.name.clone();

                match Command::new(&cmd[0]).args(&cmd[1..]).output() {
                    Ok(out) if out.status.success() && !out.stdout.is_empty() => {
                        fs::write(&output_path, out.stdout)?;
                        println!("✓ {} (sourced)", name);
                    }
                    Ok(out) => {
                        let stderr = String::from_utf8_lossy(&out.stderr);
                        let err = stderr
                            .lines()
                            .next()
                            .filter(|s| !s.is_empty())
                            .unwrap_or("empty output");
                        println!("✗ {}: {}", name, err);
                    }
                    Err(e) => println!("✗ {}: {}", name, e),
                }
            }
            _ => {
                // default: run command, write to _<name>
                let cmd: Vec<String> = tool.command.unwrap_or_else(|| {
                    vec![
                        tool.name.clone(),
                        "completion".into(),
                        "zsh".into(),
                    ]
                });
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
                    Ok(()) => (true, format!("✓ {name}")),
                    Err(e) => (false, format!("✗ {name}: write failed: {e}")),
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
                (false, format!("✗ {name}: {err}"))
            }
        }
        Err(e) => (false, format!("✗ {name}: {e}")),
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
