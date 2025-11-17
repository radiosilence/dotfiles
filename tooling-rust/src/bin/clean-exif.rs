//! Strip EXIF metadata from images in parallel
//!
//! Removes GPS, camera serial numbers, and other PII from images.

use anyhow::Result;
use clap::Parser;
use colored::Colorize;
use dotfiles_tools::audio;
use std::path::PathBuf;
use std::process::Command;

#[derive(Parser)]
#[command(name = "clean-exif")]
#[command(about = "Strip EXIF metadata from images", long_about = None)]
#[command(version)]
struct Args {
    /// Directories to search
    #[arg(value_name = "PATHS", default_value = ".")]
    paths: Vec<PathBuf>,

    /// Dry run - show what would be cleaned
    #[arg(short = 'n', long)]
    dry_run: bool,
}

fn clean_exif(file: &PathBuf) -> Result<()> {
    let status = Command::new("exiftool")
        .args([
            "-all=",               // Clear all tags
            "-overwrite_original", // Don't keep backup
            "-P",                  // Preserve file modification time
            file.to_str().unwrap(),
        ])
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()?;

    if !status.success() {
        anyhow::bail!("exiftool failed for {}", file.display());
    }

    Ok(())
}

fn main() -> Result<()> {
    let args = Args::parse();

    println!(
        "{}",
        "╔═══════════════════════════════════════════════╗".bright_yellow()
    );
    println!(
        "{}",
        "║    EXIF METADATA STRIPPER v1.0                ║".bright_yellow()
    );
    println!(
        "{}",
        "║  [privacy protection utility]                 ║".bright_yellow()
    );
    println!(
        "{}",
        "╚═══════════════════════════════════════════════╝".bright_yellow()
    );
    println!();

    // Check dependencies
    audio::check_command("exiftool")?;

    println!("{} Scanning for images...", "→".bright_yellow().bold());

    let extensions = ["jpg", "jpeg", "png", "tiff", "webp"];
    let files = audio::find_audio_files(&args.paths, &extensions);

    if files.is_empty() {
        println!("{} No image files found", "!".yellow().bold());
        return Ok(());
    }

    let cores = num_cpus::get();
    println!();
    println!(
        "{} Found {} images",
        "→".bright_yellow().bold(),
        files.len().to_string().bright_white().bold()
    );
    println!(
        "{} Cores: {}",
        "→".bright_yellow().bold(),
        cores.to_string().green()
    );
    println!(
        "{} Stripping: GPS, camera serial, copyright, XMP, IPTC",
        "→".bright_yellow().bold()
    );
    println!();

    if args.dry_run {
        println!(
            "{} Dry run - files that would be cleaned:",
            "i".blue().bold()
        );
        for file in &files {
            println!(
                "  {} {}",
                "→".bright_black(),
                file.display().to_string().white()
            );
        }
        return Ok(());
    }

    let results = audio::process_files_parallel(files, |file, _pb| {
        clean_exif(file)?;
        Ok(())
    });

    let success_count = results.iter().filter(|r| r.is_ok()).count();
    let error_count = results.len() - success_count;

    println!();
    if error_count > 0 {
        println!(
            "{} Cleaned {} files ({} {})",
            "!".yellow().bold(),
            success_count.to_string().green(),
            error_count.to_string().red(),
            "failed".red()
        );

        for result in results.iter().filter(|r| r.is_err()) {
            if let Err(e) = result {
                eprintln!("  {} {}", "×".red().bold(), e);
            }
        }
    } else {
        println!(
            "{} Cleaned {} images",
            "✓".green().bold(),
            success_count.to_string().green().bold()
        );
    }

    Ok(())
}
