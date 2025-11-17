use anyhow::Result;
use colored::Colorize;
use std::fs;
use std::process::Command;

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
    banner::status("□", "GENERATING", "rust tools", "magenta");

    // Our Rust tools
    let rust_tools = vec![
        "kill-port",
        "prune",
        "git-sync",
        "git-squash",
        "git-trigger",
        "git-update",
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
    ];

    for cmd in rust_tools {
        if which(cmd) {
            println!("   {} {}", "→".cyan(), cmd);
            let _ = Command::new(cmd)
                .arg("--completions")
                .arg("zsh")
                .output()
                .and_then(|output| {
                    if output.status.success() {
                        fs::write(format!("{}/_{}", completions_dir, cmd), output.stdout)?;
                    }
                    Ok(())
                });
        }
    }

    banner::divider("magenta");
    banner::status("□", "GENERATING", "system tools", "magenta");

    // Standard completion commands
    let standard_cmds = vec![
        "docker", "kubectl", "helm", "houston", "orbctl", "fcloud", "k9s", "argocd", "pulumi",
        "tilt", "turso", "lefthook", "mas", "yq", "rclone", "op", "nano-web",
    ];

    for cmd in standard_cmds {
        if which(cmd) {
            println!("   {} {}", "→".cyan(), cmd);
            let _ = Command::new(cmd)
                .args(["completion", "zsh"])
                .output()
                .and_then(|output| {
                    if output.status.success() {
                        fs::write(format!("{}/_{}", completions_dir, cmd), output.stdout)?;
                    }
                    Ok(())
                });
        }
    }

    // Special cases
    if which("gh") {
        println!("   {} gh", "→".cyan());
        let _ = Command::new("gh")
            .args(["completion", "-s", "zsh"])
            .output()
            .and_then(|output| {
                if output.status.success() {
                    fs::write(format!("{}/_gh", completions_dir), output.stdout)?;
                }
                Ok(())
            });
    }

    if which("task") {
        println!("   {} task", "→".cyan());
        let _ = Command::new("task")
            .arg("--completion")
            .arg("zsh")
            .output()
            .and_then(|output| {
                if output.status.success() {
                    fs::write(format!("{}/_task", completions_dir), output.stdout)?;
                }
                Ok(())
            });
    }

    if which("aws-vault") {
        println!("   {} aws-vault", "→".cyan());
        let _ = Command::new("aws-vault")
            .arg("--completion-script-zsh")
            .output()
            .and_then(|output| {
                if output.status.success() {
                    fs::write(format!("{}/_aws-vault", completions_dir), output.stdout)?;
                }
                Ok(())
            });
    }

    if which("terraform") {
        println!("   {} terraform (configured via terraform.zsh)", "→".cyan());
    }

    banner::divider("magenta");
    banner::success("COMPLETIONS REGENERATED");
    println!("   {} Restart shell: exec zsh\n", "ℹ".blue());

    Ok(())
}

fn which(cmd: &str) -> bool {
    Command::new("which")
        .arg(cmd)
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

mod banner {
    use colored::Colorize;

    pub fn print_banner(title: &str, subtitle: &str, color: &str) {
        let color_fn = match color {
            "magenta" => |s: &str| s.magenta().to_string(),
            _ => |s: &str| s.to_string(),
        };

        println!(
            "\n{}",
            color_fn("   ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄")
        );
        println!(
            "   {} {}\n",
            color_fn(&format!("▸ {}", title)).bold(),
            subtitle.dimmed()
        );
    }

    pub fn status(icon: &str, label: &str, value: &str, color: &str) {
        let color_fn = match color {
            "magenta" => |s: &str| s.magenta().to_string(),
            _ => |s: &str| s.to_string(),
        };
        println!("   {} {} {}", color_fn(icon), label.bold(), value);
    }

    pub fn success(msg: &str) {
        println!("   {} {}\n", "✓".green().bold(), msg.green().bold());
    }

    pub fn divider(color: &str) {
        let color_fn = match color {
            "magenta" => |s: &str| s.magenta().to_string(),
            _ => |s: &str| s.to_string(),
        };
        println!(
            "{}",
            color_fn("   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        );
    }
}
