use anyhow::Result;
use std::process::Command;

fn main() -> Result<()> {
    banner::print_banner("PUSH MUSIC", "sync from local to remote", "green");

    let src = "/Volumes/Turtlehead/music";

    let dest = if std::path::Path::new("/Volumes/music").exists() {
        "/Volumes/music"
    } else {
        "oldboy.local:/mnt/kontent/music"
    };

    banner::status("□", "SOURCE", src, "green");
    banner::status("□", "DEST", dest, "green");
    banner::divider("green");

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
            dest,
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
