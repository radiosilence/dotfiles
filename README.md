# dotfiles

Personal dev environment. macOS and headless Linux, zsh throughout.

## Setup

**macOS:**

```sh
curl -fsSL https://raw.githubusercontent.com/radiosilence/dotfiles/main/setup-macos | zsh
```

Runs the steps that wait on a person (Xcode tools → Touch ID for sudo → mise → 1Password → gh auth → 1Password agent), then `mise bootstrap`, which clones this repo to `~/.dotfiles`, links `~/.config/mise` to `config.d/mise` and applies everything declared there. Homebrew is never installed: mise installs formulae and casks into `/opt/homebrew` itself. Re-running applies the existing checkout.

**Linux (Ubuntu/Debian, headless):**

```sh
curl -fsSL https://raw.githubusercontent.com/radiosilence/dotfiles/main/setup-linux | bash
```

bash, because zsh isn't installed yet. Shorter path — curl, git, gh and zsh from apt → zsh as the login shell → gh device-flow auth → mise → `mise bootstrap`, which installs the rest of the apt list, links the configs and installs the tools. The login shell is set with `sudo chsh` here rather than by mise, whose plain `chsh` needs a password that a box with key-only logins doesn't have. Same config, same `upd`; casks, App Store apps and the macOS steps skip themselves.

No 1Password on a headless box, so git auth is gh's credential helper over HTTPS and secrets aren't populated. If you want signed commits there, `ssh -A` in from a machine that has the agent.

**Where root is allowed:** `mise bootstrap` uses sudo for apt, to create `/opt/homebrew`, for pkg casks, and for the PAM and sudoers steps on macOS. `upd` on Linux passes `--skip packages`, so it stays under `$HOME` and can run unattended; run `mise bootstrap` after declaring a new apt package, and `mise run dotfiles:os-upgrade` to upgrade the system.

The apt list is short by design: what mise's registry lacks, plus what the scripts exec directly. Everything that *is* in the registry comes from mise. `coreutils`, `findutils`, `openssl` and `make` are macOS un-BSD-ing and have no Linux equivalent worth installing.

Run `upd` (or `converge`) anytime to update everything: it pulls this repo and runs `mise bootstrap --upgrade`.

## What's Here

- **Shell configs** — Modular zsh setup with 30+ config files, 80+ git aliases, lig completion popup
- **`scripts/`** — System maintenance, git workflow, media processing, file operations, in zsh
- **`config.d/mise`** — global mise config: tools, and the `mise bootstrap` sections for packages, roles, links and setup tasks
- **Tool management** — mise for runtimes, and for Homebrew, App Store and apt packages
- **Terminal configs** — ghostty, herdr-app, starship prompt
- **Editor configs** — helix (LSP, tree-sitter, formatters for 15+ languages), zed

## Documentation

| Doc                                                   | Description                                                  |
| ----------------------------------------------------- | ------------------------------------------------------------ |
| [cheatsheet.md](docs/cheatsheet.md)                   | Complete reference — all commands, aliases, functions        |
| [CHANGELOG.md](CHANGELOG.md)                          | Full history from 2018 to present                            |

## Highlights

**System**

- `upd` / `converge` — Converge system to desired state (bootstrap + update in one command)
- `mise bootstrap --dry-run` — What `upd` would change
- `kill-port <port>` — Kill process on port
- `prune` — Find and delete small directories

**Git workflow**

- `git sync` — Delete merged local branches
- `git squash` — Squash commits for clean PRs
- `fm` / `fr` — Fuzzy merge/rebase with fzf

**Worktrees** — [grove](https://github.com/radiosilence/grove) in the Herdr app creates, opens and cleans up worktrees for branches, PRs and issues. They live in `<repo-parent>/worktrees/<repo>/<name>/`, outside the repo so editors don't recurse into them.

**Media**

- `to-audio opus|flac` — Parallel audio conversion
- `embed-art` — Embed cover art into FLACs
- `imp` — Download + extract + sift import

**Files**

- `vimv` — Batch rename in $EDITOR
- `clean-dls` — Remove scene release garbage

These live in [`scripts/`](scripts/README.md) as zsh — see there for what each one
does, with examples. Nothing is sourced by path — the shell exports `FPATH`, so
a script just names the functions it wants. Output helpers live in
`scripts/lib/functions/`; the interface is declared with
[zarg](zsh-plugins/zarg/README.md), which derives parsing, `--help`, `--version`
and `--completions zsh|fish|bash` from that one declaration, so a script's
completions cannot drift from the flags it actually accepts.

## Architecture Notes

**Merging** — `git.d/merge.conf` and `git.d/attributes` route merges through mergiraf, which merges syntax trees instead of lines. GitHub does not run custom merge drivers, so merge the base in locally to clear a PR conflict.

**Git signing** — `git.d/sign.conf` sets the format, signer program and `commit.gpgsign`;
the identity half (`user.email`, `user.signingkey`, `allowed_signers`) is per-machine
and lives in `~/.gitconfig`, written by the bootstrap task from the 1Password agent
and account. Nothing key-shaped is committed, and a fresh box gets it from `converge`.

**Claude reminders** — `.claude-personal/hooks/reminders.sh` is a UserPromptSubmit hook
that reads `~/REMINDERS.md` (a free-form list of medication, meals and chores, kept out of
the repo because it is personal) and asks Haiku whether anything is due. The reminder is
added to the prompt's context, so it appears in whichever session is in use and not in idle
ones. Today's state (what was done, snoozes, past reminders) lives in
`~/.local/state/claude-reminders/` and is shared by all sessions, so marking an item done in
one stops reminders for it in all of them. Haiku is asked at most once per 15 minutes
(`REMINDERS_INTERVAL`, in seconds) across all sessions; the other prompts only update a
timestamp. Without `~/REMINDERS.md` the hook does nothing.

**Bootstrap layout** — `mise bootstrap` applies `config.d/mise` in a fixed order: packages, system files, repos, dotfiles, tools, then the `bootstrap` task. Everything runs on every `upd`, and each part changes only what differs.

- `conf.d/04-packages.toml` holds what every machine gets. Unprefixed keys install through apt on Linux and brew on macOS. mise's brew manager also runs on Linux, so every `brew:` and `brew-cask:` entry carries `os = "macos"`: formulae would install into Linuxbrew, and a cask with no Linux build fails there rather than being skipped.
- `roles/*.toml` are optional package sets. A machine picks them with `include` in its gitignored `config.local.toml`, which the first bootstrap creates from `config.local.toml.template`, and one-off packages go in the same file. Config environments would also select each role, but an environment chosen in the global `miserc.toml` also loads every project's `mise.<env>.toml` and reaches project tasks as `MISE_ENV`, and role names such as `dev` and `work` would collide there.
- `conf.d/05-dotfiles.toml` links `config.d` into `~/.config` and `.claude-personal` into `~/.claude-personal`, and clones grove. Application directories are linked whole, so what an application writes lands in the checkout; herdr-app keeps state beside its config, so its tracked files are linked one by one, as any new `config.d` directory without an entry would be. The work profile is local-only, so its links live in `config.local.toml` on the machines that have one: mise stops on a missing source.
- `tasks/bootstrap` holds what no section can declare: the PAM edit with its revert, Rosetta, git signing from 1Password, the SSH remote and agent, the gitconfig include and Claude Code. It runs on every bootstrap, so each step checks first.

Casks that Homebrew installed before the switch stay Homebrew's: mise counts them as installed and never upgrades them, so a post-packages hook runs `brew upgrade --cask --greedy` wherever `brew` exists. mise's brew manager runs only on Apple Silicon, so an Intel Mac gets casks and App Store apps but no formulae.

## Syncthing

```sh
syncthing serve --no-browser
```

Web UI at `http://localhost:8384`. `brew services start syncthing` needs Homebrew, which a new Mac doesn't have.

## Related

- [browser-schedule](https://github.com/radiosilence/browser-schedule) — Time-based browser switching for macOS
