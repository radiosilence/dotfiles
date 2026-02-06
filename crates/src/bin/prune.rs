//! Find and delete small directories
//!
//! Scans directories for folders below a size threshold and interactively
//! prompts for deletion. Useful for cleaning up failed downloads, empty dirs, etc.

use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use dialoguer::Confirm;
use std::io;
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

#[derive(Parser)]
#[command(name = "prune")]
#[command(about = "Find and delete small directories", long_about = None)]
#[command(version)]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,

    /// Directories to search
    #[arg(value_name = "PATHS", default_value = ".")]
    paths: Vec<PathBuf>,

    /// Minimum size in KB (directories below this are candidates)
    #[arg(short = 's', long, default_value = "3072", env = "MIN_SIZE")]
    min_size: u64,

    /// Delete without confirmation
    #[arg(short = 'y', long)]
    yes: bool,
}

#[derive(Subcommand)]
enum Commands {
    /// Generate shell completions
    Completion {
        #[arg(value_enum)]
        shell: Shell,
    },
}

fn get_dir_size(path: &Path) -> Result<u64> {
    let mut total = 0;
    for entry in WalkDir::new(path).into_iter().filter_map(|e| e.ok()) {
        if entry.file_type().is_file() {
            total += entry.metadata()?.len();
        }
    }
    Ok(total)
}

fn format_size(bytes: u64) -> String {
    const KB: u64 = 1024;
    const MB: u64 = KB * 1024;
    const GB: u64 = MB * 1024;

    if bytes >= GB {
        format!("{:.2} GB", bytes as f64 / GB as f64)
    } else if bytes >= MB {
        format!("{:.2} MB", bytes as f64 / MB as f64)
    } else if bytes >= KB {
        format!("{:.2} KB", bytes as f64 / KB as f64)
    } else {
        format!("{} B", bytes)
    }
}

fn main() -> Result<()> {
    let args = Args::parse();

    if let Some(Commands::Completion { shell }) = args.command {
        generate(shell, &mut Args::command(), "prune", &mut io::stdout());
        return Ok(());
    }

    println!("\n/// {}\n", "PRUNE".bold());

    let min_size_bytes = args.min_size * 1024;
    println!(
        "  {} threshold: {}",
        "→".bright_black(),
        format_size(min_size_bytes)
    );

    let mut candidates = Vec::new();

    for path in &args.paths {
        for entry in WalkDir::new(path)
            .min_depth(1)
            .into_iter()
            .filter_entry(|e| {
                // Skip .git, .stfolder
                let name = e.file_name().to_string_lossy();
                !name.starts_with('.') || name == "."
            })
            .filter_map(|e| e.ok())
        {
            if entry.file_type().is_dir() {
                let size = get_dir_size(entry.path())?;
                if size < min_size_bytes {
                    candidates.push((entry.path().to_path_buf(), size));
                }
            }
        }
    }

    if candidates.is_empty() {
        println!(
            "  {} No directories found below {}",
            "✓".green(),
            format_size(min_size_bytes)
        );
        return Ok(());
    }

    // Sort by size ascending
    candidates.sort_by_key(|(_, size)| *size);

    println!(
        "  {} Found {} candidates",
        "·".bright_black(),
        candidates.len()
    );
    println!();

    // Display candidates in table
    println!("  {:<50} {:>12}", "PATH", "SIZE");
    println!("  {}", "─".repeat(64));

    for (path, size) in &candidates {
        let display_path = path.display().to_string();
        let char_count = display_path.chars().count();
        let display_path = if char_count > 48 {
            let suffix: String = display_path.chars().skip(char_count - 45).collect();
            format!("...{}", suffix)
        } else {
            display_path
        };

        println!("  {:<50} {:>12}", display_path, format_size(*size));
    }

    println!();
    println!(
        "  {} total: {}",
        "→".bright_black(),
        format_size(candidates.iter().map(|(_, s)| s).sum())
    );
    println!();

    let confirmed = if args.yes {
        true
    } else {
        Confirm::new()
            .with_prompt("Delete these directories?")
            .default(false)
            .interact()?
    };

    if !confirmed {
        println!("  {} Operation cancelled", "!".yellow());
        return Ok(());
    }

    println!();
    let mut deleted = 0;
    for (path, _) in &candidates {
        match std::fs::remove_dir_all(path) {
            Ok(_) => {
                println!("  × {}", path.display());
                deleted += 1;
            }
            Err(e) => {
                eprintln!("  ! {}: {}", path.display(), e);
            }
        }
    }

    println!();
    println!("  {} Deleted {} directories", "✓".green(), deleted);

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use tempfile::TempDir;

    #[test]
    fn test_format_size_bytes() {
        assert_eq!(format_size(0), "0 B");
        assert_eq!(format_size(512), "512 B");
        assert_eq!(format_size(1023), "1023 B");
    }

    #[test]
    fn test_format_size_kb() {
        assert_eq!(format_size(1024), "1.00 KB");
        assert_eq!(format_size(2048), "2.00 KB");
        assert_eq!(format_size(1536), "1.50 KB");
    }

    #[test]
    fn test_format_size_mb() {
        assert_eq!(format_size(1024 * 1024), "1.00 MB");
        assert_eq!(format_size(2 * 1024 * 1024), "2.00 MB");
        assert_eq!(format_size(1536 * 1024), "1.50 MB");
    }

    #[test]
    fn test_format_size_gb() {
        assert_eq!(format_size(1024 * 1024 * 1024), "1.00 GB");
        assert_eq!(format_size(2 * 1024 * 1024 * 1024), "2.00 GB");
        assert_eq!(format_size(1536 * 1024 * 1024), "1.50 GB");
    }

    #[test]
    fn test_get_dir_size_empty() {
        let temp_dir = TempDir::new().unwrap();
        let size = get_dir_size(temp_dir.path()).unwrap();
        assert_eq!(size, 0);
    }

    #[test]
    fn test_get_dir_size_with_file() {
        let temp_dir = TempDir::new().unwrap();
        let file_path = temp_dir.path().join("test.txt");
        fs::write(&file_path, "hello world").unwrap();

        let size = get_dir_size(temp_dir.path()).unwrap();
        assert_eq!(size, 11); // "hello world" is 11 bytes
    }

    #[test]
    fn test_get_dir_size_multiple_files() {
        let temp_dir = TempDir::new().unwrap();
        fs::write(temp_dir.path().join("file1.txt"), "12345").unwrap();
        fs::write(temp_dir.path().join("file2.txt"), "67890").unwrap();

        let size = get_dir_size(temp_dir.path()).unwrap();
        assert_eq!(size, 10); // 5 + 5 bytes
    }

    #[test]
    fn test_get_dir_size_nested() {
        let temp_dir = TempDir::new().unwrap();
        let nested = temp_dir.path().join("nested");
        fs::create_dir(&nested).unwrap();
        fs::write(temp_dir.path().join("root.txt"), "abc").unwrap();
        fs::write(nested.join("nested.txt"), "def").unwrap();

        let size = get_dir_size(temp_dir.path()).unwrap();
        assert_eq!(size, 6); // 3 + 3 bytes
    }
}
