use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use dotfiles_tools::{banner, system};
use std::io;
use std::process::Command;

#[derive(Parser)]
#[command(about = "Create a visual diff of two images using ImageMagick")]
#[command(args_conflicts_with_subcommands = true)]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,

    /// First image
    image1: Option<String>,
    /// Second image
    image2: Option<String>,
    /// Output file
    output: Option<String>,
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

    banner::header("gen-diff");

    if !system::which("convert") {
        anyhow::bail!("ImageMagick not installed (brew install imagemagick)");
    }

    let image1 = args
        .image1
        .ok_or_else(|| anyhow::anyhow!(Args::command().render_help()))?;
    let image2 = args
        .image2
        .ok_or_else(|| anyhow::anyhow!(Args::command().render_help()))?;
    let output = args
        .output
        .ok_or_else(|| anyhow::anyhow!(Args::command().render_help()))?;

    if !std::path::Path::new(&image1).exists() {
        anyhow::bail!("Image 1 not found: {}", image1);
    }
    if !std::path::Path::new(&image2).exists() {
        anyhow::bail!("Image 2 not found: {}", image2);
    }

    banner::status("image1", &image1);
    banner::status("image2", &image2);
    banner::status("output", &output);

    let status = Command::new("convert")
        .arg(&image1)
        .arg(&image2)
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
        .arg(&output)
        .status()?;

    if !status.success() {
        anyhow::bail!("ImageMagick convert failed");
    }

    banner::ok("visual diff created");

    Ok(())
}
