use crate::system;
use anyhow::Result;
use colored::Colorize;
use rayon::prelude::*;
use std::fs;
use std::process::Command;
use std::sync::Mutex;

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

    // Run all completions in parallel
    let output_mutex = Mutex::new(());
    let completions_dir_clone = completions_dir.clone();

    tasks.par_iter().for_each(|(cmd, args)| {
        if let Ok(output) = Command::new(cmd).args(args.as_slice()).output() {
            if output.status.success() && !output.stdout.is_empty() {
                let _ = fs::write(format!("{}/_{}", completions_dir_clone, cmd), output.stdout);
                let _lock = output_mutex.lock().unwrap();
                println!("  {} {}", "→".cyan(), cmd);
            }
        }
    });

    Ok(())
}
