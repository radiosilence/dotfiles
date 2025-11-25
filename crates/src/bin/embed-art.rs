use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use rayon::prelude::*;
use std::io;
use std::path::{Path, PathBuf};
use std::process::Command;
use walkdir::WalkDir;
use which::which;

#[derive(Parser)]
#[command(about = "Embed artwork into FLAC files")]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,

    /// Directories to search (defaults to current directory)
    #[arg(default_value = ".")]
    paths: Vec<String>,
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
        generate(shell, &mut Args::command(), "embed-art", &mut io::stdout());
        return Ok(());
    }

    println!("\n/// {}\n", "EMBED-ART".bold());

    // Check for required tools
    if which("metaflac").is_err() {
        anyhow::bail!("metaflac not found (brew install flac)");
    }
    if which("clean-exif").is_err() {
        anyhow::bail!("clean-exif not found");
    }

    println!("  {} paths: {}", "→".bright_black(), args.paths.join(", "));
    println!("  {} cores: {}", "→".bright_black(), num_cpus::get());

    // Clean EXIF data from images first
    println!("  {} cleaning exif data from images", "·".bright_black());
    for path in &args.paths {
        Command::new("clean-exif")
            .arg(path)
            .stdout(std::process::Stdio::null())
            .status()?;
    }

    // Find all FLAC files
    let flac_files: Vec<PathBuf> = args
        .paths
        .iter()
        .flat_map(WalkDir::new)
        .filter_map(|e| e.ok())
        .filter(|e| {
            e.path()
                .extension()
                .map(|ext| ext.eq_ignore_ascii_case("flac"))
                .unwrap_or(false)
        })
        .map(|e| e.path().to_path_buf())
        .collect();

    println!("  {} flac files: {}", "→".bright_black(), flac_files.len());

    // Process in parallel
    let results: Vec<_> = flac_files
        .par_iter()
        .map(|flac_file| embed_art_to_flac(flac_file))
        .collect();

    let success = results.iter().filter(|r| r.is_ok()).count();
    let failed = results.len() - success;

    println!();
    println!("  {} embedded: {}", "→".bright_black(), success);
    if failed > 0 {
        println!("  {} failed: {}", "→".bright_black(), failed);
    }

    Ok(())
}

fn embed_art_to_flac(flac_file: &Path) -> Result<()> {
    let dir = flac_file.parent().unwrap();

    // Find artwork files
    let front_cover = find_image(
        dir,
        &[
            "cover.jpg",
            "folder.jpg",
            "album.jpg",
            "front.jpg",
            "cover.png",
            "folder.png",
            "album.png",
            "front.png",
        ],
    );
    let disc_art = find_image(dir, &["cd.jpg", "disc.jpg", "cd.png", "disc.png"]);
    let back_cover = find_image(
        dir,
        &["back.jpg", "backcover.jpg", "back.png", "backcover.png"],
    );
    let artist_art = find_image(dir, &["artist.jpg", "band.jpg", "artist.png", "band.png"]);

    if front_cover.is_none() && disc_art.is_none() && back_cover.is_none() && artist_art.is_none() {
        println!(
            "  {} no artwork found: {}",
            "!".yellow(),
            flac_file.file_name().unwrap().to_string_lossy()
        );
        return Ok(());
    }

    // Create temp copy
    let temp_file = flac_file.with_extension("flac.tmp");
    std::fs::copy(flac_file, &temp_file)?;

    let mut success = true;

    // Embed front cover (type 3)
    if let Some(img) = front_cover {
        if !embed_picture(&temp_file, 3, &img) {
            success = false;
        }
    }

    // Embed disc art (type 6)
    if let Some(img) = disc_art {
        if !embed_picture(&temp_file, 6, &img) {
            success = false;
        }
    }

    // Embed back cover (type 4)
    if let Some(img) = back_cover {
        if !embed_picture(&temp_file, 4, &img) {
            success = false;
        }
    }

    // Embed artist photo (type 8)
    if let Some(img) = artist_art {
        if !embed_picture(&temp_file, 8, &img) {
            success = false;
        }
    }

    if success {
        std::fs::rename(&temp_file, flac_file)?;
        println!(
            "  {} {}",
            "✓".green(),
            flac_file.file_name().unwrap().to_string_lossy()
        );
    } else {
        std::fs::remove_file(&temp_file)?;
        println!(
            "  {} {}",
            "✗".red(),
            flac_file.file_name().unwrap().to_string_lossy()
        );
    }

    Ok(())
}

fn find_image(dir: &Path, names: &[&str]) -> Option<PathBuf> {
    for name in names {
        let path = dir.join(name);
        if path.exists() {
            return Some(path);
        }
    }
    None
}

fn embed_picture(flac_file: &Path, picture_type: u8, image: &Path) -> bool {
    Command::new("metaflac")
        .arg(format!(
            "--import-picture-from={}||||{}",
            picture_type,
            image.display()
        ))
        .arg(flac_file)
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    #[test]
    fn test_find_image_priority() {
        let temp_dir = TempDir::new().unwrap();
        let cover_path = temp_dir.path().join("cover.jpg");
        let folder_path = temp_dir.path().join("folder.jpg");
        fs::write(&cover_path, b"fake").unwrap();
        fs::write(&folder_path, b"fake").unwrap();

        // Should return first match in priority order
        let result = find_image(temp_dir.path(), &["cover.jpg", "folder.jpg"]);
        assert_eq!(result.unwrap(), cover_path);
    }

    #[test]
    fn test_find_image_fallback() {
        let temp_dir = TempDir::new().unwrap();
        let folder_path = temp_dir.path().join("folder.jpg");
        fs::write(&folder_path, b"fake").unwrap();

        // Should find second option when first doesn't exist
        let result = find_image(temp_dir.path(), &["cover.jpg", "folder.jpg"]);
        assert_eq!(result.unwrap(), folder_path);
    }

    #[test]
    fn test_find_image_none() {
        let temp_dir = TempDir::new().unwrap();
        let result = find_image(temp_dir.path(), &["cover.jpg", "folder.jpg"]);
        assert!(result.is_none());
    }

    #[test]
    fn test_find_image_multiple_extensions() {
        let temp_dir = TempDir::new().unwrap();
        let jpg_path = temp_dir.path().join("cover.jpg");
        let png_path = temp_dir.path().join("folder.png");
        fs::write(&jpg_path, b"fake").unwrap();
        fs::write(&png_path, b"fake").unwrap();

        // Should find jpg when both exist but jpg is first in list
        let result = find_image(temp_dir.path(), &["cover.jpg", "folder.png"]);
        assert_eq!(result.unwrap(), jpg_path);
    }

    #[test]
    fn test_find_image_extension_matters() {
        let temp_dir = TempDir::new().unwrap();
        let png_path = temp_dir.path().join("cover.png");
        fs::write(&png_path, b"fake").unwrap();

        // Should not match jpg when png exists
        let result = find_image(temp_dir.path(), &["cover.jpg"]);
        assert!(result.is_none());

        // Should match when explicitly looking for png
        let result = find_image(temp_dir.path(), &["cover.png"]);
        assert_eq!(result.unwrap(), png_path);
    }

    #[test]
    fn test_find_image_empty_list() {
        let temp_dir = TempDir::new().unwrap();
        let result = find_image(temp_dir.path(), &[]);
        assert!(result.is_none());
    }
}
