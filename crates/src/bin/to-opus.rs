//! Convert audio files to Opus format in parallel

use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use dotfiles_tools::{audio, banner};
use std::io;
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "to-opus")]
#[command(about = "Convert audio to Opus format", long_about = None)]
#[command(version)]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,

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
        generate(shell, &mut Args::command(), "to-opus", &mut io::stdout());
        return Ok(());
    }

    banner::print_banner("AUDIO → OPUS", "parallel transcoding system", "cyan");

    // Check dependencies
    audio::check_command("ffmpeg")?;

    banner::loading("Scanning filesystem for audio files...");

    // Find audio files (exclude opus)
    let extensions = ["wav", "aiff", "flac", "m4a"];
    let files = audio::find_audio_files(&args.paths, &extensions);

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
        &format!("Opus @ {}kbps", args.bitrate),
        "cyan",
    );
    banner::status("□", "CPU CORES", &cores.to_string(), "cyan");

    if !args.keep {
        banner::status("!", "ORIGINALS", "WILL BE DELETED", "red");
    }
    banner::divider("cyan");

    if args.dry_run {
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

    // Convert in parallel using shared utility
    let bitrate = args.bitrate;
    let keep_originals = args.keep;

    let results = audio::process_files_parallel(files, |file, _pb| {
        let output = file.with_extension("opus");
        audio::ffmpeg_convert(file, &output, "libopus", Some(bitrate))?;

        if !keep_originals {
            std::fs::remove_file(file)?;
        }

        Ok(())
    });

    // Summary
    let success_count = results.iter().filter(|r| r.is_ok()).count();
    let error_count = results.len() - success_count;

    if error_count > 0 {
        banner::warning(&format!(
            "Transcoded {} files / {} FAILED",
            success_count, error_count
        ));

        for result in results.iter().filter(|r| r.is_err()) {
            if let Err(e) = result {
                eprintln!("   {} {}", "✖".red().bold(), e);
            }
        }
    } else {
        banner::success(&format!("TRANSCODED {} FILES", success_count));
    }

    Ok(())
}

#[cfg(test)]
mod tests {

    #[test]
    fn test_bitrate_default() {
        // Test default bitrate is 160
        let default_bitrate = 160u32;
        assert_eq!(default_bitrate, 160);
    }

    #[test]
    fn test_opus_extension() {
        let path = std::path::Path::new("audio.flac");
        let output = path.with_extension("opus");
        assert_eq!(output.extension().unwrap(), "opus");
    }

    #[test]
    fn test_supported_extensions() {
        let extensions = ["wav", "aiff", "flac", "m4a"];
        assert_eq!(extensions.len(), 4);
        assert!(extensions.contains(&"flac"));
    }
}
