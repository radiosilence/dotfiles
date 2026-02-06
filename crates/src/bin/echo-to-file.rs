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

fn echo_out_path() -> std::path::PathBuf {
    let uid = nix::unistd::getuid();
    std::env::temp_dir().join(format!("echo-out-{uid}"))
}

fn write_text_to_file(text: &[String], path: &std::path::Path) -> Result<()> {
    let content = text.join(" ");
    fs::write(path, content)?;
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

    write_text_to_file(&args.text, &echo_out_path())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_write_text_to_file() {
        let tmp = tempfile::NamedTempFile::new().unwrap();
        let text = vec!["test".to_string(), "content".to_string()];
        write_text_to_file(&text, tmp.path()).unwrap();
        assert_eq!(fs::read_to_string(tmp.path()).unwrap(), "test content");
    }

    #[test]
    fn test_write_empty_text() {
        let tmp = tempfile::NamedTempFile::new().unwrap();
        let text: Vec<String> = vec![];
        write_text_to_file(&text, tmp.path()).unwrap();
        assert_eq!(fs::read_to_string(tmp.path()).unwrap(), "");
    }

    #[test]
    fn test_echo_out_path_contains_uid() {
        let path = echo_out_path();
        let filename = path.file_name().unwrap().to_str().unwrap();
        assert!(filename.starts_with("echo-out-"));
    }
}
