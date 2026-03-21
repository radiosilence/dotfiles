use anyhow::Result;
use colored::Colorize;

fn main() -> Result<()> {
    println!(
        "\n  {} {}\n",
        "⟢".magenta().bold(),
        "zsh completions".bold()
    );
    println!("  {} generating: completions (parallel)", "→".cyan());

    dotfiles_tools::regen_completions::regenerate_completions()?;

    println!("  {} completions regenerated", "󰄬".green());
    println!("  {} restart shell: exec zsh", "→".cyan());

    Ok(())
}
