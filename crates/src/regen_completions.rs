use anyhow::Result;
use indicatif::{MultiProgress, ProgressBar, ProgressStyle};
use std::fs;
use std::process::Command;
use std::thread;
use std::time::Duration;

pub fn regenerate_completions() -> Result<()> {
    let home = crate::home_dir()?;
    let completions_dir = home.join(".config/zsh/completions");
    println!(
        "Generating completions for zsh... to {}",
        completions_dir.display()
    );
    let _ = fs::remove_file(home.join(".zcompdump"));

    let _ = fs::remove_dir_all(&completions_dir);
    fs::create_dir_all(&completions_dir)?;
    let mut tasks: Vec<(&str, Vec<&str>)> = vec![];

    let tools = [
        // External tools (installed via brew/mise)
        "argocd",
        "docker",
        "helm",
        "k9s",
        "kubectl",
        "lefthook",
        "nano-web",
        "op",
        "orbctl",
        "pulumi",
        "tilt",
        "turso",
        "yq",
        "fcloud",
        "houston",
        // Our binaries
        "clean-dls",
        "clean-exif",
        "echo-to-file",
        "embed-art",
        "extract-exif-from-flac",
        "gen-diff",
        "git-squash",
        "git-sync",
        "git-trigger",
        "imp",
        "install-font-macos",
        "install-terminfo",
        "kill-port",
        "parallel-dl-extract",
        "prune",
        "prune-gen",
        "to-audio",
        "unfuck-xcode",
        "upd",
        "url2base64",
        "vimv",
    ];

    for cmd in tools {
        if which::which(cmd).is_ok() {
            tasks.push((cmd, vec!["completion", "zsh"]));
        }
    }

    // Special cases
    if which::which("gh").is_ok() {
        tasks.push(("gh", vec!["completion", "-s", "zsh"]));
    }
    if which::which("idiotify").is_ok() {
        tasks.push(("idiotify", vec!["completions", "zsh"]));
    }
    if which::which("fastmail-cli").is_ok() {
        tasks.push(("fastmail-cli", vec!["completions", "zsh"]));
    }
    if which::which("codeowners-cli").is_ok() {
        tasks.push(("codeowners-cli", vec!["completions", "zsh"]));
    }
    if which::which("task").is_ok() {
        tasks.push(("task", vec!["--completion", "zsh"]));
    }
    if which::which("just").is_ok() {
        tasks.push(("just", vec!["--completions", "zsh"]));
    }
    if which::which("aws-vault").is_ok() {
        tasks.push(("aws-vault", vec!["--completion-script-zsh"]));
    }

    if which::which("rg").is_ok() {
        tasks.push(("rg", vec!["--generate", "complete-zsh"]));
    }
    // lsd ships pre-built completions (no runtime generation since 1.x)
    if let Ok(lsd_path) = which::which("lsd") {
        let lsd_completion = lsd_path
            .parent()
            .unwrap_or(lsd_path.as_path())
            .join("autocomplete/_lsd");
        if lsd_completion.exists() {
            if let Err(e) = fs::copy(&lsd_completion, completions_dir.join("_lsd")) {
                println!("✗ lsd: copy failed: {}", e);
            } else {
                println!("✓ lsd (pre-built)");
            }
        }
    }

    // npm is special - outputs a sourceable script, not a compdef
    // Write to conf.d so it gets sourced automatically
    if which::which("npm").is_ok() {
        if let Ok(output) = Command::new("npm").arg("completion").output() {
            if output.status.success() && !output.stdout.is_empty() {
                let npm_completion_file =
                    home.join(".dotfiles/config/zsh/conf.d/npm-completion.zsh");
                fs::write(&npm_completion_file, output.stdout)?;
                println!("✓ npm (sourced completion)");
            }
        }
    }

    let mp = MultiProgress::new();

    let completions_dir_clone = completions_dir.clone();

    let handles: Vec<_> = tasks
        .iter()
        .map(|(cmd, args)| {
            let pb = mp.add(ProgressBar::new_spinner());
            pb.set_style(ProgressStyle::default_spinner());
            pb.enable_steady_tick(Duration::from_millis(80));
            pb.set_message(*cmd);
            let cmd = cmd.to_string();
            let args = args.clone();
            let completions_dir = completions_dir_clone.clone();
            thread::spawn(move || {
                let (success, msg) = match Command::new(&cmd).args(args.as_slice()).output() {
                    Ok(output) => {
                        if output.status.success() && !output.stdout.is_empty() {
                            match fs::write(completions_dir.join(format!("_{cmd}")), output.stdout)
                            {
                                Ok(()) => (true, format!("✓ {}", cmd)),
                                Err(e) => (false, format!("✗ {}: write failed: {}", cmd, e)),
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
                            (false, format!("✗ {}: {}", cmd, err))
                        }
                    }
                    Err(e) => (false, format!("✗ {}: {}", cmd, e)),
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
            })
        })
        .collect();

    for handle in handles {
        let _ = handle.join();
    }

    Ok(())
}
