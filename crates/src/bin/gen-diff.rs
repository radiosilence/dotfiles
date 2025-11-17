use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use dotfiles_tools::{banner, system};
use std::io;
use std::process::Command;

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
    if !system::which("convert") {
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
