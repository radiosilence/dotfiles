# dotfiles

Personal dev environment. macOS, zsh, Rust tooling.

## Setup

```sh
curl -fsSL https://raw.githubusercontent.com/radiosilence/dotfiles/main/setup-macos | zsh
```

Sequential bootstrap (xcode → Touch ID for sudo → brew → 1Password → clone) and then hands off to `task converge` for everything else — mise, symlinks, Rust binaries, completions, fonts, gh auth. Idempotent; re-running skips what's already done.

Run `upd` (or `converge`) anytime to update everything. Tasks that need gh auth poll silently until ready.

## What's Here

- **Shell configs** — Modular zsh setup with 30+ config files, 80+ git aliases, fzf-tab completions
- **Rust binaries** — System maintenance, git workflow, media processing, file operations
- **Taskfile.yml** — DAG-based system management (bootstrap, update, completions, fonts)
- **Tool management** — mise for runtimes, role-based Brewfile for system packages (`brewfiles.d/`)
- **Terminal configs** — zellij, ghostty, starship prompt
- **Editor configs** — helix (LSP, tree-sitter, formatters for 15+ languages), zed

## Documentation

| Doc                                                   | Description                                                  |
| ----------------------------------------------------- | ------------------------------------------------------------ |
| [cheatsheet.md](docs/cheatsheet.md)                   | Complete reference — all commands, aliases, functions        |
| [new-tools.md](docs/new-tools.md)                     | Modern CLI replacements (dust, procs, delta, xh, oha, tokei) |
| [fzf-tab-completions.md](docs/fzf-tab-completions.md) | Fuzzy completion setup with previews                         |
| [CHANGELOG.md](CHANGELOG.md)                          | Full history from 2018 to present                            |

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

**Worktrees** (`wt*`) — git worktree management, as local zsh plugins under `zsh-plugins/`: `wt-core` plus a backend per multiplexer (`wt-herdr`, `wt-zellij`). Worktrees live in `<repo-parent>/worktrees/<repo>/<name>/`, or `~/.worktrees/<repo>/<name>/` for repos sitting directly in `$HOME` — outside the repo either way, so editors don't recurse into them.

- `wt` / `wt <name>` — Upsert worktree + cd (fzf picker with no args)
- `wtt` / `wth` — Same, opening a Zellij tab / herdr workspace instead
- `wt -b <name>` — Branch from current HEAD instead of origin/main
- `wtpr <n|url>` — Worktree for a GitHub PR **or** issue (handles forks); `wti` for issues only, `wtpr-pick` to fzf over both
- `wtrm [name]` — Remove the worktree you're in (or a named one) + its branch
- `wtclean [-n]` — GC worktrees and branches whose PR is merged or closed, per `gh`. Keeps anything dirty

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
cd ~/workspace/acme/any-repo
git conf-dir user.email you@acme.example
git conf-dir user.name "Your Name (Acme)"
```

Stores config in `~/.local/git.d/<path>.conf` and adds an `includeIf` to `~/.gitconfig`. Idempotent.

## Architecture Notes

**Git signing** — Commit signing via 1Password SSH agent. `user.signingkey` is per-machine (local git config).

**Tool duplication** — Some tools exist in both brew and mise intentionally:

- `sheldon` — brew for Intel (no arm64 binary), mise for Apple Silicon
- `uv` — official astral standalone installer (system-wide Python tooling)

## Syncthing

```sh
brew services start syncthing
```

Web UI at `http://localhost:8384`. Stop: `brew services stop syncthing`.

## Related

- [browser-schedule](https://github.com/radiosilence/browser-schedule) — Time-based browser switching for macOS
- [gastown](https://github.com/steveyegge/gastown) — Multi-agent workspace orchestrator ([setup guide](GASTOWN.md))
