use anyhow::Result;
use colored::Colorize;
use dotfiles_tools::banner;

fn main() -> Result<()> {
    banner::print_banner(
        "ZSH COMPLETIONS",
        "regenerating system completions",
        "magenta",
    );

    banner::divider("magenta");
    banner::status("□", "GENERATING", "completions (parallel)", "magenta");

    dotfiles_tools::regen_completions::regenerate_completions()?;

    banner::divider("magenta");
    banner::success("COMPLETIONS REGENERATED");
    println!("   {} Restart shell: exec zsh\n", "ℹ".blue());

    Ok(())
}
