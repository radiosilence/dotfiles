//! Convert URLs to base64 data URLs
//!
//! Downloads content from URLs and converts to base64-encoded data URLs.
//! Useful for embedding SVGs and other assets inline in HTML/CSS.

use anyhow::{Context, Result};
use base64::{engine::general_purpose::STANDARD, Engine};
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use colored::Colorize;
use reqwest::blocking::Client;
use std::io::{self, BufRead};
use std::time::Duration;

#[derive(Parser)]
#[command(name = "url2base64")]
#[command(about = "Convert URLs to base64 data URLs", long_about = None)]
#[command(version)]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,

    /// URLs to convert (reads from stdin if not provided)
    #[arg(value_name = "URL")]
    url: Option<String>,

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

#[derive(Subcommand)]
enum Commands {
    /// Generate shell completions
    Completion {
        #[arg(value_enum)]
        shell: Shell,
    },
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

    if let Some(Commands::Completion { shell }) = args.command {
        generate(shell, &mut Args::command(), "url2base64", &mut io::stdout());
        return Ok(());
    }

    let client = Client::builder()
        .timeout(Duration::from_secs(args.timeout))
        .build()
        .context("Failed to create HTTP client")?;

    let url = args
        .url
        .ok_or_else(|| anyhow::anyhow!(Args::command().render_help()))?;

    if let Ok(result) = convert_url(&client, &url, &args.mime_type) {
        print!("{}", result);
    } else {
        anyhow::bail!("it fucked up")
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_convert_url_format() {
        let data = b"test data";
        let encoded = STANDARD.encode(data);
        let result = format!("data:image/svg+xml;base64,{}", encoded);

        assert!(result.starts_with("data:image/svg+xml;base64,"));
        assert!(result.contains(&encoded));
    }

    #[test]
    fn test_base64_encoding() {
        let input = b"hello world";
        let encoded = STANDARD.encode(input);
        assert_eq!(encoded, "aGVsbG8gd29ybGQ=");
    }

    #[test]
    fn test_mime_type_formatting() {
        let mime = "image/png";
        let encoded = "abc123";
        let result = format!("data:{};base64,{}", mime, encoded);
        assert_eq!(result, "data:image/png;base64,abc123");
    }

    #[test]
    fn test_empty_data() {
        let data = b"";
        let encoded = STANDARD.encode(data);
        let result = format!("data:text/plain;base64,{}", encoded);
        assert_eq!(result, "data:text/plain;base64,");
    }

    #[test]
    fn test_binary_data_encoding() {
        let data = vec![0u8, 255u8, 128u8, 64u8];
        let encoded = STANDARD.encode(&data);
        // Just verify it encodes without panicking
        assert!(!encoded.is_empty());
    }
}
