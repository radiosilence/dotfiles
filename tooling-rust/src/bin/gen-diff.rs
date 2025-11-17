use anyhow::Result;
use clap::Parser;
use std::process::Command;

#[derive(Parser)]
#[command(about = "Create a visual diff of two images using ImageMagick")]
struct Args {
    /// First image
    image1: String,
    /// Second image
    image2: String,
    /// Output file
    output: String,
}

fn main() -> Result<()> {
    let args = Args::parse();

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

mod banner {
    use colored::Colorize;

    pub fn print_banner(title: &str, subtitle: &str, color: &str) {
        let color_fn = match color {
            "red" => |s: &str| s.red().to_string(),
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
            "red" => |s: &str| s.red().to_string(),
            _ => |s: &str| s.to_string(),
        };
        println!("   {} {} {}", color_fn(icon), label.bold(), value);
    }

    pub fn success(msg: &str) {
        println!("\n   {} {}\n", "✓".green().bold(), msg.green().bold());
    }

    pub fn divider(color: &str) {
        let color_fn = match color {
            "red" => |s: &str| s.red().to_string(),
            _ => |s: &str| s.to_string(),
        };
        println!(
            "{}",
            color_fn("   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        );
    }
}
