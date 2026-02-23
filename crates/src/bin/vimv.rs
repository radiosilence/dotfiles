use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use std::fs;
use std::io::{self, Write};
use std::process::Command;
use tempfile::NamedTempFile;

#[derive(Parser)]
#[command(name = "vimv")]
#[command(about = "Batch rename files using your $EDITOR")]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,

    /// Files to rename (defaults to all files in current directory)
    files: Vec<String>,
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
        generate(shell, &mut Args::command(), "vimv", &mut io::stdout());
        return Ok(());
    }

    println!("\n/// {}\n", "VIMV".bold());

    // Get list of files
    let files: Vec<String> = if args.files.is_empty() {
        fs::read_dir(".")?
            .filter_map(|e| e.ok())
            .filter(|e| e.file_type().map(|t| t.is_file()).unwrap_or(false))
            .map(|e| e.file_name().to_string_lossy().to_string())
            .collect()
    } else {
        args.files
    };

    if files.is_empty() {
        println!("  {} No files found", "!".yellow());
        return Ok(());
    }

    println!("  {} files: {}", "→".bright_black(), files.len());

    // Create temp file with filenames
    let mut temp_file = NamedTempFile::new()?;
    for file in &files {
        writeln!(temp_file, "{}", file)?;
    }
    temp_file.flush()?;

    // Open in editor
    let editor = std::env::var("EDITOR").unwrap_or_else(|_| "vi".to_string());
    let status = Command::new(&editor).arg(temp_file.path()).status()?;

    if !status.success() {
        anyhow::bail!("editor exited with error");
    }

    // Read edited filenames
    let edited_content = fs::read_to_string(temp_file.path())?;
    let new_files: Vec<&str> = edited_content.lines().collect();

    if files.len() != new_files.len() {
        anyhow::bail!(
            "Number of files changed ({} -> {}). Did you delete a line by accident?",
            files.len(),
            new_files.len()
        );
    }

    // Perform renames
    let mut count = 0;
    for (old, new) in files.iter().zip(new_files.iter()) {
        if old != new {
            // Create parent directory if needed
            if let Some(parent) = std::path::Path::new(new).parent() {
                fs::create_dir_all(parent)?;
            }

            // Check if file is tracked by git
            let is_git_tracked = Command::new("git")
                .args(["ls-files", "--error-unmatch", old])
                .stdout(std::process::Stdio::null())
                .stderr(std::process::Stdio::null())
                .status()
                .map(|s| s.success())
                .unwrap_or(false);

            if is_git_tracked {
                Command::new("git").args(["mv", "--", old, new]).status()?;
                println!("  {} git mv {} → {}", "·".bright_black(), old, new);
            } else {
                fs::rename(old, new)?;
                println!("  {} mv {} → {}", "·".bright_black(), old, new);
            }
            count += 1;
        }
    }

    println!("  {} {} files renamed", "✓".green(), count);

    Ok(())
}
