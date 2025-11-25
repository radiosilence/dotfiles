use anyhow::Result;
use dotfiles_tools::banner;

fn main() -> Result<()> {
    banner::header("ZSH COMPLETIONS");
    banner::status("generating", "completions (parallel)");

    dotfiles_tools::regen_completions::regenerate_completions()?;

    banner::ok("completions regenerated");
    banner::info("restart shell: exec zsh");

    Ok(())
}
