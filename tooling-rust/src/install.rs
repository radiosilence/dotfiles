use anyhow::{Context, Result};
use colored::Colorize;
use std::fs;
use std::os::unix::fs as unix_fs;
use std::path::Path;
use std::process::Command;

pub fn install_dotfiles() -> Result<()> {
    let home = std::env::var("HOME").context("HOME not set")?;
    let home_path = Path::new(&home);
    let dotfiles = home_path.join(".dotfiles");

    println!("\n{}", "🏠 Installing dotfiles".cyan().bold());
    println!("{}", "━".repeat(50).cyan());

    // Update dotfiles repo if it's a git repo
    if dotfiles.join(".git").exists() {
        println!("   {} updating dotfiles...", "→".cyan());
        let status = Command::new("git")
            .args(["pull"])
            .current_dir(&dotfiles)
            .output();

        if status.is_ok() {
            println!("   {} dotfiles updated", "✓".green());
        } else {
            println!("   {} could not update dotfiles repo", "⚠".yellow());
        }
    }

    println!("{}", "━".repeat(50).cyan());

    // Link dotfiles
    println!("   {} linking dotfiles...", "→".cyan());
    let mut linked_count = 0;
    for entry in fs::read_dir(&dotfiles)? {
        let entry = entry?;
        let path = entry.path();
        let filename = path.file_name().unwrap().to_str().unwrap();

        // Skip non-dotfiles and special cases
        if !filename.starts_with('.') {
            continue;
        }

        match filename {
            "." | ".." | ".git" | ".gitignore" | ".config" | ".vscode" | ".sonarlint" => continue,
            _ => {}
        }

        let target = home_path.join(filename);

        // Check if already correctly linked
        if target.is_symlink() {
            if let Ok(link_target) = fs::read_link(&target) {
                if link_target == path {
                    continue;
                }
            }
        }

        // Skip if file/dir exists
        if target.exists() {
            continue;
        }

        println!("   {} linking {} → ~/{}", "🔗".cyan(), filename, filename);
        unix_fs::symlink(&path, &target).with_context(|| {
            format!("Failed to link {} to {}", path.display(), target.display())
        })?;
        linked_count += 1;
    }
    if linked_count == 0 {
        println!("   {} all dotfiles already linked", "✓".green());
    }

    // Link config dirs
    println!("{}", "━".repeat(50).cyan());
    println!("   {} linking config dirs...", "→".cyan());

    let config_dir = home_path.join(".config");
    if !config_dir.exists() {
        fs::create_dir(&config_dir)?;
        println!("   {} created ~/.config", "✓".green());
    }

    let dotfiles_config = dotfiles.join("config");
    let mut config_linked = 0;
    if dotfiles_config.exists() {
        for entry in fs::read_dir(&dotfiles_config)? {
            let entry = entry?;
            let path = entry.path();
            let dirname = path.file_name().unwrap();
            let target = config_dir.join(dirname);

            // Check if already correctly linked
            if target.is_symlink() {
                if let Ok(link_target) = fs::read_link(&target) {
                    if link_target == path {
                        continue;
                    }
                }
            }

            // Remove existing wrong symlink
            if target.is_symlink() {
                fs::remove_file(&target)?;
            }

            // Skip if file/dir exists
            if target.exists() {
                continue;
            }

            println!(
                "   {} linking {} → ~/.config/{}",
                "🔗".cyan(),
                dirname.to_string_lossy(),
                dirname.to_string_lossy()
            );
            unix_fs::symlink(&path, &target).with_context(|| {
                format!("Failed to link {} to {}", path.display(), target.display())
            })?;
            config_linked += 1;
        }
    }
    if config_linked == 0 {
        println!("   {} all config dirs already linked", "✓".green());
    }

    // Setup gitconfig
    println!("{}", "━".repeat(50).cyan());
    println!("   {} setting up git config...", "→".cyan());
    let gitconfig = home_path.join(".gitconfig");
    if !gitconfig.exists() {
        fs::write(&gitconfig, "")?;
    }

    let gitconfig_content = fs::read_to_string(&gitconfig)?;
    if !gitconfig_content.contains(".dotfiles") {
        let include = "\n[include]\npath = ~/.dotfiles/git.d/core.conf\n";
        fs::write(&gitconfig, format!("{}{}", gitconfig_content, include))?;
        println!("   {} added git.d/core.conf include", "✓".green());
    } else {
        println!("   {} git config already configured", "✓".green());
    }

    // Setup SSH config
    println!("{}", "━".repeat(50).cyan());
    println!("   {} setting up ssh config...", "→".cyan());
    let ssh_dir = home_path.join(".ssh");
    let ssh_config = ssh_dir.join("config");

    if !ssh_dir.exists() {
        fs::create_dir(&ssh_dir)?;
    }

    if !ssh_config.exists() {
        fs::write(&ssh_config, "")?;
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            fs::set_permissions(&ssh_config, fs::Permissions::from_mode(0o600))?;
        }
    }

    let ssh_config_content = fs::read_to_string(&ssh_config)?;
    if !ssh_config_content.contains(".dotfiles") {
        let include = "\nInclude ~/.dotfiles/ssh.d/*.conf\n";
        fs::write(&ssh_config, format!("{}{}", ssh_config_content, include))?;
        println!("   {} added ssh.d/*.conf include", "✓".green());
    } else {
        println!("   {} ssh config already configured", "✓".green());
    }

    // Link Brewfile on macOS
    if cfg!(target_os = "macos") {
        println!("{}", "━".repeat(50).cyan());
        println!("   {} linking Brewfile...", "→".cyan());
        let brewfile = home_path.join("Brewfile");
        let dotfiles_brewfile = dotfiles.join("Brewfile");

        if !brewfile.exists() && dotfiles_brewfile.exists() {
            unix_fs::symlink(&dotfiles_brewfile, &brewfile)?;
            println!("   {} linked ~/Brewfile", "✓".green());
        } else {
            println!("   {} Brewfile already linked", "✓".green());
        }
    }

    // Install sheldon plugins if available
    println!("{}", "━".repeat(50).cyan());
    if which("sheldon") {
        println!("   {} installing sheldon plugins...", "→".cyan());
        let status = Command::new("sheldon").arg("source").output();

        if status.is_ok() {
            println!("   {} sheldon plugins installed", "✓".green());
        } else {
            println!("   {} sheldon plugin installation failed", "⚠".yellow());
        }
    }

    println!("{}", "━".repeat(50).cyan());
    println!(
        "   {} {}\n",
        "✓".green().bold(),
        "Installation complete".green().bold()
    );

    Ok(())
}

fn which(cmd: &str) -> bool {
    Command::new("which")
        .arg(cmd)
        .output()
        .map(|output| output.status.success())
        .unwrap_or(false)
}
