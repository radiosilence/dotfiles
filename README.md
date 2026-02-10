# dotfiles

Personal dev environment. macOS, zsh, Rust tooling.

## Setup

```sh
git clone https://github.com/radiosilence/dotfiles ~/.dotfiles
~/.dotfiles/setup
```

The `setup` script handles the full bootstrap chain:

1. Xcode Command Line Tools (headless install via softwareupdate)
2. Rosetta 2 (Apple Silicon only)
3. Homebrew + `brew bundle`
4. Rust via mise (no rustup needed)
5. Builds all Rust binaries
6. Runs `upd` — dotfile linking, auth checks, package updates, browser extension policies, zsh completions

After setup, run `upd` anytime to update everything. Auth setup (`gh auth login`, 1Password CLI integration) is guided but manual — `upd` prints what's needed.

## What's Here

- **Shell configs** - Modular zsh setup with 30+ config files, 80+ git aliases, fzf-tab completions
- **23 Rust binaries** - System maintenance, git workflow, media processing, file operations
- **Tool management** - mise for runtimes, Brewfile for system packages
- **Terminal configs** - tmux, WezTerm, ghostty, starship prompt

## Documentation

| Doc                                                   | Description                                                  |
| ----------------------------------------------------- | ------------------------------------------------------------ |
| [cheatsheet.md](docs/cheatsheet.md)                   | **Complete reference** - all commands, aliases, functions    |
| [new-tools.md](docs/new-tools.md)                     | Modern CLI replacements (dust, procs, delta, xh, oha, tokei) |
| [fzf-tab-completions.md](docs/fzf-tab-completions.md) | Fuzzy completion setup with previews                         |

## Highlights

**System**

- `upd` - Update everything (dotfiles, brew, mise, rust bins)
- `kill-port <port>` - Kill process on port
- `prune` - Find and delete small directories

**Git workflow**

- `git-sync` - Delete merged local branches
- `git-squash` - Squash commits for clean PRs
- `git-trigger` - Re-trigger CI with empty amend
- `fm` / `fr` - Fuzzy merge/rebase with fzf

**Media**

- `to-audio opus|flac` - Parallel audio conversion
- `embed-art` - Embed cover art into FLACs
- `imp` - Download + extract + beets import

**Files**

- `vimv` - Batch rename in $EDITOR
- `clean-dls` - Remove scene release garbage

All binaries support `--help` and have shell completions.

## Related

- [browser-schedule](https://github.com/radiosilence/browser-schedule) - Time-based browser switching for macOS

## Docker

```sh
docker build -t dotfiles .
docker run -it dotfiles zsh
```
