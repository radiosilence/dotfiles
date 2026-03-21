use anyhow::Result;
use colored::Colorize;

fn main() -> Result<()> {
    println!(
        "\n  {} {}\n",
        "⟢".magenta().bold(),
        "zsh completions".bold()
    );

    let results = dotfiles_tools::regen_completions::regenerate_completions()?;

    for r in &results {
        if r.ok {
            let suffix = if r.detail.is_empty() {
                String::new()
            } else {
                format!(" ({})", r.detail)
            };
            println!("  {} {}{}", "󰄬".green(), r.name, suffix);
        } else {
            println!("  {} {}: {}", "󰅖".red(), r.name, r.detail);
        }
    }

    let ok = results.iter().filter(|r| r.ok).count();
    let failed = results.iter().filter(|r| !r.ok).count();

    println!();
    if failed > 0 {
        println!("  {} {ok} generated, {failed} failed", "".yellow());
    } else {
        println!("  {} {ok} completions generated", "󰄬".green());
    }
    println!("  {} restart shell: exec zsh", "→".cyan());

    Ok(())
}
