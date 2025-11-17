use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use std::fs;
use std::io;
use std::process::Command;
use tempfile::TempDir;
use dotfiles_tools::banner;

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

    banner::print_glitch_header("PRUNE-GEN", "yellow");
    banner::status("□", "ACTION", "generating test structure", "yellow");

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

    banner::status("□", "PATH", &path_str, "yellow");
    banner::success("TEST STRUCTURE CREATED");

    println!("{}", path_str);

    // Keep temp_dir alive so it doesn't get cleaned up
    let _path = temp_dir.keep();

    Ok(())
}

fn create_large_file(path: &std::path::Path, mb: usize) -> Result<()> {
    Command::new("dd")
        .args([
            "if=/dev/zero",
            &format!("of={}", path.display()),
            "bs=1M",
            &format!("count={}", mb),
        ])
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_create_large_file_command() {
        // Just verify the function is callable and returns Ok for 0 MB
        // (dd with count=0 should be safe and fast)
        let temp = TempDir::new().unwrap();
        let file_path = temp.path().join("test.dat");
        let result = create_large_file(&file_path, 0);
        assert!(result.is_ok());
    }

    #[test]
    fn test_path_with_spaces() {
        let temp = TempDir::new().unwrap();
        let dir_with_spaces = temp.path().join("dir with spaces");
        let result = fs::create_dir_all(&dir_with_spaces);
        assert!(result.is_ok());
        assert!(dir_with_spaces.exists());
    }

    #[test]
    fn test_nested_directory_creation() {
        let temp = TempDir::new().unwrap();
        let nested = temp.path().join("a/b/c/d");
        let result = fs::create_dir_all(&nested);
        assert!(result.is_ok());
        assert!(nested.exists());
    }
}
