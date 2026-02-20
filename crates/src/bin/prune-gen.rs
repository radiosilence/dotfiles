use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use std::fs;
use std::io;
use tempfile::TempDir;

#[derive(Parser)]
#[command(name = "prune-gen")]
#[command(about = "Generate test directory structure", long_about = None)]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,
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
        generate(shell, &mut Args::command(), "prune-gen", &mut io::stdout());
        return Ok(());
    }

    println!("\n/// {}\n", "PRUNE-GEN".bold());
    println!("  {} action: generating test structure", "→".bright_black());

    let temp_dir = TempDir::new()?;
    let test_dir = temp_dir.path();

    // Create nested directories
    fs::create_dir_all(test_dir.join("dir1/subdir1"))?;
    fs::create_dir_all(test_dir.join("largdir1"))?;
    fs::create_dir_all(test_dir.join("largedir2/subdir1"))?;
    fs::create_dir_all(test_dir.join("dir with spaces1/subdir2"))?;
    fs::create_dir_all(test_dir.join("dir1/subdir2 with spaces"))?;
    fs::create_dir_all(test_dir.join("dir2/subdir1/2/3/4"))?;
    fs::create_dir_all(test_dir.join("emptydir"))?;
    fs::create_dir_all(test_dir.join(".stfolder"))?;
    fs::create_dir_all(test_dir.join(".git"))?;

    // Create small files
    fs::write(test_dir.join("dir1/small1.txt"), "Small file 1")?;
    fs::write(test_dir.join("dir1/subdir1/small2.txt"), "Small file 2")?;
    fs::write(test_dir.join("dir2/small3.txt"), "Small file 3")?;

    // Create large files using dd
    create_large_file(&test_dir.join("largdir1/large1.wav"), 210)?;
    create_large_file(&test_dir.join("dir1/small1.jpg"), 1)?;
    create_large_file(&test_dir.join("dir1/subdir1/small2.jpg"), 2)?;
    create_large_file(&test_dir.join("largedir2/subdir1/large2.aiff"), 50)?;

    // Create files with special characters
    fs::File::create(test_dir.join("dir1/file with spaces.txt"))?;
    fs::File::create(test_dir.join("dir1/file_with_underscore.txt"))?;
    fs::File::create(test_dir.join("dir1/file-with-dashes.txt"))?;

    let path_str = test_dir.to_string_lossy().to_string();

    println!("  {} path: {}", "→".bright_black(), path_str);
    println!("  {} test structure created", "✓".green());

    println!("{}", path_str);

    // Keep temp_dir alive so it doesn't get cleaned up
    let _path = temp_dir.keep();

    Ok(())
}

fn create_large_file(path: &std::path::Path, mb: usize) -> Result<()> {
    let f = std::fs::File::create(path)?;
    f.set_len((mb as u64) * 1024 * 1024)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_large_file_zero_bytes() {
        let temp = TempDir::new().unwrap();
        let file_path = temp.path().join("test.dat");
        let result = create_large_file(&file_path, 0);
        assert!(result.is_ok());
        assert!(file_path.exists());
    }

    #[test]
    fn test_directory_with_spaces() {
        let temp = TempDir::new().unwrap();
        let dir_with_spaces = temp.path().join("dir with spaces");
        fs::create_dir_all(&dir_with_spaces).unwrap();
        assert!(dir_with_spaces.exists());
    }
}
