//! Parallel processing utilities

use anyhow::Result;
use indicatif::{ProgressBar, ProgressStyle};
use rayon::prelude::*;
use std::path::PathBuf;
use walkdir::WalkDir;

/// Find files matching patterns and process in parallel
pub fn process_files<F>(
    paths: &[PathBuf],
    extensions: &[&str],
    processor: F,
) -> Result<Vec<Result<()>>>
where
    F: Fn(&PathBuf) -> Result<()> + Send + Sync,
{
    // Collect all matching files
    let files: Vec<PathBuf> = paths
        .iter()
        .flat_map(|path| {
            WalkDir::new(path)
                .into_iter()
                .filter_map(|e| e.ok())
                .filter(|e| e.file_type().is_file())
                .filter(|e| {
                    if let Some(ext) = e.path().extension() {
                        extensions.iter().any(|&x| x == ext.to_string_lossy())
                    } else {
                        false
                    }
                })
                .map(|e| e.path().to_path_buf())
        })
        .collect();

    if files.is_empty() {
        return Ok(vec![]);
    }

    // Create progress bar
    let pb = ProgressBar::new(files.len() as u64);
    pb.set_style(
        ProgressStyle::default_bar()
            .template("[{elapsed_precise}] {bar:40.cyan/blue} {pos}/{len} {msg}")
            .unwrap()
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
