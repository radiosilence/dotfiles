use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use dotfiles_tools::banner;
use std::io;
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
    Completion {
        #[arg(value_enum)]
        shell: Shell,
    },
}

fn main() -> Result<()> {
    let args = Args::parse();

    if let Some(Commands::Completion { shell }) = args.command {
        generate(shell, &mut Args::command(), "pull-music", &mut io::stdout());
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

#[cfg(test)]
mod tests {

    #[test]
    fn test_path_exists_check() {
        let path = std::path::Path::new("/Volumes/music");
        // Just test that we can check existence
        let _exists = path.exists();
    }

    #[test]
    fn test_rclone_args_construction() {
        let args = ["sync", "--progress", "--size-only", "--checkers=16"];
        assert_eq!(args.len(), 4);
        assert_eq!(args[0], "sync");
    }
}
