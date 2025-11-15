# Dotfiles

Personal dev environment configs for macOS.

## Requirements

- macOS (Darwin) or Linux (via Docker)
- Zsh shell

## What's Included

**Core Tools:**

- **zsh** - Shell with modular config structure
- **mise** - Universal runtime/tool manager (replaces asdf/nvm/rbenv)
- **starship** - Fast, customizable shell prompt
- **git** - Modular config via includes
- **ssh** - Security-focused config modules

**Editors & Dev:**

- **zed** - Primary editor with Claude integration
- **helix** - Terminal-based editor
- **ghostty** - Primary terminal emulator

**CLI Utilities:**

- 29 POSIX-compliant scripts in `bin/` (see `bin/<script> --help`)
- Audio processing tools (FLAC/Opus conversion, CD ripping)
- Git workflow automation (branch cleanup, squashing)
- System utilities (port killing, batch renaming, directory pruning)

---

## Installation

### Fresh macOS Setup

Installs Homebrew, clones repo, symlinks configs, and installs all tools:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
git clone https://github.com/radiosilence/dotfiles ~/.dotfiles
~/.dotfiles/bin/setup-macos
```

### Existing System

If you already have Homebrew:

```sh
git clone https://github.com/radiosilence/dotfiles ~/.dotfiles
~/.dotfiles/install
brew bundle --file=~/.dotfiles/Brewfile
mise install
```

### What Install Does

The `install` script:

- Symlinks dotfiles (`.zshrc`, `.tmux.conf`) to `$HOME`
- Symlinks `config/` dirs to `~/.config/`
- Backs up existing configs to `~/.dotfiles-backup-<timestamp>` before overwriting
- Injects git/ssh config includes into existing files
- Installs Sheldon plugins

**Safe to run multiple times** - skips existing links and backs up before changes.

## Brewfile Structure

The Brewfile is organized into logical sections for easier maintenance:

- **CORE** - Essential system tools (git, curl, zsh, gnupg)
- **DEV TOOLS** - IDEs and dev applications (Zed, Figma, Fork)
- **LANGUAGES** - Runtimes and language managers (node, mise, uv)
- **BUILD TOOLS** - Compilers and build systems (cmake, llvm)
- **LSPS** - Language servers for editor integration
- **INFRA** - Cloud and DevOps tools (AWS, Terraform, Ansible)
- **NETWORKING** - Network debugging tools (nmap, grpcurl)
- **CLI UTILS** - Shell productivity tools (bat, ripgrep, btop)
- **MEDIA** - Audio/video processing (ffmpeg, flac, sox)
- **DATABASE** - Database clients and tools
- And more...

To install only specific sections, extract them into separate Brewfiles.

## Key Scripts

All scripts support `--help` flag:

- **kill-port** - Kill process listening on port
- **vimv** - Batch rename files in $EDITOR
- **git-sync** - Clean up merged branches
- **prune** - Find and delete small directories
- **to-opus** - Convert audio files to Opus format
- **setup-macos** - Bootstrap fresh macOS installation

## Container Usage

Full dev environment via Docker:

```sh
docker build -t dotfiles .
docker run -it dotfiles zsh
```

Includes all configs and mise-managed tools.
