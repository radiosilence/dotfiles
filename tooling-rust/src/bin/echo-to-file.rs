use anyhow::Result;
use clap::{Parser, Subcommand};
use dotfiles_tools::completions;
use std::fs;

#[derive(Parser)]
#[command(name = "echo-to-file")]
#[command(about = "Write to temp file", long_about = None)]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,
    /// Text to write
    #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
    text: Vec<String>,
}

#[derive(Subcommand)]
enum Commands {
    /// Generate shell completions
    Completions {
        #[arg(value_enum)]
        shell: completions::CompletionShell,
    },
}

fn main() -> Result<()> {
    let args = Args::parse();

    if let Some(Commands::Completions { shell }) = args.command {
        completions::generate_completions::<Args>(shell);
        return Ok(());
    }

    let content = args.text.join(" ");
    fs::write("/tmp/echo-out", content)?;
    Ok(())
}
