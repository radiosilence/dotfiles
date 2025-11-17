//! Shell completion generation helper

use clap::{CommandFactory, ValueEnum};
use clap_complete::{generate, Shell};
use std::io;

#[derive(Debug, Clone, Copy, ValueEnum)]
pub enum CompletionShell {
    Bash,
    Zsh,
    Fish,
    Powershell,
    Elvish,
}

impl From<CompletionShell> for Shell {
    fn from(shell: CompletionShell) -> Self {
        match shell {
            CompletionShell::Bash => Shell::Bash,
            CompletionShell::Zsh => Shell::Zsh,
            CompletionShell::Fish => Shell::Fish,
            CompletionShell::Powershell => Shell::PowerShell,
            CompletionShell::Elvish => Shell::Elvish,
        }
    }
}

/// Check if completion subcommand is present and generate completions if so
/// Returns true if completions were generated (tool should exit)
pub fn handle_completion_flag<T: CommandFactory>() -> bool {
    let args: Vec<String> = std::env::args().collect();

    if args.len() >= 3 && args[1] == "completion" {
        let shell = match args[2].as_str() {
            "bash" => Shell::Bash,
            "zsh" => Shell::Zsh,
            "fish" => Shell::Fish,
            "powershell" => Shell::PowerShell,
            "elvish" => Shell::Elvish,
            _ => {
                eprintln!("Unknown shell: {}", args[2]);
                eprintln!("Supported: bash, zsh, fish, powershell, elvish");
                std::process::exit(1);
            }
        };

        let mut cmd = T::command();
        let name = cmd.get_name().to_string();
        generate(shell, &mut cmd, name, &mut io::stdout());
        return true;
    }

    false
}

/// Generate completions for the given shell
pub fn generate_completions<T: CommandFactory>(shell: CompletionShell) {
    let mut cmd = T::command();
    let name = cmd.get_name().to_string();
    let shell: Shell = shell.into();
    generate(shell, &mut cmd, name, &mut io::stdout());
}
