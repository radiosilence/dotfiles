//! Clean up scene release garbage from downloads
//!
//! Removes .nfo, .txt, sample files, and other cruft from music/video downloads.

use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use dialoguer::Confirm;
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

    println!("\n/// {}\n", "CLEAN-DLS".bold());

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
        println!("  {} No garbage files found", "✓".green());
        return Ok(());
    }

    println!("  {} Found {} garbage files", "!".yellow(), to_delete.len());

    for file in &to_delete {
        println!("  {}", file.display());
    }

    if args.dry_run {
        println!("  {} Mode: dry-run", "→".bright_black());
        return Ok(());
    }

    println!();
    let confirmed = Confirm::new()
        .with_prompt("Delete these files?")
        .default(false)
        .interact()?;

    if !confirmed {
        println!("  {} Cancelled", "✗".red());
        return Ok(());
    }

    let mut deleted = 0;
    for file in &to_delete {
        match std::fs::remove_file(file) {
            Ok(()) => deleted += 1,
            Err(e) => eprintln!("  {} {}: {}", "!".yellow(), file.display(), e),
        }
    }

    println!("  {} Deleted {deleted} files", "✓".green());

    // Run prune if it exists to clean up empty directories
    let _ = Command::new("prune").args(&args.paths).status();

    Ok(())
}

/// Known scene release garbage filenames
const GARBAGE_FILENAMES: &[&str] = &["readme.txt", "info.txt", "nfo.txt", "file_id.diz"];

fn should_delete_file(filename: &str) -> bool {
    let lower = filename.to_lowercase();
    lower == ".ds_store"
        || lower.ends_with(".nfo")
        || lower.ends_with(".png")
        || lower.ends_with(".jpg")
        || lower.ends_with(".jpeg")
        || lower.ends_with(".sfv")
        || lower.starts_with("._")
        || GARBAGE_FILENAMES.contains(&lower.as_str())
        || is_sample_file(&lower)
}

/// Check if a filename is a sample file using word boundary matching
/// to avoid false positives like "resampled.flac" or "SamplerV2.wav"
fn is_sample_file(lower: &str) -> bool {
    let stem = lower.rsplit_once('.').map_or(lower, |(s, _)| s);
    // Exact match or word-boundary: "sample", "sample-xxx", "xxx-sample", "xxx_sample_xxx"
    stem == "sample"
        || stem.starts_with("sample-")
        || stem.starts_with("sample_")
        || stem.starts_with("sample ")
        || stem.ends_with("-sample")
        || stem.ends_with("_sample")
        || stem.contains("-sample-")
        || stem.contains("_sample_")
        || stem.contains("-sample_")
        || stem.contains("_sample-")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn should_delete_file_catches_all_patterns() {
        // DS_Store files
        assert!(should_delete_file(".DS_Store"));
        assert!(should_delete_file(".ds_store"));

        // Scene release metadata
        assert!(should_delete_file("readme.nfo"));
        assert!(should_delete_file("README.NFO"));
        assert!(should_delete_file("checksums.sfv"));

        // Known garbage txt files
        assert!(should_delete_file("info.txt"));
        assert!(should_delete_file("readme.txt"));
        assert!(should_delete_file("README.TXT"));

        // Images
        assert!(should_delete_file("cover.png"));
        assert!(should_delete_file("image.jpg"));
        assert!(should_delete_file("photo.jpeg"));

        // Sample files (word-boundary matching)
        assert!(should_delete_file("sample.mp3"));
        assert!(should_delete_file("track-sample.flac"));
        assert!(should_delete_file("SAMPLE.WAV"));
        assert!(should_delete_file("sample-track.mp3"));
        assert!(should_delete_file("track_sample_01.flac"));

        // macOS resource forks
        assert!(should_delete_file("._file.txt"));
        assert!(should_delete_file("._Document.pdf"));
    }

    #[test]
    fn should_delete_file_preserves_real_content() {
        assert!(!should_delete_file("song.mp3"));
        assert!(!should_delete_file("track.flac"));
        assert!(!should_delete_file("audio.wav"));
        assert!(!should_delete_file("document.pdf"));
        assert!(!should_delete_file("script.sh"));
        assert!(!should_delete_file("config.json"));
        // These should NOT be deleted anymore (txt files that aren't known garbage)
        assert!(!should_delete_file("lyrics.txt"));
        assert!(!should_delete_file("tracklist.txt"));
        // Substring "sample" that isn't a word boundary
        assert!(!should_delete_file("resampled.flac"));
        assert!(!should_delete_file("SamplerV2.wav"));
        assert!(!should_delete_file("downsample.aiff"));
    }

    #[test]
    fn should_delete_file_is_case_insensitive() {
        assert!(should_delete_file("README.NFO"));
        assert!(should_delete_file("Info.TXT"));
        assert!(should_delete_file("SAMPLE-track.mp3"));
        assert!(should_delete_file(".DS_STORE"));
    }

    #[test]
    fn should_delete_file_handles_edge_cases() {
        // Resource fork prefix
        assert!(should_delete_file("._"));
        assert!(should_delete_file("._something"));

        // Exact .ds_store match
        assert!(should_delete_file(".ds_store"));
        assert!(!should_delete_file("ds_store"));
        assert!(!should_delete_file(".ds_store.backup"));
    }
}
