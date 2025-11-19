use crate::system;
use anyhow::Result;
use indicatif::{MultiProgress, ProgressBar, ProgressStyle};
use std::fs;
use std::process::Command;
use std::thread;
use std::time::Duration;

pub fn regenerate_completions() -> Result<()> {
    let home = std::env::var("HOME")?;
    let completions_dir = format!("{}/.config/zsh/completions", home);

    let _ = fs::remove_file(format!("{}/.zcompdump", home));

    let _ = fs::remove_dir_all(&completions_dir);
    fs::create_dir_all(&completions_dir)?;
    let mut tasks: Vec<(&str, Vec<&str>)> = vec![];

    let tools = vec![
        "kill-port",
        "prune",
        "git-sync",
        "git-squash",
        "git-trigger",
        "to-audio",
        "clean-exif",
        "clean-dls",
        "url2base64",
        "imp",
        "install-font-macos",
        "unfuck-xcode",
        "vimv",
        "embed-art",
        "extract-exif-from-flac",
        "gen-diff",
        "install-terminfo",
        "prune-gen",
        "pull-music",
        "push-music",
        "echo-to-file",
        "parallel-dl-extract",
        "upd",
        "install-dotfiles",
        "docker",
        "kubectl",
        "helm",
        "houston",
        "orbctl",
        "fcloud",
        "k9s",
        "argocd",
        "pulumi",
        "tilt",
        "turso",
        "lefthook",
        "mas",
        "yq",
        "rclone",
        "op",
        "nano-web",
    ];

    for cmd in tools {
        if system::which(cmd) {
            tasks.push((cmd, vec!["completion", "zsh"]));
        }
    }

    // Special cases
    if system::which("gh") {
        tasks.push(("gh", vec!["completion", "-s", "zsh"]));
    }
    if system::which("task") {
        tasks.push(("task", vec!["--completion", "zsh"]));
    }
    if system::which("just") {
        tasks.push(("just", vec!["--completions", "zsh"]));
    }
    if system::which("aws-vault") {
        tasks.push(("aws-vault", vec!["--completion-script-zsh"]));
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
                        }
                        ProgressStyle::with_template("{spinner:.green} {msg}")
                            .unwrap()
                            .tick_strings(&["✓"])
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
