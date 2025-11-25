//! Parallel processing utilities

use indicatif::{ProgressBar, ProgressStyle};
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
