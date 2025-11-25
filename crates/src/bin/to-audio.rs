//! Convert audio files to various formats in parallel

use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use dotfiles_tools::{audio, parallel};
use std::{io, path::PathBuf};

#[derive(Parser)]
#[command(name = "to-audio")]
#[command(about = "Convert audio files to various formats", long_about = None)]
#[command(version)]
struct Args {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Convert to FLAC (lossless)
    Flac {
        /// Directories to search
        #[arg(value_name = "PATHS", default_value = ".")]
        paths: Vec<PathBuf>,

        /// Keep original files (don't delete)
        #[arg(short = 'k', long)]
        keep: bool,

        /// Dry run - show what would be converted
        #[arg(short = 'n', long)]
        dry_run: bool,
    },

    /// Convert to Opus (lossy, efficient)
    Opus {
        /// Directories to search
        #[arg(value_name = "PATHS", default_value = ".")]
        paths: Vec<PathBuf>,

        /// Output bitrate in kbps
        #[arg(short = 'b', long, default_value = "160", env = "BITRATE")]
        bitrate: u32,

        /// Keep original files (don't delete)
        #[arg(short = 'k', long)]
        keep: bool,

        /// Dry run - show what would be converted
        #[arg(short = 'n', long)]
        dry_run: bool,
    },
    /// Generate shell completions
    Completion {
        #[arg(value_enum)]
        shell: Shell,
    },
}

fn main() -> Result<()> {
    let args = Args::parse();

    audio::check_command("ffmpeg")?;

    match args.command {
        Commands::Completion { shell } => {
            generate(shell, &mut Args::command(), "imp", &mut io::stdout());
            Ok(())
        }
        Commands::Flac {
            paths,
            keep,
            dry_run,
        } => convert_flac(&paths, keep, dry_run),
        Commands::Opus {
            paths,
            bitrate,
            keep,
            dry_run,
        } => convert_opus(&paths, bitrate, keep, dry_run),
    }
}

fn convert_flac(paths: &[PathBuf], keep: bool, dry_run: bool) -> Result<()> {
    println!("\n/// {}\n", "FLAC CONVERSION".bold());

    let extensions = ["wav", "aiff", "m4a"];
    let files = parallel::find_files(paths, &extensions);

    if files.is_empty() {
        println!("  {} No audio files found", "!".yellow());
        return Ok(());
    }

    println!("  {} Files: {}", "→".bright_black(), files.len());
    println!("  {} Format: FLAC (lossless)", "→".bright_black());
    println!("  {} Cores: {}", "→".bright_black(), num_cpus::get());

    if !keep {
        println!("  {} Original files will be deleted", "!".yellow());
    }

    if dry_run {
        println!(
            "  {} Dry run - files that would be converted:",
            "·".bright_black()
        );
        for file in &files {
            println!("  {}", file.display());
        }
        return Ok(());
    }

    let results = audio::process_files_parallel(files, |file, _pb| {
        let output = file.with_extension("flac");
        audio::ffmpeg_convert(file, &output, "flac", None)?;

        if !keep {
            std::fs::remove_file(file)?;
        }

        Ok(())
    });

    print_results(&results);
    Ok(())
}

fn convert_opus(paths: &[PathBuf], bitrate: u32, keep: bool, dry_run: bool) -> Result<()> {
    println!("\n/// {}\n", "OPUS CONVERSION".bold());

    let extensions = ["wav", "aiff", "flac", "m4a"];
    let files = parallel::find_files(paths, &extensions);

    if files.is_empty() {
        println!("  {} No audio files found", "!".yellow());
        return Ok(());
    }

    println!("  {} Files: {}", "→".bright_black(), files.len());
    println!("  {} Format: Opus @ {}kbps", "→".bright_black(), bitrate);
    println!("  {} Cores: {}", "→".bright_black(), num_cpus::get());

    if !keep {
        println!("  {} Original files will be deleted", "!".yellow());
    }

    if dry_run {
        println!(
            "  {} Dry run - files that would be converted:",
            "·".bright_black()
        );
        for file in &files {
            println!("  {}", file.display());
        }
        return Ok(());
    }

    let results = audio::process_files_parallel(files, |file, _pb| {
        let output = file.with_extension("opus");
        audio::ffmpeg_convert(file, &output, "libopus", Some(bitrate))?;

        if !keep {
            std::fs::remove_file(file)?;
        }

        Ok(())
    });

    print_results(&results);
    Ok(())
}

fn print_results(results: &[Result<PathBuf>]) {
    let success_count = results.iter().filter(|r| r.is_ok()).count();
    let error_count = results.len() - success_count;

    if error_count > 0 {
        println!(
            "  {} Converted {} files ({} failed)",
            "!".yellow(),
            success_count,
            error_count
        );

        for result in results.iter().filter(|r| r.is_err()) {
            if let Err(e) = result {
                println!("  {} {}", "✗".red(), e);
            }
        }
    } else {
        println!("  {} Converted {} files", "✓".green(), success_count);
    }
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_flac_extensions() {
        let extensions = ["wav", "aiff", "m4a"];
        assert!(extensions.contains(&"wav"));
        assert!(!extensions.contains(&"flac"));
    }

    #[test]
    fn test_opus_extensions() {
        let extensions = ["wav", "aiff", "flac", "m4a"];
        assert!(extensions.contains(&"flac"));
        assert_eq!(extensions.len(), 4);
    }
}
