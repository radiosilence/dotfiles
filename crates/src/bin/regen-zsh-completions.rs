use anyhow::Result;
use colored::Colorize;
use dotfiles_tools::{banner, system};
use rayon::prelude::*;
use std::fs;
use std::process::Command;
use std::sync::Mutex;

fn main() -> Result<()> {
    banner::print_banner(
        "ZSH COMPLETIONS",
        "regenerating system completions",
        "magenta",
    );

    let home = std::env::var("HOME")?;
    let completions_dir = format!("{}/.config/zsh/completions", home);

    // Remove existing completion dump
    banner::status("□", "CLEANING", "zcompdump", "magenta");
    let _ = fs::remove_file(format!("{}/.zcompdump", home));

    // Clean old completion directory
    banner::status("□", "CLEANING", "completions dir", "magenta");
    let _ = fs::remove_dir_all(&completions_dir);
    fs::create_dir_all(&completions_dir)?;

    banner::divider("magenta");
    banner::status("□", "GENERATING", "completions (parallel)", "magenta");

    // Collect all completion tasks
    let mut tasks: Vec<(&str, Vec<&str>)> = vec![];

    // Tools with standard `completion zsh` or `completions zsh` subcommand
    let tools = vec![
        // Our Rust tools
        "kill-port",
        "prune",
        "git-sync",
        "git-squash",
        "git-trigger",
        "to-opus",
        "to-flac",
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
        // External tools
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
                println!("   {} {}", "→".cyan(), cmd);
            }
        }
    });

    if system::which("terraform") {
        println!("   {} terraform (configured via terraform.zsh)", "→".cyan());
    }

    banner::divider("magenta");
    banner::success("COMPLETIONS REGENERATED");
    println!("   {} Restart shell: exec zsh\n", "ℹ".blue());

    Ok(())
}
