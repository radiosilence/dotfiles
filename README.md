# dotfiles

Personal dev environment. macOS, zsh, Rust tooling.

## Setup

```sh
curl -fsSL https://raw.githubusercontent.com/radiosilence/dotfiles/main/setup-macos | bash
```

12 lines of shell that bootstraps go-task into a tmpdir, curls the Taskfile, and runs `task converge`. The Taskfile DAG handles everything — xcode, brew, mise, 1Password, gh auth, symlinks, Rust binaries, completions, fonts. Idempotent — re-running skips what's already done.

Run `upd` (or `converge`) anytime to update everything. Tasks that need 1Password or gh auth poll silently until ready — no interactive prompts.

## What's Here

- **Shell configs** — Modular zsh setup with 30+ config files, 80+ git aliases, fzf-tab completions
- **Rust binaries** — System maintenance, git workflow, media processing, file operations
- **Taskfile.yml** — DAG-based system management (bootstrap, update, completions, fonts)
- **Tool management** — mise for runtimes, role-based Brewfile for system packages (`brewfiles.d/`)
- **Terminal configs** — zellij, ghostty, tmux, starship prompt
- **Editor configs** — helix (LSP, tree-sitter, formatters for 15+ languages), zed

## Documentation

| Doc | Description |
|-----|-------------|
| [cheatsheet.md](docs/cheatsheet.md) | Complete reference — all commands, aliases, functions |
| [new-tools.md](docs/new-tools.md) | Modern CLI replacements (dust, procs, delta, xh, oha, tokei) |
| [tmux-cheatsheet.md](docs/tmux-cheatsheet.md) | tmux keybindings and usage reference |
| [fzf-tab-completions.md](docs/fzf-tab-completions.md) | Fuzzy completion setup with previews |
| [CHANGELOG.md](CHANGELOG.md) | Full history from 2018 to present |

## Highlights

**System**

- `upd` / `converge` — Converge system to desired state (bootstrap + update in one command)
- `task --list` — See all available tasks
- `kill-port <port>` — Kill process on port
- `prune` — Find and delete small directories

**Git workflow**

- `git sync` — Delete merged local branches
- `git squash` — Squash commits for clean PRs
- `git trigger` — Re-trigger CI with amend + force push
- `git conf-dir` — Set per-directory git config (email, signing, etc.)
- `fm` / `fr` — Fuzzy merge/rebase with fzf

**Worktrees** (`wt*`) — git worktree management with Zellij integration. Worktrees live in `<repo>/.worktrees/` (auto-gitignored).

- `wt` / `wt <name>` — Upsert worktree + cd (fzf picker with no args)
- `wtt` / `wtt <name>` — Upsert worktree + Zellij tab (fzf picker with no args)
- `wt -b <name>` / `wtt -b <name>` — Branch from current HEAD instead of origin/main
- `wtpr <PR>` — Upsert worktree + tab for a GitHub PR (handles forks)
- `wtrm` — Remove current worktree (cd to root + cleanup)
- `wtd <name>` — Remove worktree by name + delete local branch
- `wtp` — Prune stale worktree refs

**Media**

- `to-audio opus|flac` — Parallel audio conversion
- `embed-art` — Embed cover art into FLACs
- `imp` — Download + extract + beets import

**Files**

- `vimv` — Batch rename in $EDITOR
- `clean-dls` — Remove scene release garbage

All binaries support `--help` and have shell completions.

## Per-Directory Git Config

Set git config overrides for all repos under a directory:

```sh
cd ~/workspace/surgeventures/any-repo
git conf-dir user.email james.cleveland@fresha.com
git conf-dir user.name "James Cleveland (Fresha)"
```

Stores config in `~/.local/git.d/<path>.conf` and adds an `includeIf` to `~/.gitconfig`. Idempotent.

## Architecture Notes

**Git signing** — Commit signing via 1Password SSH agent. `user.signingkey` is per-machine (local git config).

**Tool duplication** — Some tools exist in both brew and mise intentionally:
- `sheldon` — brew for Intel (no arm64 binary), mise for Apple Silicon
- `uv` — brew only (system-wide Python tooling)

## Syncthing

```sh
brew services start syncthing
```

Web UI at `http://localhost:8384`. Stop: `brew services stop syncthing`.

## Related

- [browser-schedule](https://github.com/radiosilence/browser-schedule) — Time-based browser switching for macOS
- [gastown](https://github.com/steveyegge/gastown) — Multi-agent workspace orchestrator ([setup guide](GASTOWN.md))
