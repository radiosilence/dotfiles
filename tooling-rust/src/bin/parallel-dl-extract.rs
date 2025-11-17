use anyhow::Result;
use clap::Parser;
use std::collections::hash_map::DefaultHasher;
use std::fs;
use std::hash::{Hash, Hasher};
use std::io::Write;
use std::process::Command;
use tempfile::TempDir;

#[derive(Parser)]
#[command(about = "Parallel download and extract URLs using aria2c")]
struct Args {
    /// URLs to download
    urls: Vec<String>,
}

fn main() -> Result<()> {
    let args = Args::parse();

    if args.urls.is_empty() {
        anyhow::bail!("No URLs provided");
    }

    banner::print_banner(
        "PARALLEL DL+EXTRACT",
        "aria2c parallel download + unzip",
        "cyan",
    );

    let temp_dir = TempDir::new()?;
    let dst = temp_dir.path();

    banner::status("□", "TEMP DIR", &dst.to_string_lossy(), "cyan");
    banner::status("□", "URLS", &args.urls.len().to_string(), "cyan");
    banner::divider("cyan");

    // Create aria2c input file
    let urls_file = dst.join("urls.txt");
    let mut file = fs::File::create(&urls_file)?;

    for url in &args.urls {
        let mut hasher = DefaultHasher::new();
        url.hash(&mut hasher);
        let dir = format!("{:x}", hasher.finish());
        writeln!(file, "{}", url)?;
        writeln!(file, "  dir={}", dir)?;
        writeln!(file, "  out=dl.zip")?;

        eprintln!("[dl] {} to {}", url, dir);
    }
    file.flush()?;

    // Download with aria2c
    banner::status("□", "DOWNLOADING", "aria2c -j 8 -x 8", "cyan");
    let status = Command::new("aria2c")
        .args(["-i", "urls.txt", "-j", "8", "-x", "8", "-d"])
        .arg(dst)
        .current_dir(dst)
        .status()?;

    if !status.success() {
        anyhow::bail!("aria2c download failed");
    }

    // Extract all zips
    banner::status("□", "EXTRACTING", "unzipping archives", "cyan");
    let zips: Vec<_> = walkdir::WalkDir::new(dst)
        .into_iter()
        .filter_map(|e| e.ok())
        .filter(|e| {
            e.path()
                .extension()
                .map(|ext| ext.eq_ignore_ascii_case("zip"))
                .unwrap_or(false)
        })
        .collect();

    for entry in zips {
        let zip_path = entry.path();
        let parent = zip_path.parent().unwrap();

        eprintln!("[extract] {}", zip_path.display());

        Command::new("unzip")
            .arg("-q")
            .arg(zip_path)
            .arg("-d")
            .arg(parent)
            .status()?;

        fs::remove_file(zip_path)?;
    }

    banner::divider("cyan");
    banner::success("DOWNLOAD & EXTRACT COMPLETE");

    println!("{}", dst.display());

    // Keep temp dir alive
    let _path = temp_dir.keep();

    Ok(())
}

mod banner {
    use colored::Colorize;

    pub fn print_banner(title: &str, subtitle: &str, color: &str) {
        let color_fn = match color {
            "cyan" => |s: &str| s.cyan().to_string(),
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
            "cyan" => |s: &str| s.cyan().to_string(),
            _ => |s: &str| s.to_string(),
        };
        println!("   {} {} {}", color_fn(icon), label.bold(), value);
    }

    pub fn success(msg: &str) {
        println!("   {} {}\n", "✓".green().bold(), msg.green().bold());
    }

    pub fn divider(color: &str) {
        let color_fn = match color {
            "cyan" => |s: &str| s.cyan().to_string(),
            _ => |s: &str| s.to_string(),
        };
        println!(
            "{}",
            color_fn("   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        );
    }
}
