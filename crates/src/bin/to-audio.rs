//! Convert audio files to various formats in parallel

use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use dotfiles_tools::{audio, banner, parallel};
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
    banner::print_banner("TO-AUDIO FLAC", "lossless audio archival", "green");

    println!("{} Scanning for audio files...", "→".bright_green().bold());

    let extensions = ["wav", "aiff", "m4a"];
    let files = parallel::find_files(paths, &extensions);

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

    if !keep {
        println!(
            "{} Original files will be {}",
            "!".yellow().bold(),
            "DELETED".red().bold()
        );
    }
    println!();

    if dry_run {
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
    banner::print_banner("TO-AUDIO OPUS", "efficient lossy encoding", "cyan");

    banner::loading("Scanning filesystem for audio files...");

    let extensions = ["wav", "aiff", "flac", "m4a"];
    let files = parallel::find_files(paths, &extensions);

    if files.is_empty() {
        banner::warning("No compatible audio files detected");
        return Ok(());
    }

    let cores = num_cpus::get();

    banner::divider("cyan");
    banner::status("□", "FILES FOUND", &files.len().to_string(), "cyan");
    banner::status(
        "□",
        "OUTPUT FORMAT",
        &format!("Opus @ {}kbps", bitrate),
        "cyan",
    );
    banner::status("□", "CPU CORES", &cores.to_string(), "cyan");

    if !keep {
        banner::status("!", "ORIGINALS", "WILL BE DELETED", "red");
    }
    banner::divider("cyan");

    if dry_run {
        println!();
        banner::loading("DRY RUN - files that would be converted:");
        for file in &files {
            println!(
                "   {} {}",
                "▸".bright_black(),
                file.display().to_string().white()
            );
        }
        return Ok(());
    }

    println!();
    banner::loading("Initializing parallel transcoding...");

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

    #[test]
    fn test_path_extension_change() {
        let path = std::path::Path::new("test.wav");
        assert_eq!(path.with_extension("flac").to_str().unwrap(), "test.flac");
        assert_eq!(path.with_extension("opus").to_str().unwrap(), "test.opus");
    }
}
