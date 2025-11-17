//! Cyberpunk ASCII art banners and styling

use colored::{ColoredString, Colorize};
use unicode_width::UnicodeWidthStr;

fn colorize_text(text: &str, color: &str) -> ColoredString {
    match color {
        "cyan" => text.bright_cyan(),
        "green" => text.bright_green(),
        "magenta" => text.bright_magenta(),
        "yellow" => text.bright_yellow(),
        "red" => text.bright_red(),
        _ => text.bright_white(),
    }
}

fn colorize_text_bold(text: &str, color: &str) -> ColoredString {
    colorize_text(text, color).bold()
}

/// Cyberpunk-styled banner with glitch aesthetic - dynamically sized
pub fn print_banner(title: &str, subtitle: &str, color: &str) {
    // Calculate width needed - account for "     " prefix and "[v1.0]" suffix
    let title_display = format!("     {}  [v1.0]", title.to_uppercase());
    let subtitle_display = format!("     {}", subtitle);
    let max_width = title_display.width().max(subtitle_display.width());
    let border_width = max_width.max(50); // Minimum 50 chars

    println!();
    println!(
        "{}",
        colorize_text_bold(&format!("{}", "▄".repeat(border_width)), color)
    );
    println!(
        "{}",
        colorize_text_bold(&format!("  {}", "█".repeat(border_width)), color)
    );
    println!("{}", "▀".repeat(border_width));
    println!();
    println!(
        "     {}  {}",
        title.to_uppercase().bold(),
        "[v1.0]".bright_black()
    );
    println!("     {}", subtitle.bright_black());
    println!();
    println!(
        "{}",
        colorize_text_bold(&format!("{}", "▀".repeat(border_width)), color)
    );
    println!();
}

/// Simple glitch-style header
pub fn print_glitch_header(text: &str, color: &str) {
    println!();
    println!(
        "{}{}{}",
        ">>".bright_black(),
        colorize_text(&format!(" {} ", text.to_uppercase()), color),
        "<<".bright_black()
    );
    println!();
}

/// Status line with cyberpunk styling
pub fn status(icon: &str, message: &str, value: &str, color: &str) {
    println!(
        "{} {} {}",
        colorize_text_bold(icon, color),
        message.bright_white(),
        colorize_text(value, color).bold()
    );
}

/// Progress/loading style message
pub fn loading(message: &str) {
    println!("{} {}", "▸".bright_cyan().bold(), message.white());
}

/// Success message with cyberpunk flair
pub fn success(message: &str) {
    println!();
    println!(
        "{} {}",
        "◉".bright_green().bold(),
        message.bright_white().bold()
    );
    println!();
}

/// Error message with glitch styling
pub fn error(message: &str) {
    println!();
    println!("{} {}", "✖".bright_red().bold(), message.red());
    println!();
}

/// Warning with cyberpunk styling
pub fn warning(message: &str) {
    println!("{} {}", "⚠".yellow().bold(), message.yellow());
}

/// Divider line
pub fn divider(color: &str) {
    println!(
        "{}",
        colorize_text("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", color)
    );
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
