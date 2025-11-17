//! Shared audio processing utilities

use crate::parallel;
use anyhow::{Context, Result};
use indicatif::ProgressBar;
use rayon::prelude::*;
use std::path::{Path, PathBuf};
use std::process::Command;

/// Supported input audio formats
pub const AUDIO_EXTENSIONS: &[&str] = &["wav", "aiff", "flac", "m4a", "mp3", "ogg"];

/// Convert audio file using ffmpeg
///
/// # Errors
/// Returns error if ffmpeg command fails or file paths are invalid
///
/// # Panics
/// Panics if input or output paths contain invalid UTF-8
pub fn ffmpeg_convert(
    input: &Path,
    output: &Path,
    codec: &str,
    bitrate: Option<u32>,
) -> Result<()> {
    let mut args = vec![
        "-i",
        input.to_str().expect("Invalid UTF-8 in input path"),
        "-c:a",
        codec,
        "-vn", // No video
    ];

    let bitrate_str;
    if let Some(br) = bitrate {
        bitrate_str = format!("{br}k");
        args.extend(&["-b:a", &bitrate_str]);
    }

    args.push(output.to_str().expect("Invalid UTF-8 in output path"));

    let status = Command::new("ffmpeg")
        .args(&args)
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .context("Failed to run ffmpeg")?;

    if !status.success() {
        anyhow::bail!("ffmpeg failed for {}", input.display());
    }

    Ok(())
}

/// Process files in parallel with progress tracking
///
/// # Errors
/// Returns a vector of results, one per file. Failed files have error results.
pub fn process_files_parallel<F>(files: Vec<PathBuf>, processor: F) -> Vec<Result<PathBuf>>
where
    F: Fn(&PathBuf, &ProgressBar) -> Result<()> + Sync + Send,
{
    let pb = parallel::create_progress_bar(files.len() as u64);

    let results: Vec<Result<PathBuf>> = files
        .par_iter()
        .map(|file| {
            pb.set_message(
                file.file_name()
                    .unwrap_or_default()
                    .to_string_lossy()
                    .to_string(),
            );

            processor(file, &pb)?;
            pb.inc(1);
            Ok(file.clone())
        })
        .collect();

    pb.finish_and_clear();
    results
}

/// Check if a command exists
///
/// # Errors
/// Returns error if the command is not found or cannot be executed
pub fn check_command(cmd: &str) -> Result<()> {
    Command::new(cmd)
        .arg("--version")
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .with_context(|| format!("{cmd} not found - please install it"))?;
    Ok(())
}
