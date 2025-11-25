//! Strip EXIF metadata from images in parallel
//!
//! Removes GPS, camera serial numbers, and other PII from images.

use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use dotfiles_tools::{audio, banner, parallel};
use img_parts::jpeg::Jpeg;
use img_parts::png::Png;
use img_parts::{Bytes, ImageEXIF};
use std::fs;
use std::io;
use std::path::{Path, PathBuf};

#[derive(Parser)]
#[command(name = "clean-exif")]
#[command(about = "Strip EXIF metadata from images", long_about = None)]
#[command(version)]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,

    /// Directories to search
    #[arg(value_name = "PATHS", default_value = ".")]
    paths: Vec<PathBuf>,

    /// Dry run - show what would be cleaned
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

fn clean_exif(file: &Path) -> Result<()> {
    let data = fs::read(file)?;
    let extension = file
        .extension()
        .and_then(|s| s.to_str())
        .unwrap_or("")
        .to_lowercase();

    let cleaned_data = match extension.as_str() {
        "jpg" | "jpeg" => {
            let mut jpeg = Jpeg::from_bytes(Bytes::from(data))?;
            jpeg.set_exif(None);
            jpeg.encoder().bytes()
        }
        "png" => {
            let mut png = Png::from_bytes(Bytes::from(data))?;
            png.set_exif(None);
            png.encoder().bytes()
        }
        _ => anyhow::bail!("Unsupported format: {}", extension),
    };

    fs::write(file, &cleaned_data)?;
    Ok(())
}

fn main() -> Result<()> {
    let args = Args::parse();

    if let Some(Commands::Completion { shell }) = args.command {
        generate(shell, &mut Args::command(), "clean-exif", &mut io::stdout());
        return Ok(());
    }

    banner::header("CLEAN-EXIF");

    let extensions = ["jpg", "jpeg", "png"];
    let files = parallel::find_files(&args.paths, &extensions);

    if files.is_empty() {
        banner::warn("No image files found");
        return Ok(());
    }

    let cores = num_cpus::get();
    banner::status("Found", &format!("{} images", files.len()));
    banner::status("Cores", &cores.to_string());
    banner::status("Stripping", "all EXIF metadata");
    println!();

    if args.dry_run {
        banner::info("Dry run - files that would be cleaned:");
        for file in &files {
            println!("    {}", file.display());
        }
        return Ok(());
    }

    let results = audio::process_files_parallel(files, |file, _pb| {
        clean_exif(file)?;
        Ok(())
    });

    let success_count = results.iter().filter(|r| r.is_ok()).count();
    let error_count = results.len() - success_count;

    println!();
    if error_count > 0 {
        banner::warn(&format!(
            "Cleaned {} files ({} failed)",
            success_count, error_count
        ));
        for result in results.iter().filter(|r| r.is_err()) {
            if let Err(e) = result {
                banner::err(&format!("{}", e));
            }
        }
    } else {
        banner::ok(&format!("Cleaned {} images", success_count));
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use img_parts::{Bytes, ImageEXIF};
    use std::fs;
    use tempfile::TempDir;

    // Minimal valid 1x1 JPEG (SOI + SOF0 + SOS + EOI)
    const MINIMAL_JPEG: &[u8] = &[
        0xFF, 0xD8, // SOI
        0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x00, 0x00, 0x01, 0x00,
        0x01, 0x00, 0x00, // APP0
        0xFF, 0xDB, 0x00, 0x43, 0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07,
        0x09, 0x09, 0x08, 0x0A, 0x0C, 0x14, 0x0D, 0x0C, 0x0B, 0x0B, 0x0C, 0x19, 0x12, 0x13, 0x0F,
        0x14, 0x1D, 0x1A, 0x1F, 0x1E, 0x1D, 0x1A, 0x1C, 0x1C, 0x20, 0x24, 0x2E, 0x27, 0x20, 0x22,
        0x2C, 0x23, 0x1C, 0x1C, 0x28, 0x37, 0x29, 0x2C, 0x30, 0x31, 0x34, 0x34, 0x34, 0x1F, 0x27,
        0x39, 0x3D, 0x38, 0x32, 0x3C, 0x2E, 0x33, 0x34, 0x32, // DQT
        0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01, 0x00, 0x01, 0x01, 0x01, 0x11, 0x00, // SOF0
        0xFF, 0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00, 0xD2, // SOS
        0xFF, 0xD9, // EOI
    ];

    #[test]
    fn test_clean_exif_jpeg() {
        let temp_dir = TempDir::new().unwrap();
        let test_file = temp_dir.path().join("test.jpg");

        // Create JPEG with EXIF data
        let mut jpeg = Jpeg::from_bytes(Bytes::from(MINIMAL_JPEG.to_vec())).unwrap();
        let exif_data = vec![0x45, 0x78, 0x69, 0x66, 0x00, 0x00];
        jpeg.set_exif(Some(Bytes::from(exif_data)));
        fs::write(&test_file, jpeg.encoder().bytes()).unwrap();

        // Verify EXIF exists
        let data = fs::read(&test_file).unwrap();
        let jpeg_before = Jpeg::from_bytes(Bytes::from(data)).unwrap();
        assert!(
            jpeg_before.exif().is_some(),
            "EXIF should exist before cleaning"
        );

        // Clean it
        clean_exif(&test_file).unwrap();

        // Verify EXIF removed
        let data = fs::read(&test_file).unwrap();
        let jpeg_after = Jpeg::from_bytes(Bytes::from(data)).unwrap();
        assert!(
            jpeg_after.exif().is_none(),
            "EXIF should be removed after cleaning"
        );
    }

    #[test]
    fn test_unsupported_format() {
        let temp_dir = TempDir::new().unwrap();
        let test_file = temp_dir.path().join("test.bmp");
        fs::write(&test_file, b"fake bmp data").unwrap();

        let result = clean_exif(&test_file);
        assert!(result.is_err(), "Should fail on unsupported format");
        assert!(result
            .unwrap_err()
            .to_string()
            .contains("Unsupported format"));
    }
}
