use anyhow::{Context, Result};
use std::fs;
use std::os::unix::fs as unix_fs;
use std::path::Path;
use std::process::{Command, Stdio};

use which::which;

/// Binary names from this crate that should NOT exist in ~/.cargo/bin
const OUR_BINARIES: &[&str] = &[
    "clean-dls",
    "clean-exif",
    "echo-to-file",
    "embed-art",
    "extract-exif-from-flac",
    "gen-diff",
    "git-squash",
    "git-sync",
    "git-trigger",
    "imp",
    "install-font-macos",
    "install-terminfo",
    "kill-port",
    "parallel-dl-extract",
    "prune",
    "prune-gen",
    "regen-zsh-completions",
    "to-audio",
    "unfuck-xcode",
    "upd",
    "update-ffmpeg",
    "url2base64",
    "vimv",
];

/// Remove stale binaries from ~/.cargo/bin that conflict with ~/.dotfiles/bin
pub fn cleanup_stale_cargo_bins() -> Result<Vec<String>> {
    let home = std::env::var("HOME").context("HOME not set")?;
    let cargo_bin = Path::new(&home).join(".cargo/bin");

    if !cargo_bin.exists() {
        return Ok(vec![]);
    }

    let mut removed = vec![];
    for bin in OUR_BINARIES {
        let path = cargo_bin.join(bin);
        if path.exists() {
            fs::remove_file(&path)
                .with_context(|| format!("Failed to remove {}", path.display()))?;
            removed.push(bin.to_string());
        }
    }

    Ok(removed)
}

#[derive(Debug)]
pub struct InstallSummary {
    pub dotfiles_linked: usize,
    pub configs_linked: usize,
    pub git_configured: bool,
    pub ssh_configured: bool,
    pub brewfile_linked: bool,
    pub sheldon_installed: bool,
}

pub fn install_dotfiles() -> Result<InstallSummary> {
    let home = std::env::var("HOME").context("HOME not set")?;
    let home_path = Path::new(&home);
    let dotfiles = home_path.join(".dotfiles");

    let mut summary = InstallSummary {
        dotfiles_linked: 0,
        configs_linked: 0,
        git_configured: false,
        ssh_configured: false,
        brewfile_linked: false,
        sheldon_installed: false,
    };

    // Update dotfiles repo if it's a git repo (silently)
    if dotfiles.join(".git").exists() {
        let _ = Command::new("git")
            .args(["pull"])
            .current_dir(&dotfiles)
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .output();
    }

    // Link dotfiles
    for entry in fs::read_dir(&dotfiles)? {
        let entry = entry?;
        let path = entry.path();
        let Some(filename) = path.file_name().and_then(|f| f.to_str()) else {
            continue;
        };

        // Skip non-dotfiles and special cases
        if !filename.starts_with('.') {
            continue;
        }

        if matches!(
            filename,
            "." | ".." | ".git" | ".gitignore" | ".config" | ".vscode" | ".sonarlint"
        ) {
            continue;
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

        unix_fs::symlink(&path, &target).with_context(|| {
            format!("Failed to link {} to {}", path.display(), target.display())
        })?;
        summary.dotfiles_linked += 1;
    }

    // Link config dirs
    let config_dir = home_path.join(".config");
    if !config_dir.exists() {
        fs::create_dir(&config_dir)?;
    }

    let dotfiles_config = dotfiles.join("config");
    if dotfiles_config.exists() {
        for entry in fs::read_dir(&dotfiles_config)? {
            let entry = entry?;
            let path = entry.path();
            let Some(dirname) = path.file_name() else {
                continue;
            };
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

            unix_fs::symlink(&path, &target).with_context(|| {
                format!("Failed to link {} to {}", path.display(), target.display())
            })?;
            summary.configs_linked += 1;
        }
    }

    // Setup gitconfig
    let gitconfig = home_path.join(".gitconfig");
    if !gitconfig.exists() {
        fs::write(&gitconfig, "")?;
    }

    let gitconfig_content = fs::read_to_string(&gitconfig)?;
    if !gitconfig_content.contains(".dotfiles") {
        let include = "\n[include]\npath = ~/.dotfiles/git.d/core.conf\n";
        fs::write(&gitconfig, format!("{}{}", gitconfig_content, include))?;
        summary.git_configured = true;
    }

    // Setup SSH config
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
        summary.ssh_configured = true;
    }

    // Link Brewfile on macOS
    if cfg!(target_os = "macos") {
        let brewfile = home_path.join("Brewfile");
        let dotfiles_brewfile = dotfiles.join("Brewfile");

        if !brewfile.exists() && dotfiles_brewfile.exists() {
            unix_fs::symlink(&dotfiles_brewfile, &brewfile)?;
            summary.brewfile_linked = true;
        }
    }

    // Install sheldon plugins if available
    if which("sheldon").is_ok() {
        let installed = Command::new("sheldon")
            .arg("source")
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false);

        summary.sheldon_installed = installed;
    }

    Ok(summary)
}
