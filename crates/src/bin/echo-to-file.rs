use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use std::fs;
use std::io;

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
    Completion {
        #[arg(value_enum)]
        shell: Shell,
    },
}

fn main() -> Result<()> {
    let args = Args::parse();

    if let Some(Commands::Completion { shell }) = args.command {
        generate(
            shell,
            &mut Args::command(),
            "echo-to-file",
            &mut io::stdout(),
        );
        return Ok(());
    }

    let content = args.text.join(" ");
    fs::write("/tmp/echo-out", content)?;
    Ok(())
}
