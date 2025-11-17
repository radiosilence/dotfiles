//! Clean up scene release garbage from downloads
//!
//! Removes .nfo, .txt, sample files, and other cruft from music/video downloads.

use anyhow::Result;
use clap::Parser;
use colored::Colorize;
use std::path::PathBuf;
use std::process::Command;
use walkdir::WalkDir;

#[derive(Parser)]
#[command(name = "clean-dls")]
#[command(about = "Clean scene release garbage", long_about = None)]
#[command(version)]
struct Args {
    /// Directories to clean
    #[arg(value_name = "PATHS", default_value = ".")]
    paths: Vec<PathBuf>,

    /// Dry run - show what would be deleted
    #[arg(short = 'n', long)]
    dry_run: bool,
}

fn main() -> Result<()> {
    let args = Args::parse();

    println!(
        "{}",
        "╔═══════════════════════════════════════════════╗".bright_red()
    );
    println!(
        "{}",
        "║    DOWNLOAD CLEANER v1.0                      ║".bright_red()
    );
    println!(
        "{}",
        "║  [scene release garbage removal]              ║".bright_red()
    );
    println!(
        "{}",
        "╚═══════════════════════════════════════════════╝".bright_red()
    );
    println!();

    // Patterns to delete
    let patterns = vec![
        ".DS_Store",
        "*.nfo",
        "*.txt",
        "*.sfv",
        "*sample*",
        "._*", // macOS resource forks
    ];

    println!("{} Scanning for garbage files...", "→".bright_red().bold());
    println!(
        "{} Patterns: {}",
        "→".bright_red().bold(),
        patterns.join(", ").yellow()
    );
    println!();

    let mut to_delete = Vec::new();

    for path in &args.paths {
        for entry in WalkDir::new(path)
            .into_iter()
            .filter_map(|e| e.ok())
            .filter(|e| e.file_type().is_file())
        {
            let file_name = entry.file_name().to_string_lossy().to_lowercase();

            if file_name == ".ds_store"
                || file_name.ends_with(".nfo")
                || file_name.ends_with(".txt")
                || file_name.ends_with(".sfv")
                || file_name.contains("sample")
                || file_name.starts_with("._")
            {
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
