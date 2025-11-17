use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use std::io;
use std::process::Command;
use dotfiles_tools::banner;

#[derive(Parser)]
#[command(name = "push-music")]
#[command(about = "Sync music to remote", long_about = None)]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,
}

#[derive(Subcommand)]
enum Commands {
    /// Generate shell completions
    Completion {
        #[arg(value_enum)]
        shell: Shell,
    },
}

fn main() -> Result<()> {
    let args = Args::parse();

    if let Some(Commands::Completion { shell }) = args.command {
        generate(shell, &mut Args::command(), "push-music", &mut io::stdout());
        return Ok(());
    }

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

#[cfg(test)]
mod tests {

    #[test]
    fn test_volume_path() {
        let src = "/Volumes/Turtlehead/music";
        assert!(src.starts_with("/Volumes/"));
        assert!(src.contains("music"));
    }

    #[test]
    fn test_path_validation() {
        let path = std::path::Path::new("/Volumes/music");
        assert!(path.is_absolute());
    }
}
