use anyhow::Result;
use clap::{CommandFactory, Parser, Subcommand};
use clap_complete::{generate, Shell};
use std::fs;
use std::io;

#[derive(Parser)]
#[command(name = "echo-to-file")]
#[command(about = "Write to temp file", long_about = None)]
struct Args {
    #[command(subcommand)]
    command: Option<Commands>,
    /// Text to write
    #[arg(trailing_var_arg = true, allow_hyphen_values = true)]
    text: Vec<String>,
}

#[derive(Subcommand)]
enum Commands {
    /// Generate shell completions
    Completion {
        #[arg(value_enum)]
        shell: Shell,
    },
}

fn write_text_to_file(text: &[String]) -> Result<()> {
    let content = text.join(" ");
    fs::write("/tmp/echo-out", content)?;
    Ok(())
}

fn main() -> Result<()> {
    let args = Args::parse();

    if let Some(Commands::Completion { shell }) = args.command {
        generate(
            shell,
            &mut Args::command(),
            "echo-to-file",
            &mut io::stdout(),
        );
        return Ok(());
    }

    write_text_to_file(&args.text)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_join_text() {
        let text = ["hello".to_string(), "world".to_string()];
        let result = text.join(" ");
        assert_eq!(result, "hello world");
    }

    #[test]
    fn test_join_text_with_hyphens() {
        let text = ["--flag".to_string(), "-a".to_string(), "value".to_string()];
        let result = text.join(" ");
        assert_eq!(result, "--flag -a value");
    }

    #[test]
    fn test_write_text_to_file() {
        let text = vec!["test".to_string(), "content".to_string()];
        write_text_to_file(&text).expect("Failed to write file");

        let content = fs::read_to_string("/tmp/echo-out").expect("Failed to read file");
        assert_eq!(content, "test content");
    }

    #[test]
    fn test_empty_text() {
        use tempfile::TempDir;

        let temp_dir = TempDir::new().unwrap();
        let test_file = temp_dir.path().join("test-echo");

        let text: Vec<String> = vec![];
        let content = text.join(" ");
        fs::write(&test_file, content).unwrap();

        let read_content = fs::read_to_string(&test_file).expect("Failed to read file");
        assert_eq!(read_content, "");
    }
}
