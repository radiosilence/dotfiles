//! Clean up scene release garbage from downloads
//!
//! Removes .nfo, .txt, sample files, and other cruft from music/video downloads.

use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use dialoguer::Confirm;
use dotfiles_tools::banner;
use std::io;
use std::path::PathBuf;
use std::process::Command;
use walkdir::WalkDir;

#[derive(Parser)]
#[command(name = "clean-dls")]
#[command(about = "Clean scene release garbage", long_about = None)]
#[command(version)]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,

    /// Directories to clean
    #[arg(value_name = "PATHS", default_value = ".")]
    paths: Vec<PathBuf>,

    /// Dry run - show what would be deleted
    #[arg(short = 'n', long)]
    dry_run: bool,
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
        generate(shell, &mut Args::command(), "clean-dls", &mut io::stdout());
        return Ok(());
    }

    banner::print_banner("CLEAN-DLS", "scene release garbage removal", "red");

    println!("{} Scanning for garbage files...", "→".bright_red().bold());
    println!(
        "{} Patterns: .ds_store, *.nfo, *.txt, *.png, *.jpg, *.jpeg, *.sfv, *sample*, ._*",
        "→".bright_red().bold()
    );
    println!();

    let mut to_delete = Vec::new();

    for path in &args.paths {
        for entry in WalkDir::new(path)
            .into_iter()
            .filter_map(|e| e.ok())
            .filter(|e| e.file_type().is_file())
        {
            let file_name = entry.file_name().to_string_lossy();

            if should_delete_file(&file_name) {
                to_delete.push(entry.path().to_path_buf());
            }
        }
    }

    if to_delete.is_empty() {
        println!("{} No garbage files found", "✓".green().bold());
        return Ok(());
    }

    println!(
        "{} Found {} garbage files:",
        "!".yellow().bold(),
        to_delete.len().to_string().red().bold()
    );

    for file in &to_delete {
        println!(
            "  {} {}",
            "×".red().bold(),
            file.display().to_string().bright_black()
        );
    }
    println!();

    if args.dry_run {
        println!("{} Dry run - no files deleted", "i".blue().bold());
        return Ok(());
    }

    let confirmed = Confirm::new()
        .with_prompt(format!("{} Delete these directories?", "?".yellow().bold()))
        .default(false)
        .interact()?;

    if !confirmed {
        println!("{} Operation cancelled", "×".red().bold());
        return Ok(());
    }

    let mut deleted = 0;
    for file in &to_delete {
        if std::fs::remove_file(file).is_ok() {
            deleted += 1;
        }
    }

    println!(
        "{} Deleted {} files",
        "✓".green().bold(),
        deleted.to_string().green().bold()
    );

    // Run prune if it exists
    println!();
    println!(
        "{} Running prune to clean small directories...",
        "→".bright_red().bold()
    );

    let _ = Command::new("prune").args(&args.paths).status();

    Ok(())
}

fn should_delete_file(filename: &str) -> bool {
    let lower = filename.to_lowercase();
    lower == ".ds_store"
        || lower.ends_with(".nfo")
        || lower.ends_with(".txt")
        || lower.ends_with(".png")
        || lower.ends_with(".jpg")
        || lower.ends_with(".jpeg")
        || lower.ends_with(".sfv")
        || lower.contains("sample")
        || lower.starts_with("._")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_should_delete_ds_store() {
        assert!(should_delete_file(".DS_Store"));
        assert!(should_delete_file(".ds_store"));
    }

    #[test]
    fn test_should_delete_nfo() {
        assert!(should_delete_file("readme.nfo"));
        assert!(should_delete_file("README.NFO"));
    }

    #[test]
    fn test_should_delete_txt() {
        assert!(should_delete_file("readme.txt"));
        assert!(should_delete_file("info.TXT"));
    }

    #[test]
    fn test_should_delete_images() {
        assert!(should_delete_file("cover.png"));
        assert!(should_delete_file("image.jpg"));
        assert!(should_delete_file("photo.jpeg"));
        assert!(should_delete_file("COVER.PNG"));
    }

    #[test]
    fn test_should_delete_sfv() {
        assert!(should_delete_file("checksums.sfv"));
        assert!(should_delete_file("file.SFV"));
    }

    #[test]
    fn test_should_delete_sample() {
        assert!(should_delete_file("sample.mp3"));
        assert!(should_delete_file("track-sample.flac"));
        assert!(should_delete_file("SAMPLE.WAV"));
    }

    #[test]
    fn test_should_delete_resource_fork() {
        assert!(should_delete_file("._file.txt"));
        assert!(should_delete_file("._Document.pdf"));
    }

    #[test]
    fn test_should_not_delete_music() {
        assert!(!should_delete_file("song.mp3"));
        assert!(!should_delete_file("track.flac"));
        assert!(!should_delete_file("audio.wav"));
    }

    #[test]
    fn test_should_not_delete_normal_files() {
        assert!(!should_delete_file("document.pdf"));
        assert!(!should_delete_file("script.sh"));
        assert!(!should_delete_file("config.json"));
    }

    #[test]
    fn test_case_insensitive() {
        assert!(should_delete_file("README.NFO"));
        assert!(should_delete_file("Info.TxT"));
        assert!(should_delete_file("SAMPLE-track.mp3"));
    }
}
