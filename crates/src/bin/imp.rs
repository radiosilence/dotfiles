//! Import music from URLs
//!
//! Downloads music archives, extracts them, and imports to beets library

use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use dotfiles_tools::{banner, parallel};
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

    banner::print_banner(
        "MUSIC IMPORTER",
        "download + extract + beets import",
        "green",
    );

    // Create temp dir
    let temp_dir = TempDir::new()?;
    let dest = temp_dir.path();

    banner::status("□", "DOWNLOAD DIR", &dest.display().to_string(), "green");
    banner::status("□", "URLS", &args.urls.len().to_string(), "green");
    banner::divider("green");
    println!();

    // Download in parallel
    banner::loading("Downloading archives in parallel...");

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
        anyhow::bail!("No files downloaded successfully");
    }

    banner::loading(&format!("Downloaded {} files", successful_downloads.len()));
    println!();

    // Extract archives in parallel
    banner::loading("Extracting archives...");

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
    banner::loading(&format!("Extracted {} archives", extract_success));
    println!();

    // Show extracted files
    println!();
    banner::status("□", "EXTRACTED FILES", "", "green");
    let _ = Command::new("lsd")
        .args(["--tree", dest.to_str().unwrap()])
        .status()
        .or_else(|_| Command::new("tree").arg(dest.to_str().unwrap()).status());

    println!();
    banner::loading("Importing to beets...");

    // Import to beets with stdin exposed for user input
    let status = Command::new("beet")
        .args(["import", dest.to_str().unwrap()])
        .stdin(Stdio::inherit())
        .status()?;

    if !status.success() {
        anyhow::bail!("Beets import failed");
    }

    banner::success("IMPORT COMPLETE");

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

    let pb = parallel::create_progress_bar(response.content_length().unwrap_or(0));
    pb.set_message(file_name.clone());

    let mut file = File::create(&dest_path)?;
    let mut downloaded = 0u64;

    loop {
        let mut buffer = [0; 8192];
        let n = response.read(&mut buffer)?;
        if n == 0 {
            break;
        }
        file.write_all(&buffer[..n])?;
        downloaded += n as u64;
        pb.set_position(downloaded);
    }

    pb.finish_and_clear();

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
    fn test_zip_extension() {
        let path = std::path::Path::new("archive.zip");
        assert_eq!(path.extension().unwrap(), "zip");
    }

    #[test]
    fn test_command_construction() {
        let _aria2c = Command::new("aria2c");
        let _unzip = Command::new("unzip");
        let _beet = Command::new("beet");
    }

    #[test]
    fn test_url_vec() {
        let urls = [
            "https://example.com/file1.zip".to_string(),
            "https://example.com/file2.zip".to_string(),
        ];
        assert_eq!(urls.len(), 2);
    }
}
