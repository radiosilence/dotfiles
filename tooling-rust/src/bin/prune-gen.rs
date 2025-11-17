use anyhow::Result;
use colored::Colorize;
use std::fs;
use std::process::Command;
use tempfile::TempDir;

fn main() -> Result<()> {
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
    let _ = temp_dir.into_path();

    Ok(())
}

fn create_large_file(path: &std::path::Path, mb: usize) -> Result<()> {
    Command::new("dd")
        .args([
            "if=/dev/zero",
            &format!("of={}", path.display()),
            &format!("bs=1M"),
            &format!("count={}", mb),
        ])
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()?;
    Ok(())
}

mod banner {
    use colored::Colorize;

    pub fn print_glitch_header(title: &str, color: &str) {
        let color_fn = match color {
            "yellow" => |s: &str| s.yellow().to_string(),
            "cyan" => |s: &str| s.cyan().to_string(),
            "magenta" => |s: &str| s.magenta().to_string(),
            _ => |s: &str| s.to_string(),
        };
        println!("\n{}", color_fn(&format!("   ╔═══ {} ═══╗", title)).bold());
    }

    pub fn status(icon: &str, label: &str, value: &str, color: &str) {
        let color_fn = match color {
            "yellow" => |s: &str| s.yellow().to_string(),
            "cyan" => |s: &str| s.cyan().to_string(),
            "magenta" => |s: &str| s.magenta().to_string(),
            _ => |s: &str| s.to_string(),
        };
        println!("   {} {} {}", color_fn(icon), label.bold(), value);
    }

    pub fn success(msg: &str) {
        println!("   {} {}\n", "✓".green().bold(), msg.green().bold());
    }
}
