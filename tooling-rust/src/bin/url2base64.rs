//! Convert URLs to base64 data URLs
//!
//! Downloads content from URLs and converts to base64-encoded data URLs.
//! Useful for embedding SVGs and other assets inline in HTML/CSS.

use anyhow::{Context, Result};
use base64::{engine::general_purpose::STANDARD, Engine};
use clap::Parser;
use colored::Colorize;
use indicatif::{ProgressBar, ProgressStyle};
use reqwest::blocking::Client;
use std::io::{self, BufRead};
use std::time::Duration;

#[derive(Parser)]
#[command(name = "url2base64")]
#[command(about = "Convert URLs to base64 data URLs", long_about = None)]
#[command(version)]
struct Args {
    /// URLs to convert (reads from stdin if not provided)
    #[arg(value_name = "URLS")]
    urls: Vec<String>,

    /// MIME type (default: image/svg+xml)
    #[arg(short = 't', long, default_value = "image/svg+xml")]
    mime_type: String,

    /// Timeout in seconds
    #[arg(long, default_value = "30")]
    timeout: u64,

    /// Skip failed URLs instead of exiting
    #[arg(short, long)]
    skip_errors: bool,
}

fn convert_url(client: &Client, url: &str, mime_type: &str) -> Result<String> {
    let response = client
        .get(url)
        .send()
        .with_context(|| format!("Failed to fetch {}", url))?;

    if !response.status().is_success() {
        anyhow::bail!("HTTP {}: {}", response.status(), url);
    }

    let content = response.bytes().context("Failed to read response body")?;

    let encoded = STANDARD.encode(&content);
    Ok(format!("data:{};base64,{}", mime_type, encoded))
}

fn main() -> Result<()> {
    let args = Args::parse();

    println!(
        "{}",
        "╔═══════════════════════════════════════╗".bright_green()
    );
    println!(
        "{}",
        "║     URL → BASE64 CONVERTER v1.0       ║".bright_green()
    );
    println!(
        "{}",
        "║  [data uri encoding utility]          ║".bright_green()
    );
    println!(
        "{}",
        "╚═══════════════════════════════════════╝".bright_green()
    );
    println!();

    let client = Client::builder()
        .timeout(Duration::from_secs(args.timeout))
        .build()
        .context("Failed to create HTTP client")?;

    let urls: Vec<String> = if args.urls.is_empty() {
        // Read from stdin
        let stdin = io::stdin();
        stdin.lock().lines().filter_map(|l| l.ok()).collect()
    } else {
        args.urls
    };

    if urls.is_empty() {
        eprintln!("{} No URLs provided", "!".red().bold());
        eprintln!("Usage: url2base64 <url1> [url2...] or pipe URLs via stdin");
        std::process::exit(1);
    }

    let pb = ProgressBar::new(urls.len() as u64);
    pb.set_style(
        ProgressStyle::default_bar()
            .template("{spinner:.green} [{bar:40.cyan/blue}] {pos}/{len} {msg}")
            .unwrap()
            .progress_chars("=> "),
    );

    let mut success_count = 0;
    let mut error_count = 0;

    for url in &urls {
        pb.set_message(format!("Processing {}", url.bright_black()));

        match convert_url(&client, url, &args.mime_type) {
            Ok(data_url) => {
                println!("{}", data_url);
                success_count += 1;
                pb.inc(1);
            }
            Err(e) => {
                error_count += 1;
                pb.inc(1);

                eprintln!(
                    "{} {}: {}",
                    "✗".red().bold(),
                    url.yellow(),
                    e.to_string().red()
                );

                if !args.skip_errors {
                    pb.finish_and_clear();
                    return Err(e);
                }
            }
        }
    }

    pb.finish_and_clear();

    println!(
        "\n{} Converted {} URLs{}",
        "✓".green().bold(),
        success_count.to_string().green(),
        if error_count > 0 {
            format!(" ({} failed)", error_count.to_string().red())
        } else {
            String::new()
        }
    );

    if error_count > 0 && !args.skip_errors {
        std::process::exit(1);
    }

    Ok(())
}
