use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use std::io;
use std::process::Command;
use dotfiles_tools::banner;

#[derive(Parser)]
#[command(about = "Create a visual diff of two images using ImageMagick")]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,

    /// First image
    image1: String,
    /// Second image
    image2: String,
    /// Output file
    output: String,
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
        generate(shell, &mut Args::command(), "gen-diff", &mut io::stdout());
        return Ok(());
    }

    banner::print_banner("GEN-DIFF", "visual image diff generator", "red");

    // Check if ImageMagick is installed
    if !which("convert") {
        anyhow::bail!("ImageMagick not installed (brew install imagemagick)");
    }

    // Check if input files exist
    if !std::path::Path::new(&args.image1).exists() {
        anyhow::bail!("Image 1 not found: {}", args.image1);
    }
    if !std::path::Path::new(&args.image2).exists() {
        anyhow::bail!("Image 2 not found: {}", args.image2);
    }

    banner::status("□", "IMAGE 1", &args.image1, "red");
    banner::status("□", "IMAGE 2", &args.image2, "red");
    banner::status("□", "OUTPUT", &args.output, "red");
    banner::divider("red");

    // Create visual diff
    let status = Command::new("convert")
        .arg(&args.image1)
        .arg(&args.image2)
        .arg("-resize")
        .arg("1024x1024>")
        .arg("-gravity")
        .arg("center")
        .arg("(")
        .arg("-clone")
        .arg("0-1")
        .arg("-compose")
        .arg("difference")
        .arg("-composite")
        .arg("-threshold")
        .arg("0")
        .arg(")")
        .arg("-delete")
        .arg("0-1")
        .arg("-negate")
        .arg(&args.output)
        .status()?;

    if !status.success() {
        anyhow::bail!("ImageMagick convert failed");
    }

    banner::success("VISUAL DIFF CREATED");

    Ok(())
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_which_common_command() {
        // Test with a command that should exist on any Unix system
        let result = which("sh");
        assert!(result);
    }

    #[test]
    fn test_which_nonexistent_command() {
        let result = which("this-command-definitely-does-not-exist-12345");
        assert!(!result);
    }

    #[test]
    fn test_file_path_validation() {
        // Test that Path::new works with test inputs
        let path1 = std::path::Path::new("image1.jpg");
        let path2 = std::path::Path::new("image2.jpg");
        let output = std::path::Path::new("output.jpg");

        assert_eq!(path1.to_str().unwrap(), "image1.jpg");
        assert_eq!(path2.to_str().unwrap(), "image2.jpg");
        assert_eq!(output.to_str().unwrap(), "output.jpg");
    }
}
