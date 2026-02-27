# dotfiles

Personal dev environment. macOS, zsh, Rust tooling.

## Setup

```sh
git clone https://github.com/radiosilence/dotfiles ~/.dotfiles
~/.dotfiles/setup-macos
```

The `setup-macos` script handles the full bootstrap chain:

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
- **Tool management** - mise for runtimes, role-based Brewfile for system packages (`brewfiles.d/`)
- **Terminal configs** - tmux, WezTerm, ghostty, starship prompt

## Documentation

| Doc                                                   | Description                                                  |
| ----------------------------------------------------- | ------------------------------------------------------------ |
| [cheatsheet.md](docs/cheatsheet.md)                   | **Complete reference** - all commands, aliases, functions    |
| [new-tools.md](docs/new-tools.md)                     | Modern CLI replacements (dust, procs, delta, xh, oha, tokei) |
| [fzf-tab-completions.md](docs/fzf-tab-completions.md) | Fuzzy completion setup with previews                         |
| [CHANGELOG.md](CHANGELOG.md)                          | Full history from 2018 to present (1421 commits)             |

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

## Architecture Notes

**Git signing** - Commit signing is configured globally (`git.d/sign.conf`) via 1Password SSH agent. Tag signing and `user.signingkey` are set in the local git config per-machine since keys are machine-specific.

**Tool duplication** - Some tools exist in both brew and mise intentionally:
- `sheldon` — brew for Intel (no arm64 binary on their releases), mise for Apple Silicon
- `uv` — brew only (system-wide Python tooling, not per-project)

**Lefthook** - Uses `mise x --` to run tools. The `zsh -i -c` convention in CLAUDE.md is specifically for Claude Code agent sessions (full shell env), not for git hooks.

## Related

- [browser-schedule](https://github.com/radiosilence/browser-schedule) - Time-based browser switching for macOS
