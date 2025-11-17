use anyhow::Result;
use clap::Parser;
use dotfiles_tools::completions;
use colored::Colorize;
use std::fs;
use std::io::Write;
use std::process::Command;
use tempfile::NamedTempFile;

#[derive(Parser)]
#[command(about = "Batch rename files using your $EDITOR")]
struct Args {
    /// Files to rename (defaults to all files in current directory)
    files: Vec<String>,
}

fn main() -> Result<()> {
    if completions::handle_completion_flag::<Args>() {
        return Ok(());
    }

    let args = Args::parse();

    banner::print_banner("VIMV", "batch rename with editor", "yellow");

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
        banner::warning("NO FILES FOUND");
        return Ok(());
    }

    banner::status("□", "FILES", &files.len().to_string(), "yellow");

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

    banner::divider("yellow");

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
                println!("   {} {} → {}", "git".cyan(), old.dimmed(), new);
            } else {
                fs::rename(old, new)?;
                println!("   {} {} → {}", "mv".green(), old.dimmed(), new);
            }
            count += 1;
        }
    }

    banner::divider("yellow");
    banner::success(&format!("{} FILES RENAMED", count));

    Ok(())
}

mod banner {
    use colored::Colorize;

    pub fn print_banner(title: &str, subtitle: &str, color: &str) {
        let color_fn = match color {
            "yellow" => |s: &str| s.yellow().to_string(),
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
            "yellow" => |s: &str| s.yellow().to_string(),
            _ => |s: &str| s.to_string(),
        };
        println!("   {} {} {}", color_fn(icon), label.bold(), value);
    }

    pub fn success(msg: &str) {
        println!("   {} {}\n", "✓".green().bold(), msg.green().bold());
    }

    pub fn warning(msg: &str) {
        println!("   {} {}\n", "⚠".yellow().bold(), msg.yellow().bold());
    }

    pub fn divider(color: &str) {
        let color_fn = match color {
            "yellow" => |s: &str| s.yellow().to_string(),
            _ => |s: &str| s.to_string(),
        };
        println!(
            "{}",
            color_fn("   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        );
    }
}
