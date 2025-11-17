//! Cyberpunk ASCII art banners and styling

use colored::Colorize;

/// Cyberpunk-styled banner with glitch aesthetic
pub fn print_banner(title: &str, subtitle: &str, color: &str) {
    let colorize = match color {
        "cyan" => |s: &str| s.bright_cyan().bold().to_string(),
        "green" => |s: &str| s.bright_green().bold().to_string(),
        "magenta" => |s: &str| s.bright_magenta().bold().to_string(),
        "yellow" => |s: &str| s.bright_yellow().bold().to_string(),
        "red" => |s: &str| s.bright_red().bold().to_string(),
        _ => |s: &str| s.bright_white().bold().to_string(),
    };

    println!();
    println!(
        "{}",
        colorize("   ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄")
    );
    println!(
        "{}",
        colorize("  ████▌▄▌▄▐▐▌█████▌▄▌▄▐▐▌▀███▄█▌▄▌▄▐▐▌██████▌▄▌▄▐▐▌█▄")
    );
    println!("   ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀");
    println!();
    println!(
        "        {}  {}",
        title.to_uppercase().bold(),
        "[v1.0]".bright_black()
    );
    println!("        {}", subtitle.bright_black());
    println!();
    println!(
        "{}",
        colorize("   ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀")
    );
    println!();
}

/// Simple glitch-style header
pub fn print_glitch_header(text: &str, color: &str) {
    let colorize = match color {
        "cyan" => |s: &str| s.cyan().to_string(),
        "green" => |s: &str| s.green().to_string(),
        "magenta" => |s: &str| s.magenta().to_string(),
        "yellow" => |s: &str| s.yellow().to_string(),
        "red" => |s: &str| s.red().to_string(),
        _ => |s: &str| s.white().to_string(),
    };

    println!();
    println!(
        "   {}{}{}",
        ">>".bright_black(),
        colorize(&format!(" {} ", text.to_uppercase())),
        "<<".bright_black()
    );
    println!();
}

/// Status line with cyberpunk styling
pub fn status(icon: &str, message: &str, value: &str, color: &str) {
    let icon_colored = match color {
        "cyan" => icon.cyan().bold(),
        "green" => icon.green().bold(),
        "magenta" => icon.magenta().bold(),
        "yellow" => icon.yellow().bold(),
        "red" => icon.red().bold(),
        _ => icon.white().bold(),
    };

    let value_colored = match color {
        "cyan" => value.cyan(),
        "green" => value.green(),
        "magenta" => value.magenta(),
        "yellow" => value.yellow(),
        "red" => value.red(),
        _ => value.white(),
    };

    println!(
        "   {} {} {}",
        icon_colored,
        message.bright_white(),
        value_colored.bold()
    );
}

/// Progress/loading style message
pub fn loading(message: &str) {
    println!("   {} {}", "▸".bright_cyan().bold(), message.white());
}

/// Success message with cyberpunk flair
pub fn success(message: &str) {
    println!();
    println!(
        "   {} {}",
        "◉".bright_green().bold(),
        message.bright_white().bold()
    );
    println!();
}

/// Error message with glitch styling
pub fn error(message: &str) {
    println!();
    println!("   {} {}", "✖".bright_red().bold(), message.red());
    println!();
}

/// Warning with cyberpunk styling
pub fn warning(message: &str) {
    println!("   {} {}", "⚠".yellow().bold(), message.yellow());
}

/// Divider line
pub fn divider(color: &str) {
    let line = match color {
        "cyan" => "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━".cyan(),
        "green" => "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━".green(),
        "magenta" => "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━".magenta(),
        "yellow" => "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━".yellow(),
        "red" => "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━".red(),
        _ => "   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━".bright_black(),
    };
    println!("{}", line);
}

/// Animated-style countdown (just prints)
pub fn countdown_style(count: usize, total: usize) {
    print!(
        "\r   {} [{}/{}] {}",
        "▸".bright_cyan(),
        count.to_string().cyan().bold(),
        total.to_string().bright_black(),
        "█".repeat(count * 50 / total).cyan()
    );
}
