use anyhow::Result;
use indicatif::{MultiProgress, ProgressBar, ProgressStyle};
use std::fs;
use std::process::Command;
use std::thread;
use std::time::Duration;

pub fn regenerate_completions() -> Result<()> {
    let home = std::env::var("HOME")?;
    let completions_dir = format!("{}/.config/zsh/completions", home);
    println!("Generating completions for zsh... to {}", completions_dir);
    let _ = fs::remove_file(format!("{}/.zcompdump", home));

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
        // Internal company tools
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
        "update-ffmpeg",
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
    if which::which("task").is_ok() {
        tasks.push(("task", vec!["--completion", "zsh"]));
    }
    if which::which("just").is_ok() {
        tasks.push(("just", vec!["--completions", "zsh"]));
    }
    if which::which("aws-vault").is_ok() {
        tasks.push(("aws-vault", vec!["--completion-script-zsh"]));
    }
    if which::which("bun").is_ok() {
        tasks.push(("bun", vec!["completions"]));
    }
    if which::which("rg").is_ok() {
        tasks.push(("rg", vec!["--generate", "complete-zsh"]));
    }

    // npm is special - outputs a sourceable script, not a compdef
    // Write to conf.d so it gets sourced automatically
    if which::which("npm").is_ok() {
        if let Ok(output) = Command::new("npm").arg("completion").output() {
            if output.status.success() && !output.stdout.is_empty() {
                let npm_completion_file =
                    format!("{}/.dotfiles/config/zsh/conf.d/npm-completion.zsh", home);
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
                pb.set_style(match Command::new(&cmd).args(args.as_slice()).output() {
                    Ok(output) => {
                        if output.status.success() && !output.stdout.is_empty() {
                            fs::write(format!("{}/_{}", completions_dir, cmd), output.stdout)
                                .unwrap();
                            ProgressStyle::with_template("{spinner:.green} {msg}")
                                .unwrap()
                                .tick_strings(&["✓"])
                        } else {
                            ProgressStyle::with_template("{spinner:.red} {msg}")
                                .unwrap()
                                .tick_strings(&["✗"])
                        }
                    }
                    Err(_) => ProgressStyle::with_template("{spinner:.red} {msg}")
                        .unwrap()
                        .tick_strings(&["✗"]),
                });
                pb.finish();
            })
        })
        .collect();

    for handle in handles {
        let _ = handle.join();
    }

    Ok(())
}
