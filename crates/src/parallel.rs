//! Parallel processing utilities

use anyhow::Result;
use indicatif::{ProgressBar, ProgressStyle};
use rayon::prelude::*;
use std::path::PathBuf;
use walkdir::WalkDir;

/// Create a progress bar with custom style
///
/// # Panics
/// Panics if the progress bar template is invalid
#[must_use]
pub fn create_progress_bar(total: u64) -> ProgressBar {
    let pb = ProgressBar::new(total);
    pb.set_style(
        ProgressStyle::default_bar()
            .template("{spinner:.cyan} [{bar:40.cyan/blue}] {pos}/{len} {msg}")
            .expect("Invalid progress bar template")
            .progress_chars("█▓░"),
    );
    pb
}

/// Find files matching extension patterns in given paths
///
/// # Arguments
/// * `paths` - Directories to search
/// * `extensions` - File extensions to match (case-insensitive)
#[must_use]
pub fn find_files(paths: &[PathBuf], extensions: &[&str]) -> Vec<PathBuf> {
    paths
        .iter()
        .flat_map(|path| {
            WalkDir::new(path)
                .into_iter()
                .filter_map(Result::ok)
                .filter(|e| e.file_type().is_file())
                .filter(|e| {
                    e.path()
                        .extension()
                        .and_then(|ext| ext.to_str())
                        .is_some_and(|ext_str| {
                            extensions.iter().any(|&x| x.eq_ignore_ascii_case(ext_str))
                        })
                })
                .map(|e| e.path().to_path_buf())
        })
        .collect()
}

/// Find files matching patterns and process in parallel
///
/// # Errors
/// Returns error if directory traversal fails. Individual file processing errors are in the result vector.
///
/// # Panics
/// Panics if the progress bar template is invalid
pub fn process_files<F>(
    paths: &[PathBuf],
    extensions: &[&str],
    processor: F,
) -> Result<Vec<Result<()>>>
where
    F: Fn(&PathBuf) -> Result<()> + Send + Sync,
{
    let files = find_files(paths, extensions);

    if files.is_empty() {
        return Ok(vec![]);
    }

    // Create progress bar
    let pb = ProgressBar::new(files.len() as u64);
    pb.set_style(
        ProgressStyle::default_bar()
            .template("[{elapsed_precise}] {bar:40.cyan/blue} {pos}/{len} {msg}")
            .expect("Invalid progress bar template")
            .progress_chars("=> "),
    );

    // Process files in parallel
    let results: Vec<Result<()>> = files
        .par_iter()
        .map(|file| {
            let result = processor(file);
            pb.inc(1);
            result
        })
        .collect();

    pb.finish_with_message("Done");

    Ok(results)
}
