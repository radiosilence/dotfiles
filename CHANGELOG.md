# Changelog

A history of this dotfiles repo from its inception in May 2018 through February 2026. 1421 commits across 8 years of terminal tinkering, tool-hopping, and eventual convergence on a Rust-powered setup.

## 2026 (Q1) - Rust Hardening & Zero-Friction Bootstrap

**Setup overhaul** (`2234f80`): Complete rewrite of the bootstrap process. Fresh Mac goes from zero to fully configured with a single `./setup` command - Xcode CLI tools, Rosetta 2, Homebrew, Rust via mise, all binaries built, `upd` run automatically. No manual steps beyond `gh auth login`.

**Security**
- Switched from OpenSSL to rustls (`e23f321`) - no more system OpenSSL dependency hell
- Comprehensive crate audit (`6a968b7`) - bug fixes, security hardening, better error handling across all 23 binaries
- Sudo keepalive for brew, mise GH token fallback (`8c3cd9c`)
- Dependabot bumps for git2, time, bytes crates

**Tooling**
- `update-ffmpeg` tool for optimized ffmpeg builds from martin-riedl.de
- Massive mise migration - moved tools from brew to mise `github:` backend (gh, ripgrep, btop, etc.)
- Added `codeowners` CLI, `fastmail-cli` completions
- Kubernetes aliases simplified, fzf-tab pod completions added
- Zed config updates, preview features enabled
- Zsh conf.d files renamed with cleaner numbering scheme
- `docs/cheatsheet.md` - comprehensive command reference
- Intel Mac support with brew/sheldon fallbacks

## 2025 - The Rust Rewrite & Fish Experiment

The biggest year by far (646 commits). Started with a fish shell experiment, ultimately returned to zsh, and rewrote nearly every shell script into compiled Rust binaries.

### Q4 2025 - Rust Workspace (`fdb44d0` onwards)

**The big one.** All custom tools consolidated into a Cargo workspace under `crates/`:

- **`upd`** - System updater (brew bundle, mise, cargo, dotfile linking, completions regen). Parallel execution with spinners and structured output
- **`prune`** - Find and delete small/empty directories with size thresholds
- **`prune-gen`** - Generate test directory structures for prune testing
- **`git-sync`** - Delete local branches already merged to main
- **`git-trigger`** - Re-trigger CI with empty amend + force push
- **`git-squash`** - Interactive squash to N commits
- **`kill-port`** - Find and kill process on a given port
- **`vimv`** - Batch rename files in $EDITOR
- **`imp`** - Download, extract, beets import pipeline
- **`to-audio`** - Parallel audio conversion (opus/flac)
- **`embed-art`** - Embed cover.jpg into FLAC files
- **`extract-exif-from-flac`** - Pull embedded metadata
- **`clean-exif`** - Strip EXIF from images
- **`clean-dls`** - Remove scene release junk from filenames
- **`gen-diff`** - Generate diffs between git refs
- **`url2base64`** - Fetch URL content and base64 encode
- **`echo-to-file`** - Write stdin to file (for scripts)
- **`parallel-dl-extract`** - Parallel download and extract archives
- **`install-font-macos`** - Native font installation
- **`install-terminfo`** - Install custom terminfo entries
- **`unfuck-xcode`** - Reset Xcode state when it gets stuck
- **`regen-zsh-completions`** - Regenerate completions for all tools

Key technical decisions: anyhow for error handling, rayon for parallelism, indicatif for progress display, clap for CLI parsing.

Later fixes: libgit2 HTTPS auth was broken so git-trigger/git-sync shell out to git instead (`48f8131`, `5ea4538`).

### Q3 2025 - Packages & Scripts

- **`rip-cd`** - Audiophile CD ripping tool in Go (later removed)
- **`browser-schedule`** - Time-based default browser switching in Swift (later moved to own repo)
- **`sleep-report`** - macOS sleep/wake analysis tool in Go
- `sudo-ask-pass` - 1Password sudo integration
- `clean-exif`, `embed-art`, `extract-exif-from-flac` scripts (later rewritten in Rust)
- Claude Code integration (`.claude/CLAUDE.md`)
- Alacritty config re-added
- Harper-ls dictionary for prose linting in Zed
- Starship prompt heavily customized with icons and git info

### Q2 2025 - Fish AI & Fastmail CLI

- **`fastmail-cli`** - Go tool for JMAP email (search, send, manage identities). Got its own Homebrew formula
- Fish AI plugin setup via fish-ai with 1Password API key integration
- Brewfile reorganized with `greedy` upgrade flags
- Lefthook for pre-commit hooks (shellcheck, rubocop)
- K9s config added
- Zed extensions: biome, elixir format-on-save
- Migrated more tools from mise to brew (starship, buf, rust-analyzer)

### Q1 2025 - The Fish Experiment & Great Cleanup

**Nuclear option on Dec 31, 2024** (`a12e4ce`): Deleted the entire `.zsh.d/` directory (819 lines), `.zshrc`, sheldon config, vimrc, alacritty, kitty, terminal.app profile, tmux default config, vscode settings, yarn.lock. Massive purge.

**Fish shell era** (Jan 1 - ~Nov 2025):
- Full fish config under `config/fish/` with `conf.d/` modules
- Fish functions for `upd`, `imp`, `prune`, `opts`, `fonts!`
- Fish completions for kubectl, docker, gitleaks, pnpm, houston, rip-cd, fastmail-cli
- Broot file manager config with custom verbs and dark theme
- Btop config added
- Git config moved to `git.d/` with separate files (core, diff, lfs, sign, delta)
- SSH config moved to `ssh.d/` (basic, harden)
- Prune script went through fish -> lua -> python -> sh -> finally Rust

**Return to zsh**: Eventually came back, keeping the `conf.d/` modular approach but in zsh.

## 2024 - Mise Migration & Brewfile Era (270 commits)

Major shift from asdf to mise for runtime management, and from ad-hoc `setup-macos.zsh` to a proper Brewfile.

**Package management revolution:**
- Adopted mise (`08f7820`, May) - replaced asdf entirely
- Created Brewfile (`f43ccf9`, June) - replaced manual `setup-macos.zsh` brew commands
- Migrated alacritty config to TOML format (`fff401e`)
- Removed Vundle/vimrc (`63aab60`) - vim era officially over

**Shell evolution:**
- Sheldon ordering fixed with numbered prefixes (01-brew, 02-sheldon, 03-mise, etc.)
- `upd` script created (`f1a065b`, Dec) - renamed from `updates`, handles everything
- `bin/` directory grew: `kill-port`, `vimv`, `prune`, `imp`, `fco`, and various music scripts
- Zoxide replaced bd for directory jumping

**Editor:**
- Zed config matured throughout the year
- Helix config still maintained

**New tools:**
- `prune-small-dirs` (later `prune`) - find tiny directories to delete
- `yt-aac` / `yt-opus` - youtube-dl wrapper scripts
- Music sync scripts (`pull-music`, `push-music`, `imp`) for SMB/rsync workflows
- `cloud-armour-upsert-ip` - GCP security policy management (later removed)
- Tailscale completions
- 1Password CLI plugin integration

**Brewfile management** became the primary way to track system packages - casks, formulae, Mac App Store apps all declared.

## 2023 - The Great Plugin Manager Migration (38 commits)

**September 20 was chaos** - tried antidote, sheldon, and zephyr all in one day:
- Tried antidote (`6861313`) - replaced zgenom
- Added sheldon config (`216f142`) - liked it better
- Removed antidote (`e52de0e`) - sheldon won
- Cleaned out years of cruft: iterm2 integration, color.sh, ffmpeg notes, weather function, old completions

**Helix editor** entered the picture (`b171eb2`, May):
- Config for helix with language servers
- WezTerm updated for helix keybindings
- Git editor switched away from VS Code

**SSH agent** replaced with 1Password (`b97686f`, July) - removed gpg-agent and ssh-agent scripts.

**Other changes:**
- exa/lsd aliases for ls replacement
- pnpm support added
- Rancher Desktop path
- Java/Android configs broken into separate files
- Bun runtime support

## 2022 - Steady State (32 commits)

Quietest year. The setup was mostly stable.

- Warp terminal explored briefly (`08ba53c`)
- WezTerm color improvements and tmux integration
- GPG agent + Yubikey switching script
- bat, jwt, and cloudflare helper aliases
- Delta diff config refined
- Terraform conditional loading
- pyenv added
- lsd `tgree` alias
- K8s and GKE aliases
- Brew path fixes for M1 vs Intel

## 2021 - M1 Migration & Prompt Overhaul (73 commits)

**Starship prompt** replaced p10k (`79205e6`, Feb) - removed 1500+ lines of p10k config in one commit. Much simpler.

**Plugin manager: zgenom** replaced antibody (`f831820`, Jan):
- Added zsh-autocomplete, forgit, direnv
- History and directory modules
- Comprehensive completion setup

**WezTerm** entered (`b0e9403`, April) alongside kitty and alacritty.

**M1 Apple Silicon migration** (`4597b37`, June):
- Homebrew path changes (`/opt/homebrew` vs `/usr/local`)
- Setup script simplified
- Architecture-conditional paths

**Other notable changes:**
- ffmpeg notes and compress functions
- SSH config refactored (gpg-agent removed in favor of ssh-agent)
- Zoxide and broot adopted
- youtube-dl wrapper scripts
- fcp (fast copy) adopted, removed GNU coreutils ls aliases
- AWS upload helpers
- tmux config enhanced

## 2020 - The Quarantine Year (128 commits)

Lots of activity. Working from home energy.

**Powerlevel10k** adopted (`c538b92`, April):
- Replaced pure prompt with p10k lean theme
- Nerd Font required (switched to Fantasque Sans Mono)
- Transient prompt, k8s context display

**Setup script** introduced (`a46ad3f`, April):
- First `setup.zsh` with brew, asdf, gem installs
- Font installation

**Git delta** adopted for diffs (`323b80c`, October) - syntax-highlighted, side-by-side diffs.

**Major shell restructuring** (Dec 31 marathon session):
- `is_cmd` helper function
- Renamed `00-setup.zsh` to `00-prelude.zsh`
- Install script refactored into `.zsh.d/install.zsh`
- `updates.zsh` function for brew + antibody + asdf updates
- `dotfiles-dir` env var, bin path added
- `gpg-copy-id` utility script

**Other additions:**
- Nix support (conditional)
- GPG agent configuration
- Beets music import pipeline
- LS colors via lsd
- FZF expanded with file preview, git helpers
- Wasmtime, cargo paths
- `.gitattributes` for diff drivers

## 2019 - Modularization & Terminal Hopping (105 commits)

The year of trying every terminal emulator and finally organizing the shell config.

**Shell config split** (`196ae37`, June):
- Monolithic `.zshrc` broken into `.zsh.d/` directory
- Numbered files for load order: `00-setup`, `01-path`, `02-completions`, etc.
- Git aliases got their own file (245 lines!)
- Yarn, fzf, history as separate modules

**Plugin manager journey:**
- Started with prezto (inherited from 2018)
- Switched to zplug (Nov 2018)
- Switched to antibody (`3e89d63`, Feb) - much faster
- Tried spaceship prompt (`a387173`, May) - "no it was slow as shit" (`f249d8f`)
- Adopted powerlevel9k/purepower (`0161322`, May)

**Terminal emulator journey:**
- Alacritty (from day 1, 2018)
- Hyper added (`6fa76ab`, Feb) then removed (`05d0dac`, May) - "goodbye hyper"
- Terminal.app profile added (`fabcf1f`, May)
- iTerm2 profile + shell integration (`c10d8e3`, May)
- Kitty added (`62cea0c`, Aug) with custom config

**Package management:**
- asdf adopted (`04721bc`, Feb) - replaced manual nvm/rbenv/nodenv
- Homebrew became primary installer

**Fonts:**
- Input Mono (original)
- SF Mono (`e01363b`, Jan)
- Monokai Pro colors (`1b2852d`, Mar)

**Other:**
- Rust tooling added to PATH
- SDKMAN for Java
- FZF integration with preview, docker container checkout (`8a37f6c`)
- Git config moved to separate `git.conf`
- VS Code settings maintained
- cheat.sh alias
- tmux copy-paste fixes, plugin manager (tpm)

## 2018 - Genesis (36 commits)

**May 2**: Initial commit (`ca072c4`). The OG files:
- `.alacritty.yml` - GPU-accelerated terminal with Tomorrow Night Bright theme
- `.tmux.conf` - Prefix rebound to Ctrl-A, mouse mode, tpm plugins (resurrect, continuum)
- `.zpreztorc` - Prezto with sorin theme, emacs keybindings, SSH identities
- `.zshrc` - Pure prompt, nodenv, Go, coreutils, basic aliases
- `install.sh` - Simple symlink loop
- `vscode.json` - Input Mono font, tslint, eslint, 80-char ruler

**Key moments:**
- Added gitconfig with `git up` (pull --rebase --autostash) (`73cb160`)
- Added vimrc with Vundle, typescript-vim, fugitive (`f135ba2`)
- Encrypted workspace sparsebundle automount alias
- **November overhaul**: Removed prezto, switched to zplug, added pure prompt port, emacs keybindings, history module. The `.zshrc` went from simple to structured.

---

*Generated from 1421 commits, May 2018 - February 2026.*
