//! Shared audio processing utilities

use anyhow::{Context, Result};
use indicatif::{ProgressBar, ProgressStyle};
use rayon::prelude::*;
use std::path::{Path, PathBuf};
use std::process::Command;
use walkdir::WalkDir;

/// Supported input audio formats
pub const AUDIO_EXTENSIONS: &[&str] = &["wav", "aiff", "flac", "m4a", "mp3", "ogg"];

/// Find audio files in directories
pub fn find_audio_files(paths: &[PathBuf], extensions: &[&str]) -> Vec<PathBuf> {
    paths
        .iter()
        .flat_map(|path| {
            WalkDir::new(path)
                .into_iter()
                .filter_map(|e| e.ok())
                .filter(|e| e.file_type().is_file())
                .filter(|e| {
                    if let Some(ext) = e.path().extension() {
                        let ext_str = ext.to_str().unwrap_or("");
                        extensions.iter().any(|&x| x.eq_ignore_ascii_case(ext_str))
                    } else {
                        false
                    }
                })
                .map(|e| e.path().to_path_buf())
        })
        .collect()
}

/// Create a progress bar with custom style
pub fn create_progress_bar(total: u64) -> ProgressBar {
    let pb = ProgressBar::new(total);
    pb.set_style(
        ProgressStyle::default_bar()
            .template("{spinner:.cyan} [{bar:40.cyan/blue}] {pos}/{len} {msg}")
            .unwrap()
            .progress_chars("█▓░"),
    );
    pb
}

/// Convert audio file using ffmpeg
pub fn ffmpeg_convert(
    input: &Path,
    output: &Path,
    codec: &str,
    bitrate: Option<u32>,
) -> Result<()> {
    let mut args = vec![
        "-i",
        input.to_str().unwrap(),
        "-c:a",
        codec,
        "-vn", // No video
    ];

    let bitrate_str;
    if let Some(br) = bitrate {
        bitrate_str = format!("{}k", br);
        args.extend(&["-b:a", &bitrate_str]);
    }

    args.push(output.to_str().unwrap());

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
pub fn process_files_parallel<F>(files: Vec<PathBuf>, processor: F) -> Vec<Result<PathBuf>>
where
    F: Fn(&PathBuf, &ProgressBar) -> Result<()> + Sync + Send,
{
    let pb = create_progress_bar(files.len() as u64);

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
pub fn check_command(cmd: &str) -> Result<()> {
    Command::new(cmd)
        .arg("--version")
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .with_context(|| format!("{} not found - please install it", cmd))?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_audio_extensions() {
        assert!(AUDIO_EXTENSIONS.contains(&"flac"));
        assert!(AUDIO_EXTENSIONS.contains(&"wav"));
    }

    #[test]
    fn test_extension_matching() {
        let extensions = ["flac", "wav"];
        assert!(extensions.contains(&"flac"));
    }
}
