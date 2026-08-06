# dotfiles

Personal dev environment. macOS and headless Linux, zsh, Rust tooling.

## Setup

**macOS:**

```sh
curl -fsSL https://raw.githubusercontent.com/radiosilence/dotfiles/main/setup-macos | zsh
```

Sequential bootstrap (xcode → Touch ID for sudo → brew → 1Password → clone) and then hands off to `task converge` for everything else — mise, symlinks, Rust binaries, completions, fonts, gh auth. Idempotent; re-running skips what's already done.

**Linux (Ubuntu/Debian, headless):**

```sh
curl -fsSL https://raw.githubusercontent.com/radiosilence/dotfiles/main/setup-linux | bash
```

bash, because zsh isn't installed yet. Shorter path — apt base packages → mise → clone → gh device-flow auth → `task converge`. Same Taskfile, same `upd`; the darwin-only tasks (brew, casks, Touch ID, 1Password, `use-ssh`, `secrets:populate`) skip themselves.

No 1Password on a headless box, so git auth is gh's credential helper over HTTPS and secrets aren't populated. If you want signed commits there, `ssh -A` in from a machine that has the agent.

**Where root is allowed:** bootstrap may install system packages; the Taskfile may not. `converge` runs unattended, so on Linux it stays entirely under `$HOME` — mise in `~/.local`, tools in `~/.local/share/mise`, configs symlinked into `~`. `apt:core`, `apt:upgrade` and `dnf:upgrade` exist but you run them by hand. brew is the exception that isn't one: it's user-owned and installs formulae without root, so `brew:bundle` stays in converge.

The apt list is short by design: `zsh git curl ca-certificates gh rsync gnupg unzip aria2`, plus `build-essential` to compile `crates/`. Nothing there is in mise's registry, and everything that *is* comes from mise. `core.rb`'s `coreutils`/`findutils`/`openssl`/`make` are macOS un-BSD-ing and have no Linux equivalent worth installing.

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

**Worktrees** (`wt*`) — git worktree management with Zellij integration. Worktrees live in `<repo-parent>/worktrees/<repo>/<name>/` — outside the repo so editors don't recurse into them.

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
