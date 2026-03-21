use anyhow::Result;
use std::fs;
use std::process::Command;
use std::thread;

use crate::config::DotfilesConfig;

#[derive(Debug)]
pub struct CompletionResult {
    pub name: String,
    pub ok: bool,
    pub detail: String,
}

/// Regenerate all zsh completions. Returns results per tool — no printing, no spinners.
pub fn regenerate_completions() -> Result<Vec<CompletionResult>> {
    let home = crate::home_dir()?;
    let dotfiles = home.join(".dotfiles");
    let completions_dir = home.join(".config/zsh/completions");
    let mut results = Vec::new();

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
    } else {
        fs::create_dir_all(&completions_dir)?;
    }

    let config = DotfilesConfig::load()?;

    if config.completions.tools.is_empty() {
        return Ok(results);
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
                    results.push(CompletionResult {
                        name: tool.name,
                        ok: false,
                        detail: "missing source field".into(),
                    });
                    continue;
                };
                let Ok(bin_path) = which::which(&tool.name) else {
                    continue;
                };
                let src = bin_path.parent().unwrap_or(bin_path.as_path()).join(source);
                if src.exists() {
                    let dest = completions_dir.join(format!("_{}", tool.name));
                    match fs::copy(&src, &dest) {
                        Ok(_) => results.push(CompletionResult {
                            name: tool.name,
                            ok: true,
                            detail: "pre-built".into(),
                        }),
                        Err(e) => results.push(CompletionResult {
                            name: tool.name,
                            ok: false,
                            detail: format!("copy failed: {e}"),
                        }),
                    }
                }
            }
            "sourced" => {
                let Some(cmd) = tool.command.as_ref() else {
                    results.push(CompletionResult {
                        name: tool.name,
                        ok: false,
                        detail: "missing command field".into(),
                    });
                    continue;
                };
                let Some(output_rel) = tool.output.as_ref() else {
                    results.push(CompletionResult {
                        name: tool.name,
                        ok: false,
                        detail: "missing output field".into(),
                    });
                    continue;
                };
                let output_path = dotfiles.join(output_rel);
                if let Some(parent) = output_path.parent() {
                    let _ = fs::create_dir_all(parent);
                }
                match Command::new(&cmd[0]).args(&cmd[1..]).output() {
                    Ok(out) if out.status.success() && !out.stdout.is_empty() => {
                        match fs::write(&output_path, &out.stdout) {
                            Ok(()) => results.push(CompletionResult {
                                name: tool.name,
                                ok: true,
                                detail: "sourced".into(),
                            }),
                            Err(e) => results.push(CompletionResult {
                                name: tool.name,
                                ok: false,
                                detail: e.to_string(),
                            }),
                        }
                    }
                    Ok(out) => {
                        let stderr = String::from_utf8_lossy(&out.stderr);
                        let err = stderr
                            .lines()
                            .next()
                            .filter(|s| !s.is_empty())
                            .unwrap_or("empty output");
                        results.push(CompletionResult {
                            name: tool.name,
                            ok: false,
                            detail: err.to_string(),
                        });
                    }
                    Err(e) => results.push(CompletionResult {
                        name: tool.name,
                        ok: false,
                        detail: e.to_string(),
                    }),
                }
            }
            _ => {
                let cmd: Vec<String> = tool
                    .command
                    .unwrap_or_else(|| vec![tool.name.clone(), "completion".into(), "zsh".into()]);
                let name = tool.name.clone();
                let dir = completions_dir.clone();
                handles.push(thread::spawn(move || -> CompletionResult {
                    match Command::new(&cmd[0]).args(&cmd[1..]).output() {
                        Ok(output) if output.status.success() && !output.stdout.is_empty() => {
                            match fs::write(dir.join(format!("_{name}")), output.stdout) {
                                Ok(()) => CompletionResult {
                                    name,
                                    ok: true,
                                    detail: String::new(),
                                },
                                Err(e) => CompletionResult {
                                    name,
                                    ok: false,
                                    detail: e.to_string(),
                                },
                            }
                        }
                        Ok(output) => {
                            let stderr = String::from_utf8_lossy(&output.stderr);
                            let err = stderr.lines().next().unwrap_or("").to_string();
                            CompletionResult {
                                name,
                                ok: false,
                                detail: if err.is_empty() {
                                    "empty output".into()
                                } else {
                                    err
                                },
                            }
                        }
                        Err(e) => CompletionResult {
                            name,
                            ok: false,
                            detail: e.to_string(),
                        },
                    }
                }));
            }
        }
    }

    for handle in handles {
        if let Ok(result) = handle.join() {
            results.push(result);
        }
    }

    Ok(results)
}
