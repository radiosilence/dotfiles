# dotfiles

Personal dev environment. macOS, zsh, Rust tooling.

## Setup

```sh
xcode-select --install  # needed for git, compilers, etc.
git clone https://github.com/radiosilence/dotfiles ~/.dotfiles
~/.dotfiles/setup-macos
```

The `setup-macos` script handles the full bootstrap chain:

1. Sudo/TouchID, Rosetta 2 (Apple Silicon only)
2. Homebrew + `brew bundle`
3. GitHub CLI auth (for private mise tools)
4. mise tool installation
5. Symlinks dotfiles and configs (`mise run link`)
6. Builds Rust binaries, runs `upd` for package updates + zsh completions
7. Switches repo remote to SSH, prints manual steps (1Password SSH agent)

After setup, run `upd` anytime to update everything. Auth setup (`gh auth login`, 1Password CLI integration) is guided but manual — `upd` prints what's needed.

## What's Here

- **Shell configs** - Modular zsh setup with 30+ config files, 80+ git aliases, fzf-tab completions
- **23 Rust binaries** - System maintenance, git workflow, media processing, file operations
- **Tool management** - mise for runtimes, role-based Brewfile for system packages (`brewfiles.d/`)
- **Terminal configs** - tmux, ghostty, cmux, starship prompt

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

## Configuration

`dotfiles.toml` is the tracked config. For per-machine overrides, create `dotfiles.local.toml` (gitignored) — arrays are concatenated, scalars are replaced.

The config drives:
- **ZSH completions** (`[[completions.tools]]`) — add a tool's completions by appending a few lines of TOML instead of editing Rust source. Supports custom commands, pre-built completions, and sourced scripts.
- **Fonts** (`[[fonts]]`) — macOS font auto-installation. `upd` downloads and installs any fonts not already present.

## Per-Directory Git Config

Set git config overrides for all repos under a directory:

```sh
cd ~/workspace/surgeventures/any-repo
mise run git-conf-dir user.email james.cleveland@fresha.com
mise run git-conf-dir user.name "James Cleveland (Fresha)"
```

Stores config in `~/.local/git.d/<path>.conf` (e.g. `workspace--surgeventures.conf`) and adds an `includeIf` to `~/.gitconfig`. Multiple keys accumulate in the same file. Idempotent.

## Architecture Notes

**Git signing** - Commit signing is configured globally (`git.d/sign.conf`) via 1Password SSH agent. Tag signing and `user.signingkey` are set in the local git config per-machine since keys are machine-specific.

**Tool duplication** - Some tools exist in both brew and mise intentionally:
- `sheldon` — brew for Intel (no arm64 binary on their releases), mise for Apple Silicon
- `uv` — brew only (system-wide Python tooling, not per-project)

**Lefthook** - Uses `mise x --` to run tools. The `zsh -i -c` convention in CLAUDE.md is specifically for Claude Code agent sessions (full shell env), not for git hooks.

## Syncthing

Syncthing is installed via brew (`brewfiles.d/core.rb`). To start it as a background service that persists across reboots:

```sh
brew services start syncthing
```

The web UI is at `http://localhost:8384`. Configure shared folders and remote devices there.

To stop the service: `brew services stop syncthing`. To run it one-off without a background service: `syncthing --no-browser --no-restart`.

## cmux Integration

`mise run link` auto-injects three Claude Code hooks into `~/.claude/settings.json` for cmux:

| Hook | Script | What it does |
|------|--------|-------------|
| `SessionStart` | `cmux-session.sh` | Renames workspace to repo name, sets "ready" status pill |
| `UserPromptSubmit` | `cmux-title.sh` | Sets "working" status pill, shows prompt summary in sidebar |
| `Stop` | `cmux-notify.sh` | Fires `cmux claude-hook stop`, sets "waiting" status pill |

All hooks are no-ops outside cmux. The cmux CLI ships with the app — no extra install needed.

The `cmux` CLI also supports spawning workspaces/panes, a full browser automation API, screen reading, and more — run `cmux` for the full command list.

## Related

- [browser-schedule](https://github.com/radiosilence/browser-schedule) - Time-based browser switching for macOS
