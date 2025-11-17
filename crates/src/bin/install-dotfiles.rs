use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use std::io;

#[derive(Parser)]
#[command(name = "install-dotfiles")]
#[command(about = "Install dotfiles symlinks and configurations", long_about = None)]
#[command(version)]
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
    let _args = Args::parse();

    if let Some(Commands::Completion { shell }) = _args.command {
        generate(
            shell,
            &mut Args::command(),
            "install-dotfiles",
            &mut io::stdout(),
        );
        return Ok(());
    }

    dotfiles_tools::install::install_dotfiles()
}
