use anyhow::Result;
use colored::Colorize;

fn main() -> Result<()> {
    println!("\n/// {}\n", "ZSH COMPLETIONS".bold());
    println!(
        "  {} generating: completions (parallel)",
        "→".bright_black()
    );

    dotfiles_tools::regen_completions::regenerate_completions()?;

    println!("  {} completions regenerated", "✓".green());
    println!("  {} restart shell: exec zsh", "·".bright_black());

    Ok(())
}
