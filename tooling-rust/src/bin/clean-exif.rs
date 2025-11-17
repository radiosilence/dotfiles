//! Strip EXIF metadata from images in parallel
//!
//! Uses native Rust img-parts crate instead of shelling out to exiftool.

use anyhow::Result;
use clap::Parser;
use colored::Colorize;
use dotfiles_tools::{audio, completions};
use img_parts::jpeg::Jpeg;
use img_parts::png::Png;
use img_parts::{Bytes, ImageEXIF};
use std::fs;
use std::path::{Path, PathBuf};

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

fn clean_exif(file: &Path) -> Result<()> {
    let data = fs::read(file)?;
    let extension = file
        .extension()
        .and_then(|s| s.to_str())
        .unwrap_or("")
        .to_lowercase();

    let cleaned_data = match extension.as_str() {
        "jpg" | "jpeg" => {
            let mut jpeg = Jpeg::from_bytes(Bytes::from(data))?;
            jpeg.set_exif(None);
            jpeg.encoder().bytes()
        }
        "png" => {
            let mut png = Png::from_bytes(Bytes::from(data))?;
            png.set_exif(None);
            png.encoder().bytes()
        }
        _ => anyhow::bail!("Unsupported format: {}", extension),
    };

    fs::write(file, &cleaned_data)?;
    Ok(())
}

fn main() -> Result<()> {
    if completions::handle_completion_flag::<Args>() {
        return Ok(());
    }

    let args = Args::parse();

    println!(
        "{}",
        "╔═══════════════════════════════════════════════╗".bright_yellow()
    );
    println!(
        "{}",
        "║    EXIF METADATA STRIPPER                     ║".bright_yellow()
    );
    println!(
        "{}",
        "║  [strip metadata from images]                 ║".bright_yellow()
    );
    println!(
        "{}",
        "╚═══════════════════════════════════════════════╝".bright_yellow()
    );
    println!();

    println!("{} Scanning for images...", "→".bright_yellow().bold());

    let extensions = ["jpg", "jpeg", "png"];
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
        "{} Stripping: all EXIF metadata",
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
