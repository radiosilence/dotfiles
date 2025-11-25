//! Import music from URLs
//!
//! Downloads music archives, extracts them, and imports to beets library

use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use rayon::prelude::*;
use reqwest::blocking::Client;
use std::fs::File;
use std::io::{self, Read, Write};
use std::path::Path;
use std::process::{Command, Stdio};
use tempfile::TempDir;

#[derive(Parser)]
#[command(name = "imp")]
#[command(about = "Import music from URLs", long_about = None)]
#[command(version)]
#[command(args_conflicts_with_subcommands = true)]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,

    /// URLs to download and import
    #[arg(value_name = "URLS")]
    urls: Vec<String>,
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
        generate(shell, &mut Args::command(), "imp", &mut io::stdout());
        return Ok(());
    }

    if args.urls.is_empty() {
        anyhow::bail!(Args::command().render_help());
    }

    let temp_dir = TempDir::new()?;
    let dest = temp_dir.path();

    println!("\n/// {}\n", "MUSIC IMPORTER".bold());
    println!("  {} temp dir: {}", "→".bright_black(), dest.display());
    println!("  {} urls: {}", "→".bright_black(), args.urls.len());

    // Download in parallel
    println!("  {} Downloading archives...", "·".bright_black());

    let client = Client::builder()
        .timeout(std::time::Duration::from_secs(300))
        .build()?;

    let downloaded_files: Vec<Result<std::path::PathBuf>> = args
        .urls
        .par_iter()
        .map(|url| download_file(&client, url, dest))
        .collect();

    let successful_downloads: Vec<_> = downloaded_files
        .into_iter()
        .filter_map(|r| r.ok())
        .collect();

    if successful_downloads.is_empty() {
        println!("  {} No files downloaded successfully", "✗".red());
        anyhow::bail!("Download failed");
    }

    println!(
        "  {} Downloaded {} files",
        "✓".green(),
        successful_downloads.len()
    );

    // Extract archives in parallel
    println!("  {} Extracting archives...", "·".bright_black());

    let extract_results: Vec<Result<()>> = successful_downloads
        .par_iter()
        .filter(|path| path.extension().and_then(|s| s.to_str()) == Some("zip"))
        .map(|zip_path| {
            extract_zip(zip_path, dest)?;
            std::fs::remove_file(zip_path)?;
            Ok(())
        })
        .collect();

    let extract_success = extract_results.iter().filter(|r| r.is_ok()).count();
    println!("  {} Extracted {} archives", "✓".green(), extract_success);

    // Show extracted files
    println!("  {} Files:", "·".bright_black());
    let _ = Command::new("lsd")
        .args(["--tree", dest.to_str().unwrap()])
        .status()
        .or_else(|_| Command::new("tree").arg(dest.to_str().unwrap()).status());

    // Import to beets with stdin exposed for user input
    println!("  {} Importing to beets...", "·".bright_black());

    let status = Command::new("beet")
        .args(["import", dest.to_str().unwrap()])
        .stdin(Stdio::inherit())
        .status()?;

    if !status.success() {
        println!("  {} Beets import failed", "✗".red());
        anyhow::bail!("Import failed");
    }

    println!("  {} Import complete", "✓".green());

    Ok(())
}

fn download_file(client: &Client, url: &str, dest_dir: &Path) -> Result<std::path::PathBuf> {
    let mut response = client.get(url).send()?;

    if !response.status().is_success() {
        anyhow::bail!("Failed to download {}: {}", url, response.status());
    }

    // Generate unique filename since we'll scan for zips anyway
    let file_name = format!(
        "download_{}.zip",
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos()
    );
    let dest_path = dest_dir.join(&file_name);

    let mut file = File::create(&dest_path)?;
    let mut buffer = [0; 8192];

    loop {
        let n = response.read(&mut buffer)?;
        if n == 0 {
            break;
        }
        file.write_all(&buffer[..n])?;
    }

    Ok(dest_path)
}

fn extract_zip(zip_path: &Path, dest_dir: &Path) -> Result<()> {
    let file = File::open(zip_path)?;
    let mut archive = zip::ZipArchive::new(file)?;

    for i in 0..archive.len() {
        let mut file = archive.by_index(i)?;
        let outpath = match file.enclosed_name() {
            Some(path) => dest_dir.join(path),
            None => continue,
        };

        if file.name().ends_with('/') {
            std::fs::create_dir_all(&outpath)?;
        } else {
            if let Some(p) = outpath.parent() {
                if !p.exists() {
                    std::fs::create_dir_all(p)?;
                }
            }
            let mut outfile = File::create(&outpath)?;
            std::io::copy(&mut file, &mut outfile)?;
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_extract_zip_creates_files() -> Result<()> {
        let temp = TempDir::new()?;
        let zip_path = temp.path().join("test.zip");

        // Create a simple zip with one file
        let file = File::create(&zip_path)?;
        let mut zip = zip::ZipWriter::new(file);
        let options = zip::write::FileOptions::<()>::default();
        zip.start_file("test.txt", options)?;
        zip.write_all(b"test content")?;
        zip.finish()?;

        let extract_dir = temp.path().join("extracted");
        std::fs::create_dir(&extract_dir)?;

        extract_zip(&zip_path, &extract_dir)?;

        let extracted_file = extract_dir.join("test.txt");
        assert!(extracted_file.exists());

        let content = std::fs::read_to_string(extracted_file)?;
        assert_eq!(content, "test content");

        Ok(())
    }

    #[test]
    fn test_extract_zip_handles_nested_dirs() -> Result<()> {
        let temp = TempDir::new()?;
        let zip_path = temp.path().join("test.zip");

        let file = File::create(&zip_path)?;
        let mut zip = zip::ZipWriter::new(file);
        let options = zip::write::FileOptions::<()>::default();
        zip.start_file("dir1/dir2/nested.txt", options)?;
        zip.write_all(b"nested")?;
        zip.finish()?;

        let extract_dir = temp.path().join("extracted");
        std::fs::create_dir(&extract_dir)?;

        extract_zip(&zip_path, &extract_dir)?;

        let nested_file = extract_dir.join("dir1/dir2/nested.txt");
        assert!(nested_file.exists());
        assert_eq!(std::fs::read_to_string(nested_file)?, "nested");

        Ok(())
    }
}
