use anyhow::Result;
use clap::{Parser, ValueEnum};
use dotfiles_tools::completions;
use dotfiles_tools::setup::{setup, Platform};

#[derive(Debug, Clone, Copy, ValueEnum)]
enum PlatformArg {
    Macos,
    Linux,
}

impl From<PlatformArg> for Platform {
    fn from(arg: PlatformArg) -> Self {
        match arg {
            PlatformArg::Macos => Platform::MacOS,
            PlatformArg::Linux => Platform::Linux,
        }
    }
}

#[derive(Parser)]
#[command(name = "setup")]
#[command(about = "Bootstrap a fresh system with dotfiles and tools", long_about = None)]
#[command(version)]
struct Args {
    /// Target platform (defaults to current platform)
    #[arg(long, value_enum)]
    platform: Option<PlatformArg>,
}

fn main() -> Result<()> {
    if completions::handle_completion_flag::<Args>() {
        return Ok(());
    }

    let args = Args::parse();

    let platform = if let Some(p) = args.platform {
        p.into()
    } else {
        Platform::detect().ok_or_else(|| anyhow::anyhow!("Unsupported platform"))?
    };

    setup(platform)
}
