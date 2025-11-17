//! Convert audio files to FLAC format in parallel

use anyhow::Result;
use clap::Parser;
use colored::Colorize;
use dotfiles_tools::audio;
use dotfiles_tools::completions;
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "to-flac")]
#[command(about = "Convert audio to FLAC format", long_about = None)]
#[command(version)]
struct Args {
    /// Directories to search
    #[arg(value_name = "PATHS", default_value = ".")]
    paths: Vec<PathBuf>,

    /// Keep original files (don't delete)
    #[arg(short = 'k', long)]
    keep: bool,

    /// Dry run - show what would be converted
    #[arg(short = 'n', long)]
    dry_run: bool,
}

fn main() -> Result<()> {
    if completions::handle_completion_flag::<Args>() {
        return Ok(());
    }

    let args = Args::parse();

    println!(
        "{}",
        "╔═══════════════════════════════════════════════╗".bright_green()
    );
    println!(
        "{}",
        "║    AUDIO → FLAC CONVERTER v1.0                ║".bright_green()
    );
    println!(
        "{}",
        "║  [lossless audio archival utility]            ║".bright_green()
    );
    println!(
        "{}",
        "╚═══════════════════════════════════════════════╝".bright_green()
    );
    println!();

    audio::check_command("ffmpeg")?;

    println!("{} Scanning for audio files...", "→".bright_green().bold());

    let extensions = ["wav", "aiff", "m4a"];
    let files = audio::find_audio_files(&args.paths, &extensions);

    if files.is_empty() {
        println!("{} No audio files found", "!".yellow().bold());
        return Ok(());
    }

    let cores = num_cpus::get();
    println!();
    println!(
        "{} Found {} files",
        "→".bright_green().bold(),
        files.len().to_string().bright_white().bold()
    );
    println!("{} Output: FLAC (lossless)", "→".bright_green().bold());
    println!(
        "{} Cores: {}",
        "→".bright_green().bold(),
        cores.to_string().green()
    );

    if !args.keep {
        println!(
            "{} Original files will be {}",
            "!".yellow().bold(),
            "DELETED".red().bold()
        );
    }
    println!();

    if args.dry_run {
        println!(
            "{} Dry run - files that would be converted:",
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

    let keep_originals = args.keep;

    let results = audio::process_files_parallel(files, |file, _pb| {
        let output = file.with_extension("flac");
        audio::ffmpeg_convert(file, &output, "flac", None)?;

        if !keep_originals {
            std::fs::remove_file(file)?;
        }

        Ok(())
    });

    let success_count = results.iter().filter(|r| r.is_ok()).count();
    let error_count = results.len() - success_count;

    println!();
    if error_count > 0 {
        println!(
            "{} Converted {} files ({} {})",
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
            "{} Converted {} files",
            "✓".green().bold(),
            success_count.to_string().green().bold()
        );
    }

    Ok(())
}
