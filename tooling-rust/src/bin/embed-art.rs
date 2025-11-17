use anyhow::Result;
use clap::Parser;
use colored::Colorize;
use rayon::prelude::*;
use std::path::{Path, PathBuf};
use std::process::Command;
use walkdir::WalkDir;

#[derive(Parser)]
#[command(about = "Embed artwork into FLAC files")]
struct Args {
    /// Directories to search (defaults to current directory)
    #[arg(default_value = ".")]
    paths: Vec<String>,
}

fn main() -> Result<()> {
    let args = Args::parse();

    banner::print_banner("EMBED-ART", "flac artwork embedder", "magenta");

    // Check for required tools
    if !which("metaflac") {
        anyhow::bail!("metaflac not found (brew install flac)");
    }
    if !which("clean-exif") {
        anyhow::bail!("clean-exif not found");
    }

    let cores = num_cpus::get();
    banner::status("□", "PATHS", &args.paths.join(", "), "magenta");
    banner::status("□", "CORES", &cores.to_string(), "magenta");
    banner::divider("magenta");

    // Clean EXIF data from images first
    banner::status("□", "CLEANING", "exif data from images", "magenta");
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

    banner::status("□", "FLAC FILES", &flac_files.len().to_string(), "magenta");
    banner::divider("magenta");

    // Process in parallel
    let results: Vec<_> = flac_files
        .par_iter()
        .map(|flac_file| embed_art_to_flac(flac_file))
        .collect();

    let success = results.iter().filter(|r| r.is_ok()).count();
    let failed = results.len() - success;

    banner::divider("magenta");
    banner::success(&format!("{} EMBEDDED  {} FAILED", success, failed));

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
            "   {} {}",
            "⚠".yellow(),
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
            "   {} {}",
            "✓".green(),
            flac_file.file_name().unwrap().to_string_lossy()
        );
    } else {
        std::fs::remove_file(&temp_file)?;
        println!(
            "   {} {}",
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

fn which(cmd: &str) -> bool {
    Command::new("which")
        .arg(cmd)
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

mod banner {
    use colored::Colorize;

    pub fn print_banner(title: &str, subtitle: &str, color: &str) {
        let color_fn = match color {
            "magenta" => |s: &str| s.magenta().to_string(),
            _ => |s: &str| s.to_string(),
        };

        println!(
            "\n{}",
            color_fn("   ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄")
        );
        println!(
            "   {} {}\n",
            color_fn(&format!("▸ {}", title)).bold(),
            subtitle.dimmed()
        );
    }

    pub fn status(icon: &str, label: &str, value: &str, color: &str) {
        let color_fn = match color {
            "magenta" => |s: &str| s.magenta().to_string(),
            _ => |s: &str| s.to_string(),
        };
        println!("   {} {} {}", color_fn(icon), label.bold(), value);
    }

    pub fn success(msg: &str) {
        println!("   {} {}\n", "✓".green().bold(), msg.green().bold());
    }

    pub fn divider(color: &str) {
        let color_fn = match color {
            "magenta" => |s: &str| s.magenta().to_string(),
            _ => |s: &str| s.to_string(),
        };
        println!(
            "{}",
            color_fn("   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        );
    }
}
