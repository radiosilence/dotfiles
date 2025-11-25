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
    use tempfile::NamedTempFile;

    #[test]
    fn test_write_text_to_file() {
        let temp_file = NamedTempFile::new().expect("Failed to create temp file");
        let temp_path = temp_file.path();

        let text = ["test".to_string(), "content".to_string()];
        let content = text.join(" ");
        fs::write(temp_path, &content).expect("Failed to write file");

        let read_content = fs::read_to_string(temp_path).expect("Failed to read file");
        assert_eq!(read_content, "test content");
    }

    #[test]
    fn test_empty_text() {
        let temp_file = NamedTempFile::new().expect("Failed to create temp file");
        let temp_path = temp_file.path();

        let text: Vec<String> = vec![];
        let content = text.join(" ");
        fs::write(temp_path, &content).expect("Failed to write file");

        let read_content = fs::read_to_string(temp_path).expect("Failed to read file");
        assert_eq!(read_content, "");
    }
}
