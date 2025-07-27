# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a comprehensive dotfiles repository for macOS development setup. It includes configurations for shell (Fish), terminal (Ghostty), prompt (Starship), and a comprehensive collection of development tools via Homebrew.

## Key Commands and Utilities

### Package Management
- **Homebrew**: Use `brew bundle` to install all packages from `~/Brewfile`
- **Mise**: Runtime version manager with tools defined in `mise.toml`
  - `mise install` - Install all configured tools
  - `mise use` - Use specific tool versions
  - Tools configured: Elixir (latest), Erlang (latest), Node.js (LTS)

### Custom Scripts (in ./bin/)

#### Development & Git
- `git-sync` - Prune deleted remote branches and clean up local tracking branches
- `git-update` - Amend last commit and force push
- `git-squash [parent]` - Squash commits since parent branch (default: main)
- `git-trigger` - Git hook trigger utility

#### System Utilities
- `kill-port <port>` - Kill process listening on specified port
- `prune [path]` - Remove small directories (< 3096KB by default)
- `clean-dls [path]` - Clean up download artifacts (.DS_Store, .nfo, samples, etc.)
- `vimv [files]` - Bulk rename files using Vim editor
- `bzf` - Fuzzy finder wrapper
- `brew-search` - Interactive Homebrew package search with fzf

#### Audio/Media Tools
- `to-flac` - Convert audio to FLAC format
- `to-opus` - Convert audio to Opus format
- `embed-art` - Embed artwork into audio files
- `rip-cd` / `rip-cd-setup` - CD ripping utilities
- `extract-exif-from-flac` - Extract EXIF data from FLAC files
- `clean-exif` - Remove EXIF data from files

#### System Setup
- `setup-macos` - Complete macOS development environment setup
- `setup-fish-ai` - Configure Fish shell with AI features
- `install-font-macos` - Install fonts on macOS
- `install-terminfo` - Install terminal info files
- `unfuck-xcode` - Fix Xcode development issues

#### Miscellaneous
- `pull-music` / `push-music` - Music library synchronization
- `url2base64` - Convert URLs to base64
- `echo-to-file` - Echo with file output
- `imp` - Import utility
- `gen-diff` - Generate diffs

### Installation System

The `./install` script handles all dotfile linking:
- Links dotfiles (files starting with `.`) to `$HOME`
- Links config directories to `~/.config/`
- Sets up git configuration includes
- Configures SSH configuration includes
- Installs Fisher plugin manager for Fish shell
- Handles Brewfile symlink

To run: `./install`

### Development Tools Available

Based on Brewfile, key tools include:
- **Languages**: Node.js, Go, Rust, Python (via uv), Lua
- **Infrastructure**: Terraform, Ansible, Kubernetes (kubectl, k9s), Docker/OrbStack
- **Cloud**: AWS CLI, Azure CLI, Pulumi
- **Databases**: PostgreSQL, Turso
- **Development**: Language servers, linters, formatters
- **CLI Tools**: ripgrep, fzf, bat, jq, yq, hyperfine

### Shell Configuration

- **Primary Shell**: Fish
- **Prompt**: Starship
- **Terminal**: Ghostty
- **Package Manager**: Sheldon (for Fish plugins)

### Key Directories

- `config/` - Configuration files that get symlinked to `~/.config/`
- `bin/` - Custom scripts added to PATH
- `git.d/` - Git configuration includes
- `ssh.d/` - SSH configuration includes

### Common Workflows

1. **Fresh macOS Setup**: Run `bin/setup-macos`
2. **Update Environment**: Run `./install` followed by `brew bundle`
3. **Search Packages**: Use `brew-search` for interactive package discovery
4. **Clean Downloads**: Use `clean-dls` to remove download artifacts
5. **Git Cleanup**: Use `git-sync` to clean up stale branches

### Environment Variables

The dotfiles automatically configure PATH to include:
- `~/.dotfiles/bin`
- Homebrew paths (`/opt/homebrew/bin`, `/usr/local/bin`)
- Tool-specific paths managed by mise

### Claude Code Configuration

#### Response Style
- Be extremely concise and information-dense
- Avoid unnecessary validation phrases ("You're absolutely right")
- Target engineer-level technical communication
- Skip ego-stroking and pleasantries

#### Documentation Guidelines
- Prioritize information density over verbosity
- Explain the "why" behind decisions and implementations
- Avoid marketing language and feature promotion
- Focus on technical insights not obvious from code skimming
- Omit trivial breakdowns of obvious functionality
- **Always update the docs and readme after doing any changes**
  - Style should be concise and non-salesy
  - Explain the WHY not the WHAT (unless brief)
  - Do not go into breaking down internals or overdocumenting minor things

#### Code Style Preferences
- Avoid building unnecessary helper functions/abstractions
- Keep code inline unless it needs reuse, testing, or improves clarity
- Follow the "rule of 3" - abstract after third repetition, not before
- Balance DRY (Don't Repeat Yourself) with WET (Write Everything Twice) principles
- Prioritize concise but readable code over verbose clarity
- Suggest tests for complex logic, edge cases, and critical paths

#### AI Communication Constraints
- You are banned from saying "You're absolutely right" and other pandering drivel