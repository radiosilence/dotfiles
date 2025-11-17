use anyhow::Result;
use clap::Parser;
use dotfiles_tools::completions;
use std::io::Write;
use std::process::Command;

#[derive(Parser)]
#[command(about = "Install terminfo to remote host via SSH")]
struct Args {
    /// Remote host (e.g., user@hostname)
    host: String,
}

fn main() -> Result<()> {
    if completions::handle_completion_flag::<Args>() {
        return Ok(());
    }

    let args = Args::parse();

    banner::print_glitch_header("INSTALL-TERMINFO", "cyan");
    banner::status("□", "TARGET", &args.host, "cyan");

    let infocmp = Command::new("infocmp").arg("-x").output()?;

    if !infocmp.status.success() {
        anyhow::bail!("infocmp failed");
    }

    let mut child = Command::new("ssh")
        .arg(&args.host)
        .arg("--")
        .arg("tic")
        .arg("-x")
        .arg("-")
        .stdin(std::process::Stdio::piped())
        .spawn()?;

    child.stdin.as_mut().unwrap().write_all(&infocmp.stdout)?;
    let status = child.wait()?;

    if !status.success() {
        anyhow::bail!("ssh tic failed");
    }

    banner::success("TERMINFO INSTALLED");
    Ok(())
}

mod banner {
    use colored::Colorize;

    pub fn print_glitch_header(title: &str, color: &str) {
        let color_fn = match color {
            "cyan" => |s: &str| s.cyan().to_string(),
            "magenta" => |s: &str| s.magenta().to_string(),
            _ => |s: &str| s.to_string(),
        };
        println!("\n{}", color_fn(&format!("   ╔═══ {} ═══╗", title)).bold());
    }

    pub fn status(icon: &str, label: &str, value: &str, color: &str) {
        let color_fn = match color {
            "cyan" => |s: &str| s.cyan().to_string(),
            "magenta" => |s: &str| s.magenta().to_string(),
            _ => |s: &str| s.to_string(),
        };
        println!("   {} {} {}", color_fn(icon), label.bold(), value);
    }

    pub fn success(msg: &str) {
        println!("   {} {}\n", "✓".green().bold(), msg.green().bold());
    }
}
