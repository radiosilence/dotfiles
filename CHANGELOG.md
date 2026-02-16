# Changelog

A history of this dotfiles repo from its inception in May 2018 through February 2026. 1421+ commits across 8 years of terminal tinkering, tool-hopping, and eventual convergence on a Rust-powered setup.

---

## 2026

### February

**Security & bootstrap hardening:**

- Dropped OpenSSL dependency entirely, switched to rustls (`e23f321`) — no more system OpenSSL version hell
- Comprehensive crate audit (`6a968b7`) — bug fixes, security hardening, better error handling across all binaries
- Overhauled setup process (`2234f80`) — fresh Mac goes from zero to fully configured with `./setup`, no manual steps beyond `gh auth login`
- Smarter font installation with per-font marker files, graceful sudo fallback (`56ea49a`)
- Sudo keepalive for brew + mise GH token fallback (`8c3cd9c`)

**Repo gardening:**

- Removed `crates/CANDIDATES.md` — all tools fully rewritten to Rust, doc was stale
- Removed dead Ruby configs (`.gemrc`, `.default-gems`, `.rubocop.yml`) — no Ruby managed by mise anymore
- Removed `misc/fb2k/` — Windows foobar2000 configs on a macOS repo
- Removed `config/firefox/policies.json` — not deployed by any script
- Fixed `crates/README.md` — corrected binary count (23 not 26), removed references to nonexistent justfile and banner module, listed all tools
- Renamed `setup` → `setup-macos`, updated README.md to match
- Zed: added codeowners-lsp to Proto language servers

**Maintenance:**

- Dependabot bumps: `time` 0.3.44→0.3.47, `bytes` 1.11.0→1.11.1
- Completion regen error display fix + stale cargo bin cleanup (`fc08283`)
- Zed + mise config updates (`baed0f6`, `0891aed`)
- Added `codeowners` CLI (`d493fcf`)

### January (weeks 3-4)

**Kubernetes & shell polish:**

- Simplified k8s aliases (`6885618`)
- Re-added completion helpers (`1e855ab`)
- Various maintenance (`f890449`, `6308495`)

### January (weeks 1-2) — The Great Mise Migration

A massive push to move tools from Homebrew to mise's `github:` backend. ~40 commits in two days.

**Tool migration (`Jan 9-10`):**

- Migrated gh, ripgrep, and others to mise `github:` backend (`ed6474d`, `b7f9066`, `ffab5a7`)
- Moved npm-based tools (prettier, etc.) from brew to mise (`9fcd37f`)
- Used `ubi:` backend for some edge cases (`b161453`)
- Removed Vercel CLI (`07904ff`), deprecated XLD, uninstalled postgresql@14 (`ae3de8e`)
- Moved btop/terraform back to brew where mise was flaky (`985b8a7`), then to mise core (`c493cc5`)
- Renamed mpv to stolendata-mpv for custom build (`284177b`)
- Documented all mise tool entries with comments (`8a174bc`, `e913a1f`)
- Fixed unicode in starship path truncation (`56b3adb`)

**New tools:**

- `update-ffmpeg` — downloads optimized ffmpeg builds from martin-riedl.de, integrated into `upd` (`f07c2af`, `1d7b586`, `7abbc45`, `917a077`)
- Removed ttfautohint, swiftformat (`63b4a08`, `26e0023`)

**Zed & editor:**

- Preview features enabled, new extensions, ruby formatter (`8a96692`)
- Prefer `zed --wait` as `$EDITOR` (`e7c6d84`)

**Zsh overhaul (`Jan 13`):**

- Renamed `conf.d` files with cleaner numbering scheme and `prelude` prefix (`fad499e`)
- Simplified `.zshrc` — alphabetical ordering instead of hardcoded loads (`43e7c2f`)
- Renamed `performance.zsh` to `shell.zsh`, consolidated completions (`db185a5`)
- Switched aws-vault to ByteNess fork (`e0c511e`)
- Added 1Password plugins (`3d7a3e3`)
- Fixed deprecated config (`34807a8`), switched back to tombi (`84dc901`)
- Evaluated GH token properly (`6cfb913`)

**Kubernetes fzf-tab completions (`Jan 13`):**

- Added fzf-tab pod completion to all k8s commands (`79a6bd6`)
- `klg` with pod preview (`457c9fd`)
- `kkp` — kill pods with fzf multi-select (`99dd076`)
- `kcme` (edit configmap) and `ksv` (view secret) (`1a34f6f`)
- Added k8s commands to cheatsheet (`a0e7a49`)

**Intel Mac support (`Jan 15`):**

- Added `macos-x64` binary target (`8bc4cb7`)
- Sheldon brew fallback for Intel Macs (`cf50916`)
- Link dotfiles FIRST before other steps (`1ce7f77`)
- Removed tesseract, added aria2 (`8191478`)

**Documentation:**

- Comprehensive cheatsheet (`ce1ddff`), command docs, utils aliases (`a78fee0`)
- yt-dlp nightly, gh keyring alias, fzf-tab docs, tokei via brew (`c04b627`)
- Harper-ls dictionary additions (`6e17661`)
- Misc mise tweaks: 30m cache, fastmail tools (`53abbe5`)
- Cargo update, added uv for mise pipx backend (`869ba2e`, `7472431`)
- Added fastmail-cli completions (`2839c45`)

---

## 2025

### December

**Quiet month — polish and fixes:**

- Brew bundle now runs interactively for sudo prompts, fixed output formatting, added cargo progress display (`338be96`, `10e5946`)
- Updated all deps, bumped zip to v7 (`9d9a70b`)
- `--greedy` flag for brew upgrade to update auto_updates casks (`851cbcd`)
- **libgit2 auth workaround**: `git-trigger` and `git-sync` now shell out to git because libgit2's HTTPS auth is broken (`48f8131`, `5ea4538`)
- Less aggressive Rust binary rebuilding (`51370e5`)
- Tried tsgo, added additional ripgrep config (`71f2ea6`, `772e729`)

### November — THE MONTH (Week-by-Week)

The biggest month in the repo's history. ~140 commits. Everything got rewritten in Rust.

#### Nov 25-26 — Cleanup & Completions

- Stripped banner cruft, fixed garbage tests (`99a6748`)
- Hardened Dockerfile security (`5a69b7a`)
- Rewrote `install_fonts` natively in Rust (`f2fe3fd`)
- Removed dead lib modules, killed banner module — inline colored output instead (`44178d5`, `80feab8`)
- Sexy completions: fzf-tab + previews + styling (`39e7f09`)
- Fixed autocomplete and npm-completions (`af3684f`, `91e0af7`)

#### Nov 19-21 — Stabilization

- Massive code deletion — removing old shell scripts replaced by Rust (`23d5070`, `6e4ecbb`)
- Built nice command wrappers (`8e85880`)
- Error handling improvements, clippy fixes (`38fde91`, `1f0d6b4`)
- Fixed parallel output mangling — collect results and print at end (`c44eff9`)
- Inlined everything, fixed stderr stealing (`129ff60`, `f41b9bb`)
- Made clippy a pre-push hook (`82b2f64`)
- Added npm completions (`cfc9033`)
- Fixed `imp`, `gen-diff`, `url2base64` (`63872b3`, `f2cc59c`, `9577c26`)
- Consistent anyhow usage across all binaries (`c25e461`)

#### Nov 17-18 — The Marathon (100+ commits in two days)

**PR #6: Improve dotfiles maintainability** (`49b5e2f`)
**PR #7: Rewrite core utilities in Rust** (`36c85cd`) — the big bang. All custom tools rewritten:

- `upd` — system updater with parallel execution, spinners, structured output
- `prune` / `prune-gen` — directory cleanup with size thresholds
- `git-sync`, `git-trigger`, `git-squash` — git workflow tools
- `kill-port`, `vimv`, `imp`, `to-audio`, `embed-art`, `clean-exif`, `clean-dls`
- `gen-diff`, `url2base64`, `echo-to-file`, `parallel-dl-extract`
- `install-font-macos`, `install-terminfo`, `unfuck-xcode`, `regen-zsh-completions`

**PR #8: Replace CLI wrappers with native Rust** (`bc91818`, `0ce9cdf`)
**PR #9: Port install and setup-macos to Rust** (`2367271`)

**Key technical evolution during the marathon:**

- Fixed clippy warnings, bootstrap function (`e6a3d47`)
- Removed `--quiet` and `--force` from cargo install (`787d51e`, `8d3af1b`)
- Parallel completion generation, smart upd bootstrap (`dceb577`)
- Simplified upd — sequential sudo tasks, no spinners initially (`38d3f10`)
- Self-healing upd, removed brew bundle temporarily (`6aaf6eb`)
- Moved `tooling-rust/` to `crates/` for idiomatic layout (`a61d55a`, `fdb44d0`)
- Added comprehensive test suite (`b6d0875`)
- Consolidated duplicated code, improved patterns (`2be83cf`)
- Removed unused deps: glob, image, serde, sysinfo, thiserror, tokio, tracing (`a06a0ca`)
- Unified setup: single `./setup` command for all platforms (`cf198fe`)
- Merged setup into `upd` — one idempotent command for everything (`8b8f4c9`)
- Replaced mas with casks where possible (`009e486`)
- Built live progress display for brew bundle (`7c4f916`)
- Background thread I/O — never block main thread (`95693e3`)
- "Weebification" phase — cyberpunk aesthetic with colored output and banners (`6c8a4fb`..`b6207a6`)
- Bumped all Rust deps to latest (`776af26`)
- Added Rust test workflow and CI (`cfd3b90`, `17115ff`)

#### Nov 15 — Pre-Rewrite

- Last "dumb" commit before the storm (`6581364`)

### October

**Cleanup and gardening:**

- Various small updates, removed cargo bin thing (`e9febfa`, `b162020`)
- Fixed beets config (`296f734`, `df1acf9`)
- Removed AI-related brew packages (`c2d6ead`), deleted annoying formula (`f38032e`)
- Env tweaks, simplifications (`f4a2290`, `c0ae182`)
- Updated Zed settings (`1084b71`), removed old cruft (`d2eb56e`)
- Removed dumb repos from mise config (`af95913`)

### September

No commits.

### August

No commits.

### July — Tools & Tinkering

**`rip-cd` — Audiophile CD ripping tool (`Jul 5`):**
Built an entire Go-based CD ripping tool with MusicBrainz integration, FLAC encoding, config system, fish completions, Homebrew formula. Went through multiple iterations: Python helper → Go CLI → audiophile enhancements (`#3`). Then deleted the whole thing and moved it to its own repo (`4681d9d`). Classic.

**`browser-schedule` — Time-based default browser switching (`Jul 27`):**
Another tool built, iterated, and eventually extracted. Started as a shell script, became a Go tool, then got rewritten in Swift because native macOS APIs. Went through JSON → TOML config, added night shift support, Package.swift, unified logging. Then removed from dotfiles to become its own package (`9bb9171`).

**Audio tools (`Jul 8`):**

- `clean-exif` — strip EXIF from images (`cc272b8`)
- `embed-art` — embed cover.jpg into FLAC files with parallel processing (`cc272b8`, `50976f7`)
- `extract-exif-from-flac` — pull embedded metadata (`a1c524a`)

**Other:**

- `sleep-report` — macOS sleep/wake analysis in Go (`95d489d`)
- `sudo-ask-pass` — 1Password sudo integration (`199ca6b`), then a full sudo binary override (`e666d71`)
- Harper-ls dictionary for prose linting in Zed (`92390e1`)
- Starship prompt: git committer display, icons, better ordering (`1ad40a6`, `927b9d2`, `67c93c5`)
- Claude Code integration — `.claude/CLAUDE.md` added (`a193ddf`)
- Alacritty config re-added (`5c74e3d`)
- Brewfile AI-assisted reorganization (`55936f5`)
- Added steam cask (`1f24957`)
- fcloud completions (`6fe3177`)

### July (early) — upd Improvements

- Refactored upd: simplified, removed over-engineering (`be805ee`, `#15`)
- Added `upd doctor` command for system health checks (`e87a9d2`, `#16`)
- Various Perl/Zed updates (`c0288f7`)

### June — Brewfile & Tool Gardening

**Fastmail CLI (`Jun 2`):**
Built `fastmail-cli` in Go — JMAP email search, send, manage identities. Multiple iterations in a single day: initial tool → test script → send functionality → sent folder copying → Homebrew formula/tap → panic fixes. Later moved to own repo (`e65caeb`).

**Brewfile management (`Jun 7` — 20+ commits in one day):**

- Experimented with simpler brewing, more aggressive updates (`56c5f05`, `c268933`)
- Made casks greedy... then discovered greedy only works as upgrade arg (`d30e27b`)
- Migrated tools between brew/mise: starship, buf, rust-analyzer to brew (`f58c5e3`, `a917dba`, `97ae2ba`)
- Made pnpm a node dep not a mise one (`7d39eef`)
- Added/removed solargraph, rubocop fixes (`232350e`, `f518699`, `d50b3a6`)
- Elixir format-on-save with mix because elixir-ls is "fucking terrible" (`e90641e`)
- Removed ruby LSP (`0ec33f4`)
- Added default Go packages file (`0a130a6`)

**Other:**

- Added lefthook for pre-commit hooks (shellcheck, rubocop) (`2d32c58`)
- Added/removed uv (`e8c820d`, `648b584`)
- Turso, biome re-added (`2c593b1`)
- K9s config added
- Various package management (`318a598`, `9ed369f`)
- Fixed yt-dlp and other scripts (`300f7fa`)

### May — Fish AI & Claude

**Fish AI plugin setup (`May 28`):**

- Configured fish-ai with 1Password API key integration (`f4e0c9c`)
- Bulletproof setup and install scripts (`119f2a6`)
- Switched model, removed old function, added uv (`86e3b36`)

**Other:**

- Added Claude Code (`a2d007d`)
- Various brew tools and alias fixes (`ab20f32`, `463b077`)
- Some AI-related brew search tools (`6067f7c`)

### April — Spring Cleaning

- Added git update command (`ef03032`)
- Added fzf (`9879585`)
- Temporarily disabled mas (`a5f7b13`)
- Moved beets config, fixed it (`bdaceee`, `8c75c5a`)
- Removed Erlang and Elixir from mise — too flaky (`da618ee`, `71b3dac`)

### March

Quiet month — just periodic `update` commits for config tweaks and dependency bumps.

### February

Continued periodic updates. Notable:

- Pinned biome version (`95e0e6e`)
- Various cleanup (`a5a5028`)

### January — The Fish Experiment & Great Purge

**Dec 31 2024 / Jan 1 2025 — Nuclear option** (`a12e4ce`):
Deleted the entire `.zsh.d/` directory (819 lines), `.zshrc`, sheldon config, vimrc, alacritty config, kitty config, terminal.app profile, tmux default config. Massive purge of accumulated cruft.

**Fish shell migration (Jan 1-15):**

- Full fish config under `config/fish/` with `conf.d/` modules
- Fish functions: `upd`, `imp`, `prune`, `opts`, `fonts!`, `fco`, `fm`, `fr`, `taketmp`, `using`
- Fish completions for kubectl, docker, gitleaks
- Broot file manager with custom verbs and dark theme
- Btop config added
- Git config restructured into `git.d/` (core, diff, lfs, merge as separate files)
- SSH config moved to `ssh.d/` (basic, harden)
- Misc snippets moved to `misc/`
- Prune script rewrote: Python → shell (multiple iterations)
- Yazi file manager added (`6e71eaa`, `a8e10f0`)

**Script cleanup (Jan 10):**

- Deleted `dl-opus`, `yt-opus`, `make-cd-quality`, `make-fake-flacs` — dead scripts
- Fixed `to-flac`, `to-opus`, `kill-port`, `install-font`
- Moved `fco` from bin to fish function
- Reimplemented git fzf stuff in fish (`fm`, `fr`)
- Added `set -e` / `set -u` to all shell scripts

**Terminal config (Jan 14):**

- WezTerm keybinding overhaul
- Ghostty config updates, Monokai Pro theme tweaks
- Broot config refined

**Other:**

- Helix config updated, removed efm (`f295449`)
- Parallel flac conversion (`91c0ada`)
- Mise config additions
- README rewritten multiple times

---

## 2024 - Mise Migration & Brewfile Era (270 commits)

Major shift from asdf to mise for runtime management, and from ad-hoc `setup-macos.zsh` to a proper Brewfile.

**Package management revolution:**

- Adopted mise (`08f7820`, May) — replaced asdf entirely
- Created Brewfile (`f43ccf9`, June) — replaced manual `setup-macos.zsh` brew commands
- Migrated alacritty config to TOML format (`fff401e`)
- Removed Vundle/vimrc (`63aab60`) — vim era officially over

**Shell evolution:**

- Sheldon ordering fixed with numbered prefixes (01-brew, 02-sheldon, 03-mise, etc.)
- `upd` script created (`f1a065b`, Dec) — renamed from `updates`, handles everything
- `bin/` directory grew: `kill-port`, `vimv`, `prune`, `imp`, `fco`, and various music scripts
- Zoxide replaced bd for directory jumping

**Editor:**

- Zed config matured throughout the year
- Helix config still maintained

**New tools:**

- `prune-small-dirs` (later `prune`) — find tiny directories to delete
- `yt-aac` / `yt-opus` — youtube-dl wrapper scripts
- Music sync scripts (`pull-music`, `push-music`, `imp`) for SMB/rsync workflows
- `cloud-armour-upsert-ip` — GCP security policy management (later removed)
- Tailscale completions
- 1Password CLI plugin integration

**Brewfile management** became the primary way to track system packages — casks, formulae, Mac App Store apps all declared.

## 2023 - The Great Plugin Manager Migration (38 commits)

**September 20 was chaos** — tried antidote, sheldon, and zephyr all in one day:

- Tried antidote (`6861313`) — replaced zgenom
- Added sheldon config (`216f142`) — liked it better
- Removed antidote (`e52de0e`) — sheldon won
- Cleaned out years of cruft: iterm2 integration, color.sh, ffmpeg notes, weather function, old completions

**Helix editor** entered the picture (`b171eb2`, May):

- Config for helix with language servers
- WezTerm updated for helix keybindings
- Git editor switched away from VS Code

**SSH agent** replaced with 1Password (`b97686f`, July) — removed gpg-agent and ssh-agent scripts.

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

**Starship prompt** replaced p10k (`79205e6`, Feb) — removed 1500+ lines of p10k config in one commit. Much simpler.

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

**Git delta** adopted for diffs (`323b80c`, October) — syntax-highlighted, side-by-side diffs.

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
- Switched to antibody (`3e89d63`, Feb) — much faster
- Tried spaceship prompt (`a387173`, May) — "no it was slow as shit" (`f249d8f`)
- Adopted powerlevel9k/purepower (`0161322`, May)

**Terminal emulator journey:**

- Alacritty (from day 1, 2018)
- Hyper added (`6fa76ab`, Feb) then removed (`05d0dac`, May) — "goodbye hyper"
- Terminal.app profile added (`fabcf1f`, May)
- iTerm2 profile + shell integration (`c10d8e3`, May)
- Kitty added (`62cea0c`, Aug) with custom config

**Package management:**

- asdf adopted (`04721bc`, Feb) — replaced manual nvm/rbenv/nodenv
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

- `.alacritty.yml` — GPU-accelerated terminal with Tomorrow Night Bright theme
- `.tmux.conf` — Prefix rebound to Ctrl-A, mouse mode, tpm plugins (resurrect, continuum)
- `.zpreztorc` — Prezto with sorin theme, emacs keybindings, SSH identities
- `.zshrc` — Pure prompt, nodenv, Go, coreutils, basic aliases
- `install.sh` — Simple symlink loop
- `vscode.json` — Input Mono font, tslint, eslint, 80-char ruler

**Key moments:**

- Added gitconfig with `git up` (pull --rebase --autostash) (`73cb160`)
- Added vimrc with Vundle, typescript-vim, fugitive (`f135ba2`)
- Encrypted workspace sparsebundle automount alias
- **November overhaul**: Removed prezto, switched to zplug, added pure prompt port, emacs keybindings, history module. The `.zshrc` went from simple to structured.

---

_Generated from 1421+ commits, May 2018 — February 2026._
