//! Minimal CLI output helpers

use colored::Colorize;

/// Print a section header: `/// .SECTION NAME`
pub fn header(text: &str) {
    println!();
    println!("{}", format!("/// .{}", text.to_uppercase()).bold());
    println!();
}

/// Print a status line: `→ label: value`
pub fn status(label: &str, value: &str) {
    println!("  {} {}: {}", "→".bright_black(), label, value.white());
}

/// Print success: `✓ message`
pub fn ok(message: &str) {
    println!("  {} {}", "✓".green(), message);
}

/// Print warning: `! message`
pub fn warn(message: &str) {
    println!("  {} {}", "!".yellow(), message);
}

/// Print error: `✗ message`
pub fn err(message: &str) {
    println!("  {} {}", "✗".red(), message);
}

/// Print info: `· message`
pub fn info(message: &str) {
    println!("  {} {}", "·".bright_black(), message);
}
