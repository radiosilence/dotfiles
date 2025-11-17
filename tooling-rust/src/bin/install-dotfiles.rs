use anyhow::Result;
use clap::Parser;
use dotfiles_tools::completions;

#[derive(Parser)]
#[command(name = "install-dotfiles")]
#[command(about = "Install dotfiles symlinks and configurations", long_about = None)]
#[command(version)]
struct Args {}

fn main() -> Result<()> {
    if completions::handle_completion_flag::<Args>() {
        return Ok(());
    }

    let _args = Args::parse();

    dotfiles_tools::install::install_dotfiles()
}
