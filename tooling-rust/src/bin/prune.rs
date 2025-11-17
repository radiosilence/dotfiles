//! Find and delete small directories
//!
//! Scans directories for folders below a size threshold and interactively
//! prompts for deletion. Useful for cleaning up failed downloads, empty dirs, etc.

use anyhow::Result;
use clap::Parser;
use dotfiles_tools::completions;
use colored::Colorize;
use dialoguer::Confirm;
use std::path::PathBuf;
use walkdir::WalkDir;

#[derive(Parser)]
#[command(name = "prune")]
#[command(about = "Find and delete small directories", long_about = None)]
#[command(version)]
struct Args {
    /// Directories to search
    #[arg(value_name = "PATHS", default_value = ".")]
    paths: Vec<PathBuf>,

    /// Minimum size in KB (directories below this are candidates)
    #[arg(short = 's', long, default_value = "3096", env = "MIN_SIZE")]
    min_size: u64,

    /// Delete without confirmation
    #[arg(short = 'y', long)]
    yes: bool,
}

fn get_dir_size(path: &PathBuf) -> Result<u64> {
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
    if completions::handle_completion_flag::<Args>() {
        return Ok(());
    }

    let args = Args::parse();

    // ASCII art banner with 90s cracker aesthetic
    println!(
        "{}",
        "╔════════════════════════════════════════════════╗".bright_cyan()
    );
    println!(
        "{}",
        "║              P R U N E   v1.0                  ║".bright_cyan()
    );
    println!(
        "{}",
        "║        [directory cleanup utility]             ║".bright_cyan()
    );
    println!(
        "{}",
        "╚════════════════════════════════════════════════╝".bright_cyan()
    );
    println!();

    let min_size_bytes = args.min_size * 1024;

    println!(
        "{} Scanning for directories < {}...",
        "→".bright_cyan().bold(),
        format_size(min_size_bytes).yellow()
    );
    println!();

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
                let size = get_dir_size(&entry.path().to_path_buf())?;
                if size < min_size_bytes {
                    candidates.push((entry.path().to_path_buf(), size));
                }
            }
        }
    }

    if candidates.is_empty() {
        println!(
            "{} No directories found below {}",
            "✓".green().bold(),
            format_size(min_size_bytes).yellow()
        );
        return Ok(());
    }

    // Sort by size ascending
    candidates.sort_by_key(|(_, size)| *size);

    println!(
        "{} Found {} candidates:",
        "!".yellow().bold(),
        candidates.len().to_string().bright_white().bold()
    );
    println!();

    // Display candidates in fancy table
    println!(
        "  {:<50} {:>12}",
        "PATH".bright_black(),
        "SIZE".bright_black()
    );
    println!("  {}", "─".repeat(64).bright_black());

    for (path, size) in &candidates {
        let display_path = path.display().to_string();
        let display_path = if display_path.len() > 48 {
            format!("...{}", &display_path[display_path.len() - 45..])
        } else {
            display_path
        };

        println!(
            "  {:<50} {:>12}",
            display_path.white(),
            format_size(*size).red().bold()
        );
    }

    println!();
    println!(
        "{} Total to delete: {}",
        "→".bright_cyan().bold(),
        format_size(candidates.iter().map(|(_, s)| s).sum())
            .red()
            .bold()
    );
    println!();

    let confirmed = if args.yes {
        true
    } else {
        Confirm::new()
            .with_prompt(format!("{} Delete these directories?", "?".yellow().bold()))
            .default(false)
            .interact()?
    };

    if !confirmed {
        println!("{} Operation cancelled", "×".red().bold());
        return Ok(());
    }

    println!();
    println!("{} Deleting...", "→".bright_cyan().bold());

    let mut deleted = 0;
    for (path, _) in &candidates {
        match std::fs::remove_dir_all(path) {
            Ok(_) => {
                println!(
                    "  {} {}",
                    "×".red().bold(),
                    path.display().to_string().bright_black()
                );
                deleted += 1;
            }
            Err(e) => {
                eprintln!(
                    "  {} {}: {}",
                    "!".yellow().bold(),
                    path.display().to_string().yellow(),
                    e.to_string().red()
                );
            }
        }
    }

    println!();
    println!(
        "{} Deleted {} directories",
        "✓".green().bold(),
        deleted.to_string().green().bold()
    );

    Ok(())
}
