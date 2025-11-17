use anyhow::Result;
use clap::{Parser, Subcommand};
use dotfiles_tools::completions;
use std::process::Command;

#[derive(Parser)]
#[command(name = "pull-music")]
#[command(about = "Sync music from remote", long_about = None)]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    /// Generate shell completions
    Completions {
        #[arg(value_enum)]
        shell: completions::CompletionShell,
    },
}

fn main() -> Result<()> {
    let args = Args::parse();

    if let Some(Commands::Completions { shell }) = args.command {
        completions::generate_completions::<Args>(shell);
        return Ok(());
    }

    banner::print_banner("PULL MUSIC", "sync from remote to local", "cyan");

    let src = if std::path::Path::new("/Volumes/music").exists() {
        "/Volumes/music"
    } else {
        "oldboy:/mnt/kontent/music"
    };

    let dst = "/Volumes/Turtlehead/music";

    banner::status("□", "SOURCE", src, "cyan");
    banner::status("□", "DEST", dst, "cyan");
    banner::divider("cyan");

    let status = Command::new("rclone")
        .args([
            "sync",
            "--progress",
            "--size-only",
            "--checkers=16",
            "--delete-during",
            "--transfers=16",
            "--exclude=**/.DS_Store",
            "--exclude=.DS_Store",
            "-v",
            src,
            dst,
        ])
        .status()?;

    if !status.success() {
        anyhow::bail!("rclone sync failed");
    }

    banner::success("MUSIC SYNCED");
    Ok(())
}

mod banner {
    use colored::Colorize;

    pub fn print_banner(title: &str, subtitle: &str, color: &str) {
        let color_fn = match color {
            "cyan" => |s: &str| s.cyan().to_string(),
            "green" => |s: &str| s.green().to_string(),
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
            "cyan" => |s: &str| s.cyan().to_string(),
            "green" => |s: &str| s.green().to_string(),
            _ => |s: &str| s.to_string(),
        };
        println!("   {} {} {}", color_fn(icon), label.bold(), value);
    }

    pub fn success(msg: &str) {
        println!("\n   {} {}\n", "✓".green().bold(), msg.green().bold());
    }

    pub fn divider(color: &str) {
        let color_fn = match color {
            "cyan" => |s: &str| s.cyan().to_string(),
            "green" => |s: &str| s.green().to_string(),
            _ => |s: &str| s.to_string(),
        };
        println!(
            "{}",
            color_fn("   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        );
    }
}
