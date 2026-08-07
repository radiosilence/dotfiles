# Changelog

A history of this dotfiles repo from its inception in May 2018 through February 2026. 1421+ commits across 8 years of terminal tinkering, tool-hopping, and eventual convergence on a zsh-first setup.

---

## 2026

### August

**`wtclean`'s logic moved into the script:**

- The plugin defined `_wt_clean`, `_wt_pr_cache` and `_wt_fan` with `bin/wtclean` as their only caller, so every interactive shell parsed ~150 lines it would never run. The split also meant zarg parsed `--dry-run` into `$dry_run` and the script re-encoded it back into `-n` for the function to parse again — a round trip that existed purely because of the file boundary, and that needed a comment to explain its own gotcha
- Only the helpers `wtrm` and the pickers share stayed behind
- `_wt_prs` deliberately keeps its declaration beside `_wt_pr_state` rather than travelling with the code that fills it. An *undeclared* associative array turns `${_wt_prs[feat/x]}` into an arithmetic subscript, where `feat/x` is a division — so every slashed branch name died with "division by zero". Caught by testing `wtrm`'s path, not by reading


**The rest of the wt bins parse with zarg:**

- `wtclean` moved to zarg in #82; the other four were still hand-rolled, which is the drift zarg exists to prevent. All five now derive `--help`, the parser and the completions from one declaration, and unknown flags are refused with a did-you-mean rather than ignored
- Branch arguments declare `complete=_wt_branches`, reusing the function already backing the `wt` and `wtrm` compdefs instead of a second list of worktrees
- Registered in `generate:completions:plugin`, the by-path variant — plugin internals aren't on `PATH`, so the `command -v` gate the ordinary tools use would skip them silently


**`crates/` is gone — 15 binaries become 15 zsh scripts:**

- 3097 lines of Rust and **326 transitive crates** for tools that mostly shuffled argv. Ten of the fifteen shelled out to `ffmpeg`, `metaflac`, `aria2c`, `unzip`, `beet` or `exiftool` anyway, so the Rust was a progress bar wrapped around someone else's program. `git2` vendored libgit2, which is the only reason `setup-linux` installed `build-essential`; `reqwest` + rustls came along for two HTTP GETs that `curl` already does. The replacements total roughly 250 lines and need nothing that wasn't already installed
- **`task reinstall-bins` had not rebuilt anything in a long time.** Its guard was `status: ["test -f {{.DOTFILES}}/bin/clean-dls"]` — true forever after the first install, so every later edit to `crates/` was skipped silently and the cheatsheet's claim that `upd` "rebuilds rust bins" was false. Nobody noticed, which is its own argument
- `clean-exif` was the one binary doing real in-process work (`img-parts` stripping the EXIF chunk) and it still lost to `exiftool -all= -overwrite_original`, which additionally strips XMP, IPTC and ICC. When the best case for a language is beaten by a one-liner, there isn't a case
- `extract-exif-from-flac` parsed `metaflac --list` text output with a hand-rolled state machine. It is now awk, which is what awk is for

**zarg — clap for zsh, in `zsh-plugins/zarg`:**

- Every one of these scripts needs a parser *and* a compdef, and hand-written pairs drift the moment a flag is added: the parser accepts something completion never offers, or completion offers something the parser rejects. zarg takes one declaration and derives parsing, `--help`, `--version` and `--completions zsh|fish|bash` from it, which makes that failure mode unrepresentable rather than merely discouraged
- Handles `--long value`, `--long=value`, `-s value`, attached shorts (`-b192`), clustered flags (`-nk`), `--`, defaults, `env=` fallbacks, `required`, `variadic`, and `values=` sets validated before the script body runs. Unknown flags get a did-you-mean
- Fidelity across shells is uneven and that is the shells' doing: `complete=` names a zsh completion function, so fish and bash fall back to file completion there. Declared value sets work in all three
- The emitters live in a separate `completions.zsh` sourced only on demand — scripts load zarg on every invocation and generate completions about once per converge
- 32 tests in `zsh-plugins/zarg/test.zsh`, plus `zsh-plugins/zarg/check-completions.zsh`, which asserts every script's emitted completion actually parses in zsh, bash and fish. Both run in CI and on pre-push; the old `rust-tests.yml` is now `scripts.yml`

**`wtclean` uses zarg too:**

- It was already a script rather than a function — a GC pass has no reason to mutate the calling shell — so it drops its hand-rolled `[[ $1 == -n ]]` and gains `--help`, `--version`, a typo-correcting parser and the first completion it has ever had
- The rest of `wt-*` deliberately doesn't. `wt` and `wtrm` `cd`, so they must stay functions, and zarg is wrong for functions on two counts: `zarg_go` calls `exit`, which in an interactive function kills the user's shell rather than the command, and `typeset -g` would leak parsed values and the `ZARG_*` spec arrays into the session. They keep `compdef` at load time
- Needed a `generate:completions:plugin` task: `wtclean` is reached through a shell function, so `command -v wtclean` finds nothing from inside a task and the usual generator would have skipped it silently

**Behaviour that deliberately changed:**

- **`to-audio flac|opus` is a positional, not a subcommand.** The two differed by exactly one option (`--bitrate`, meaningless for lossless), so the subcommand machinery was buying nothing. `--bitrate` is now ignored for flac rather than absent
- **`prune` measures blocks, not apparent size.** `du` reports what you get back by deleting, which is the question being asked. This surfaced a matching bug in `prune-gen`, whose fixture files were sparse: a "210MB" directory read as 16KB and the fixture had quietly stopped exercising the threshold it exists to test. It writes real bytes now
- **`extract-exif-from-flac` could never report "Clean".** It substring-matched the sensitive-field list against the whole `exiftool -json` document, and exiftool always emits `"SourceFile"` — which contains `Source`. Every image came back dirty. It now asks exiftool for only the tags that matter, so an answer beyond `SourceFile` *is* the finding. Verified against a scrubbed image and one carrying GPS + Artist
- `kill-port -s` takes signal names only; `-s 9` now errors telling you to use `KILL` instead of being quietly accepted
- The warning glyph was `""` — an empty string in the Rust, so every warning line rendered with colour and no icon. It's `󰀪` now, matching the Material Design set the check and cross already come from

**Fallout:** `link:cargo` and `packager.d/cargo-config.toml` deleted, `rust` dropped from `03-tools.toml`, `~/.dotfiles/bin` off `$PATH`, cargo artefacts out of `.gitignore`. `setup-linux` loses `build-essential` and the `DOTFILES_NO_RUST` escape hatch, and gains `lsof` and `libimage-exiftool-perl` — the two things `kill-port` and `clean-exif` used to do in-process and now delegate.

**`wtclean` fans out the per-worktree work:**

- The two costs that scale with worktree count are `git status` and the removal itself. Both are per-worktree independent, so they go through GNU parallel, or `xargs -P` where it isn't installed. Concurrent `git worktree remove` turns out to be safe — each touches only its own directory under `.git/worktrees`, verified 12-way with a clean `fsck` after
- Branch deletion went the opposite way: **batched**, not parallelised. `git branch -D` takes many refs in one invocation, which is a single `packed-refs` rewrite instead of a pile of processes contending for its lock
- Both fan-out backends pass the path as a real argument rather than substituting it into a command string, so a worktree path with a space in it survives. GNU parallel needs `-q` for that, without which it re-tokenises the snippet and `sh -c` gets only the first word
- Classification now happens before any of it, so the expensive probe only runs on worktrees that are still candidates — the one you're standing in, detached checkouts and agent worktrees never get walked at all


**wt-\* helpers are zsh; `wtclean` is a script:**

- These are zsh plugins, so the `bin/` helpers had no business being bash — zsh is guaranteed present here and macOS still ships bash 3.2. Not purely cosmetic: bash's single-char read in `wt-shell`'s keep/remove prompt is `read -rsn1`, which zsh spells `read -rsk1`, and `${BASH_SOURCE[0]}` becomes `${0:A}`
- `wtclean` moved out of the plugin into `bin/wtclean`; the plugin keeps a one-line shim onto it. A function is only worth defining when it has to mutate the shell — `wt` and `wtrm` cd, a GC pass doesn't. The distinction has teeth: a shell started before an update ran a stale `wtclean` against a `wt-list` that didn't exist on disk yet, silently processed zero worktrees while reporting `removed 0, kept 0`, and still went on to delete seven branches. A script is re-read every invocation, so it cannot half-run


**`setup-linux` — headless Ubuntu/Debian boxes:**

- Everything load-bearing already lived in mise, so the port was mostly gating rather than porting. brew's real job here is casks — ghostty, fonts, 1Password, raycast — none of which a headless box wants
- **`setup-macos` never worked on a genuinely fresh machine**, and this is what surfaced it. `mise install task@latest` leaves a shim that dies with "No version is set for shim: task" — a shim only resolves if some config file *declares* the tool, and at that point in bootstrap `$DOTFILES/mise.toml` declares only lefthook and shellcheck. brew hid it for `gh` and `mise` by installing real binaries at step 4; `task` had no such cover, so the handoff to converge fell over. Both scripts now symlink the mise config before installing anything through it, and drop the `@latest` so versions come from `03-tools.toml`
- `gh` comes from apt, not mise, and auth happens *before* mise touches the network. mise reads gh's `hosts.yml` directly (`github.gh_cli_tokens`, on by default), so every release lookup from then on is authenticated and the anonymous rate limit never enters into it. Ubuntu's `gh` is a year behind, but it only has to survive bootstrap — `03-tools.toml` installs a current one and the shim takes over on `PATH`
- Auth is device flow: gh prints a code you paste on whatever machine you're actually sitting at, which is the only kind that works over SSH with no browser
- `use-ssh` is now darwin-only: the signing key lives in the 1Password desktop agent, so a headless box has nothing to switch *to*. HTTPS via gh's credential helper instead. `secrets:populate` stays darwin-only for the same reason — no desktop agent, no `op`
- `mise:ensure` lost its darwin gate and branches on brew's presence; `gh:ensure` is new, because `gh:auth` reached gh transitively through `brew:bundle` and that whole path is skipped on Linux
- **The divide: bootstrap installs system packages, the Taskfile doesn't.** `apt:upgrade` and `dnf:upgrade` were converge deps and are now manual, joining the new `apt:core`. brew is user-owned and installs formulae without root, so `brew:bundle` staying in converge isn't the same thing — `upd` running unattended is the wrong place to prompt for a sudo password. Everything converge touches on Linux lives under `$HOME`: mise in `~/.local`, tools in `~/.local/share/mise`, configs symlinked into `~`
- The apt list is everything in `core.rb` that mise's registry doesn't cover and a headless box actually wants: `zsh git curl ca-certificates gh rsync gnupg unzip aria2`. `aria2`/`unzip` are there because `parallel-dl-extract` execs `aria2c` and `unzip` rather than linking them. Left behind: `coreutils`, `findutils`, `openssl@3`, `libressl`, `make` and `curl`-the-formula exist to un-BSD macOS and Ubuntu already ships GNU ones; `parallel` turned out to be unused (`to-audio` uses rayon in-process), `fswatch` is superseded by `watchwoman`, and `node` was carrying a global npm for a `npm:` backend that nothing in the config uses
- Verified: `converge --dry` on a fresh Ubuntu 26.04 box reaches no task that shells out to `sudo`. `crates/` also builds with plain `build-essential` — `git2` is vendored and `reqwest` is on rustls, so no `pkg-config`, no `libssl-dev`
- `config.d/btop` is symlinked into `~/.config` on every machine `link:config` touches, but `btop` is a brew formula, so on Linux the config lands pointing at nothing. Left that way deliberately: aqua declares btop `supported_envs ["linux"]` and upstream ships no darwin asset, so moving it to mise would have traded a missing binary on Linux for a broken one on macOS. `tokei`'s latest release is source-only — mise would compile it via the cargo backend. Neither is worth the split; both stay on brew
- `15-brew.zsh` set `BREW_PREFIX=/usr/local` on any machine without `/opt/homebrew`, including ones with no brew at all, and prepended two nonexistent dirs to `PATH`. Returns early now
- `upd` still prompted for a sudo password on Linux after all that. The `converge` shell function pre-warmed sudo before handing off, so the prompt wouldn't get buried in parallel task output — correct while `apt:upgrade` was a converge dep, and pure noise once nothing in the DAG needed root. The audit missed it because it looked at the Taskfile, and this lives in `utils.zsh`

**Worktree cleanup asks GitHub, not git:**

- `git branch --merged` never reclaimed anything, because everything is squash-merged: the local branch shares no commit with what actually landed, so git calls it unmerged forever. `wtclean` now asks `gh` for PR state — merged or closed means the worktree and its branch go, along with orphaned branches whose worktree is already gone. Without `gh` a deleted upstream stands in, which means the same thing in practice
- One `gh pr list` up front instead of a query per branch. A dozen worktrees is a second, not a minute — it's meant to run from cron
- Five verbs collapsed to two. `wtd` was `wtrm` with a different argument, `wtp` was an alias for `git worktree prune`, and `wtpb` skipped every branch it existed to prune, because `-d` refuses on a squash-merged branch
- Dirty worktrees, the one you're standing in, and detached checkouts are never touched. `-n` dry-runs — and did not, on the first cut, which cost two already-merged branches

**wt-\* plugins: dead paths and drifted copies:**

- The plugin split (#76) left `scripts/wt-picker` and `scripts/wt-preview` behind. The zellij `alt+w` binding and the `wtt` completion preview had been pointing at nothing ever since — the latter single-quoted, so `$word` never expanded either
- `wt-shell` counted unpushed commits with `@{upstream}..HEAD`. A branch created with `-b` and never pushed has no upstream, so git errored and the count came back zero — reading as clean in the exact case where commits were about to be lost. `wtt -b foo`, commit, close the tab, gone. Now falls back to the remote default branch
- `wt-picker` carried its own copy of the create path — fetch plus the three-way `worktree add` fallback — and it had drifted from `wt-core`'s. It shells into the plugin functions now. Parsing `worktree list --porcelain` went from four copies to one `wt-list` script
- `wtpr`/`wti` were welded to herdr, so the zellij backend couldn't open a PR at all. Ref parsing, the PR-vs-issue probe, fork fetching via `refs/pull/N/head` and slugging moved to `wt-core`; a backend is now two one-line bindings and gets `wttpr`/`wtti`/`wttpr-pick` for nothing. wt-herdr: 140 lines → 41
- `_wt_repo_root` aborted on an unmatched glob instead of reporting no local checkout, and `wtrm`'s zellij tab close fired on whichever tab was current rather than the worktree's

**Zed worktree scan — `node_modules` excluded:**

- Zed's own diagnostics reported **16,020,592 tracked entries against 15,193 visible** in one monorepo checkout, with the process resident at ~18 GB. Excluding `**/node_modules` took it to 15,265 entries / 0.34 GB — a ~1000× drop in tracked entries and ~40× in memory, and the file picker went back to being instant
- The ratio is the tell: 99.9% of what Zed tracked was gitignored. Zed honours LSP `workspace/didChangeWatchedFiles` requests **regardless of gitignore**, and `tsgo` watches `node_modules` because that is where the type definitions live. So gitignore stopped being load-bearing the moment LSP watch support got good, which is why this repo was fast a year ago at a larger size
- VS Code ships `**/node_modules/**` in `files.watcherExclude` by default; Zed does not. That difference, not repo size, is the whole story
- The cost is real and deliberate: files under `node_modules` can no longer be opened, so go-to-definition into dependency types will not resolve
- `file_scan_exclusions` **replaces** the defaults rather than merging, so every default entry is repeated in the list. It also only applies at worktree scan time — editing it does nothing until Zed fully restarts

**Terminal keys: escape sequences over control bytes:**

- Three separate bugs, one shape. Ghostty translated `alt+backspace` → `\x17` (ctrl+w) and `cmd+left` → `\x01` (ctrl+a); herdr had `close_tab` on ctrl+w and its prefix on ctrl+a. Deleting a word closed a tab; jumping to line start opened prefix mode. Once a control byte leaves the terminal nothing downstream can tell it from a real keypress
- `alt+backspace` remap deleted outright — zsh already bound `^[^?` to `backward-kill-word`, so it was redundant *and* harmful. `cmd+left`/`cmd+right` moved onto `\x1b[H`/`\x1b[F`, which no multiplexer claims
- Symbol remaps (`alt+2` → `€` etc.) stay: they restore printable characters that `macos-option-as-alt` breaks, and produce nothing any tool interprets as a command. The distinction is character-restoration versus key-translation
- `cmd+k` → `\x0c` remains as the last control-byte remap, safe only while nothing binds bare ctrl+l
- Alt+digit `digit-argument` unbound — an emacs repeat count where `alt+4` then a key repeats it 4×, and only some alt-digits reached zsh anyway

**herdr adopted; zellij autoattach guarded:**

- `zellij-autoattach.zsh` now requires an explicit `ZELLIJ_AUTOATTACH=1`. It `exec`s the shell into zellij and gated only on `TERM_PROGRAM`, which children inherit — so herdr's spawned panes matched, replaced themselves with zellij, and died instantly (`exit 1`, no shell left to fall back to)
- herdr config lives in `config.d/herdr/config.toml`, per-file symlinked rather than whole-dir: `~/.config/herdr` also holds sockets, logs and `session.json`, and `link:config` does `rm -rf` on its target
- Keybindings mirror the zellij muscle memory where it transfers. Every action is bound explicitly, including ones never used — leaving one unbound leaves its default live, and one of those defaults sat on `alt+backspace`
- The daemon reads config only at startup and restarts whenever a session dies, so it kept re-reading whatever existed at that instant. `herdr server reload-config` is the only reliable way to apply an edit
- `initial-command = zsh -ic herdr` resumes the persistent session on launch. Must be `-i`, not `-l`: mise activates from `.zshrc`, which only runs for interactive shells

**herdr themed to match Zed:**

- `[theme.custom]` overrides individual slots on top of `name = "terminal"`, so the terminal palette still drives pane contents while herdr's own chrome is explicit
- `struct CustomThemeColors` has 16 slots, but they are *semantic*, not ANSI: nine are UI (`panel_bg`, three surfaces, two overlays, `text`, `subtext0`, `accent`) and only seven are hues. Monokai Pro offers six — red, green, yellow, orange, purple, cyan — and **no blue**; Zedokai itself maps `terminal.ansi.blue` to orange. Since herdr has a separate `peach`, `blue` takes the cyan so it collides with `teal` rather than with orange
- Values come from Zedokai rather than ghostty's theme file: ghostty exposes only the 16 ANSI entries plus background/foreground, so every surface and overlay would have been invented. Zedokai has real ones — `panel.background`, `border`, `border.focused`, `text.muted`
- Greys were then tuned by contrast rather than by eye. `overlay0` carries section labels and branch names, not just borders, and at Zedokai's `#474448` it sat at **1.5:1** — invisible. Settled at `#6a686b`, the OKLCH-L midpoint between that and an over-corrected `#939293`
- `panel_bg` follows the terminal background, not Zedokai's lighter `#333034`: herdr chrome sitting a shade above the terminal reads as a colour bug rather than as layering
- ghostty's `macos-titlebar-style` returned to `transparent`. `tabs` and `transparent` tint the titlebar to the terminal background; `native` does not, which is what made the window look mismatched

**`wtpr` rebuilt on herdr; PR picker popup:**

- `wtpr` takes a PR number, a full URL, or `owner/repo#N`. A URL resolves the local checkout itself, so it works from anywhere rather than only inside the target repo — GitHub owner matches the directory under `~/workspace`
- Workspace lookup is not reimplemented: `herdr worktree open --cwd <root> --branch <b>` lets herdr resolve the repo and own workspace creation, falling back to `worktree create`. That is why this is ~20 lines rather than grovelling through `workspace list` JSON
- Fetches via `refs/pull/N/head`, so fork PRs work without the branch existing on origin
- `alt+shift+p` opens an fzf picker (number / author / branch / title) in a herdr `type = "popup"`. `--print-query` returns what was typed when nothing matches, so a pasted URL falls through to `wtpr` untouched — including for repos other than the one the popup was opened in
- `${${(f)out}[1]}` **indexes characters, not lines** — the nested expansion collapses to a scalar first, yielding `h` and `t` rather than the query and the selected row. Needs `local -a lines=("${(@f)out}")`. Cost an hour; the tell was `t` appearing as a "PR reference"
- A `wt-runcmd` wrapper for vim-style `:!cmd` was written and then deleted — `vared` only imitates what an interactive shell already does, and it could not run a follow-up command. The popup runs plain `zsh -i` instead
- Popups close the moment the command returns, so failures must hold the window open or the error is never seen

**Claude profiles — `.claude/` renamed to `.claude-work/`:**

- `.dotfiles/.claude/` was the work profile source, but Claude Code also treats `.claude/` in any repo as *project* config. One directory doing both jobs meant herdr installed a session hook into the tracked work profile. `.claude/` is now gitignored so tools writing there land somewhere harmless
- Hook paths use `${CLAUDE_CONFIG_DIR:-…}` rather than an absolute path, so they follow the active profile instead of pinning personal sessions at the work directory

### July

**`16-shadows.zsh` — system tools replaced with current Homebrew builds:**

- macOS ships deliberately frozen versions of a handful of CLI tools, and brew refuses to link its replacements (keg-only, or GNU tools installed g-prefixed). Nothing was bridging that gap, so the 2006-era ones were winning. One file now does it for `make`, `coreutils`, `findutils`, `curl` and `libressl` — the point being that shadowing a system binary is a decision, and decisions belong in one place rather than scattered across per-tool conf.d files
- The one that actually bites: Apple's `make` is **3.81**, frozen pre-GPLv3, so no `.ONESHELL`, no `!=`, no `$(file ...)`. Also `curl` 8.7.1 links zlib only — `Content-Encoding: br`/`zstd` fails outright with `Unrecognized content encoding type`
- Stayed on LibreSSL (4.3.2) rather than switching to OpenSSL: `/usr/bin/openssl` being LibreSSL is a macOS assumption that tooling encodes, and the complaint was the 2021 version, not the fork
- Numbered `16-` to land immediately after `15-brew.zsh` — it must beat `/opt/homebrew/bin`, while the alphabetical files that follow keep `~/.dotfiles/bin` on top
- Not via mise: its registry has `coreutils` only as `aqua:uutils/coreutils` (the Rust rewrite, not GNU), `make`/`sqlite` only on the conda backend, and no `findutils`/`curl`/`libressl` at all
- `llvm` left shadowed on purpose — Apple's clang knows the macOS SDK, and displacing it causes link failures

**Agent profiles moved from zsh wrappers to mise env:**

- `~/.config/ai-profiles/*.yaml` + the `_ai_profile` zsh resolver are gone. Profile selection is now just mise `[env]`: `CLAUDE_CONFIG_DIR`/`PI_CONFIG_DIR` default to the personal profiles in `mise/conf.d`, and the work root's `mise.toml` overrides them per-root. mise already walks the directory hierarchy — no reason to reimplement that in shell
- Paths need `{{env.HOME}}`, **not** `~` — mise does not tilde-expand `[env]` values, and a literal `~/…` makes the tool resolve it relative to cwd and silently re-onboard into `./~/`. `PI_CONFIG_DIR` stays HOME-relative (`.omp-personal`) because omp resolves it under `$HOME` itself
- Unsetting a var in a child config is `VAR = false`; `_.unset = [...]` parses as a tool spec and hard-errors on mise 2026.7.15
- Claude behaviour that used to ride on flags now lives in the committed `settings.json` for both profiles: `remoteControlAtStartup: true` replaces `--remote-control`, and `permissions.defaultMode: "bypassPermissions"` replaces `--dangerously-skip-permissions`. `c` is now a bare alias. omp keeps `--auto-approve` on `o` — it has no verified config equivalent, and it doesn't validate unknown config keys, so a guess would fail silently

**Static env vars moved out of mise into zsh:**

- mise `[env]` now carries only what genuinely varies per-directory — `CLAUDE_CONFIG_DIR` and `PI_CONFIG_DIR`, both overridden in work roots. Everything static moved to the conf.d file for its tool (`NI_CONFIG_FILE` → `ni.zsh`, the `CLAUDE_CODE_*` flags → `claude.zsh`) with `env.zsh` for the homeless ones; `00-env.toml` is gone
- Perf was not the reason — measured at ~0.15 ms per var, so the five that moved were worth well under a millisecond of a ~40 ms `hook-env` you pay on every `cd` regardless. The point is that mise is for directory-scoped values and a shell rc is for constants

**Completions now actually wait for `mise up`:**

- `generate:completions` listed `mise:upgrade` as a dep alongside the ~50 `generate:completions:gen` deps — but go-task runs *all* deps in parallel, so completions were generated from pre-upgrade binaries while `mise up` was still running. The ordering was never real
- Fixed by moving the constraint onto `generate:completions:setup`, the single task every gen deps on: `mise:install` → `mise:upgrade`. One choke point orders the whole fan-out without serialising it

**`claude` / `omp` auto-pick their profile by directory:**

- `claude`/`c` and `omp`/`o` are now functions that resolve which profile to launch from `$PWD` — no switcher, no thinking. cwd under a configured work root → the work profile; anywhere else → personal (with `--remote-control` for claude). `c` and `o` are plain aliases to those functions, so both the short and long name do the magic
- Driven by `~/.config/ai-profiles/{claude,omp}.yaml` (longest matching `root` wins, else `default: true`). Shared resolver `_ai_profile` in `ai-profiles.zsh` parses it with `yq`. The real configs are gitignored (private paths); only `*.template` + a deny-all-`*.yaml` `.gitignore` are committed. No config / no yq / no match → the tool's own default dir, so a fresh machine just works
- Work claude is now its own isolated profile `~/.claude-work`, symmetric with `~/.claude-personal`: its `.claude.json` + runtime live there (out of the repo tree), while `CLAUDE.md`/`skills`/`settings.json` are vendored back as per-file symlinks. The old whole-dir `~/.claude` symlink and `$HOME/.claude.json` are **gone** — running `claude` with no wrapper re-onboards a fresh profile, by design (clean cutover, no back-compat shims). The wrapper sets `CLAUDE_CONFIG_DIR=~/.claude-work` for work, `~/.claude-personal` for personal
- Work settings are **split** to keep this *public* repo clean: committed `.claude/settings.json` is minimal and portable (model, theme, editor, notif — no hooks, no marketplaces, no usernames); everything machine- or org-specific (suvadu + gastown hooks, custom marketplaces + their plugins, local permissions) lives in gitignored `~/.claude-work/settings.local.json`, which claude deep-merges at runtime
- omp needs none of this — `~/.omp` is already a clean isolated dir, so the wrapper leaves `PI_CONFIG_DIR` unset for work and sets it (`~/.omp-personal`) only for personal. `cjc` / `ojc` stay as force-personal escape hatches; `cjc` no longer `cp`s the work `CLAUDE.md` over the personal one (both are committed now)

**bat pager fixed — no more one-line-at-a-time / hangs:**

- `PAGER='bat --style=plain'` was the bug: bat as a generic pager receives other tools' output and re-pages through `less`, and `alias cat='bat'` paged big files (a screenful, or with a broken pager a line, at a time — and could hang waiting on `less`). Now `cat` is `bat --paging=never` (dumps), `PAGER`/`BAT_PAGER` are plain `less` with `LESS='-FR'` (raw colours, quit-if-one-screen, no `-X` footgun)
- `MANPAGER` pipes through `col -bx | bat -l man` (+ `MANROFFOPT=-c`) so man's backspace overstrike is stripped instead of rendered as garbage

**Agent configs vendored (omp + claude-personal):**

- `~/.omp`, `~/.omp-personal`, and `~/.claude-personal` now feed committed config into the repo the same spirit as `~/.claude` — but per-file, not whole-dir. Only the safe surface is symlinked in: omp `agent/{config.yml,mcp.json}` and claude-personal `{CLAUDE.md,settings.json}`. Everything else (transcripts, Mnemopi `memories`, `*.db`, sessions, 200M+ of caches/natives) stays put in `~` and never enters the repo tree
- Per-file over `.claude`'s whole-dir symlink for two reasons: the omp dirs host *live daemons* (a `rm -rf`-then-relink of the whole dir would nuke the running harness), and whole-dir would drag hundreds of MB of gitignored runtime junk into the working tree. Each subtree carries a deny-all-then-allowlist `.gitignore` (`*` + `!` the exact files) so a new secret file added by any tool fails safe — stays ignored until explicitly whitelisted
- `task link:dotfiles` skip-lists the three dirs (its destructive whole-dir linker must not touch them); a new idempotent `link:agent-configs` task rebuilds the per-file symlinks on a fresh machine

**PR labels rule:**

- CLAUDE.md Git & GitHub gains: apply the repo's labels when creating PRs (e.g. `expect-breaking-changes`, `allow-unsafe-migrations`), and any label that waives a safety gate must be justified in the PR description — what it permits and why it's OK for this change. A bare waiver label tells the reviewer nothing
- Companion rule: ANY unsafe change (breaking, risky migration, backwards-incompatible) gets justified in the PR description even when no label exists to flag it — the reviewer gets the risk context either way

**Time awareness rule:**

- CLAUDE.md gains a top-of-file rule: on return-from-silence signals ("I'm back", "morning!!") or relative dates ("today", "yesterday"), run `date` and re-anchor before reasoning about time, keeping the previous anchor so relative references resolve against when the last exchange actually happened. Sessions span sleep/weekend breaks; the user shouldn't have to announce that it's the next day

**Standards MCP check + Coding Standards section:**

- CLAUDE.md `Code Style` renamed to `Coding Standards` and gains the rule: when the standards MCP is connected, newly written code gets checked against the relevant standards while writing or right after push, in parallel with tests/CI (delegable to an arm). Catches standards violations locally instead of waiting a full cycle for AI review to bounce them back

**Octopus Mode 🐙 — CLAUDE.md agent orchestration rewritten:**

- Replaced the tiered subagent routing ("USE TEAMS", Haiku/Sonnet/Opus by task type) with Octopus Mode: one frontier brain holds all context and does all thinking; arms are Haiku agents executing pre-distilled, self-contained todos (exact file, exact change, exact verify). Prompted by stencil.so/blog/prewalk — the bill is O(reads), so plan-then-handoff to a cheaper executor costs *more* than the main thread doing it (the executor re-reads everything the plan summarised away). The Opus-subagent tier was the worst offender: paying to re-ship context to a second frontier model
- Read-only recon fan-out survives as the one delegation that saves money — cheap agents sweep files and return conclusions, keeping raw reads out of main context
- De-rotted the rest of the file while in there: merged Commit/Pushing into Git & GitHub (same rules written twice), deduped resolve-comments and @claude-review (3× each), tore out all Jira references (GitHub Issues everywhere), killed dead `/batch`/teams references, and recorded the no-plan-mode preference (align in chat, tickets created/updated at do-time so they never drift)

**Atuin dropped, suvadu kept — ctrl-r back to fzf:**

- Ended the trial: removed `atuin` (mise tool, `config.d/atuin/`, `zz-atuin.zsh`). The atuin ctrl-r UI overlapped fzf without earning the slot; suvadu stays for its agent-aware recording and MCP read path
- Dropping atuin does **not** hand ctrl-r to fzf on its own — `suv init zsh` also binds `^R` (to `suvadu-search`), and it loads after `fzf.zsh`. `suvadu.zsh` now reclaims ctrl-r with `bindkey '^R' fzf-history-widget` after the init eval, so fzf owns ctrl-r while suvadu keeps the up/down arrows and its recorder hook
- Fixed a silent breakage: `.claude/settings.json` registered the `suv init claude-code` hooks (PostToolUse/PostToolUseFailure/UserPromptSubmit) but the scripts under `config.d/suvadu/hooks/` were never committed — the symlink `~/.config/suvadu → config.d/suvadu` dangled, so agent-command origin tracking no-opped against missing files. Regenerated and committed the hooks; the MCP read path was always fine

**Lift the `brew bundle` parallelism cap:**

- `HOMEBREW_BUNDLE_JOBS` set to `hw.ncpu` in `15-brew.zsh`. Homebrew 6.x ships a real parallel installer for `brew bundle` (dependency-graph scheduled thread pool), but `auto` caps at `min(cores, 4)` — leaving 14 cores idle on the 18-core box. Pinned to core count rather than a literal 18 so it stays correct across machines
- Only lifts the ceiling for formulae; casks stay serialised inside the installer (they fire interactive `sudo`/`Password:` prompts to `/dev/tty` that would otherwise interleave into garbage), so a cask-heavy Brewfile has a floor no amount of jobs can dodge

**Suvadu trial (agent-aware shell history):**

- Reversed the "passed for now" call below — trialling suvadu alongside atuin rather than instead of it. mise-managed via alias (`suvadu = "github:AppachiTech/suvadu"` in `02-aliases.toml`, github backend — not in the mise registry), no curlbash
- Keybind topology is load-order-driven since `suv init zsh` has no flag to opt out of bindings: `suvadu.zsh` sorts after `fzf.zsh` and before `zz-atuin.zsh`, so **ctrl-r = atuin, up/down arrows = suvadu**. Both record every command; the trial ends by deleting whichever conf.d file loses
- `config.d/suvadu/hooks/` holds the `suv init claude-code`-generated Claude Code hooks (PostToolUse/UserPromptSubmit → records agent-run commands with origin tracking), symlinked to `~/.config/suvadu` like any other config dir. The suvadu MCP server in `~/.claude.json` exposes the recorded history to Claude itself

**Atuin shell history:**

- `atuin` added to mise tools (aqua backend, no curlbash) with init in `config.d/zsh/conf.d/zz-atuin.zsh` — the `zz-` prefix is load-bearing: both atuin and `fzf --zsh` bind ctrl-r and last-loaded wins, so atuin must source after `fzf.zsh` (atuin takes ctrl-r; fzf keeps ctrl-t/alt-c). Up-arrow stays native via `--disable-up-arrow`
- `config.d/atuin/config.toml` holds only deviations from defaults: compact inline style, global filter by default (repo-scoped start hid imported history, which has no cwd context — ctrl-r cycling into workspace scope still works), enter-to-run
- Considered suvadu (agent-origin tracking for AI-run commands) — passed for now: 4 months old, single-org, and shell history is too load-bearing a slot for a v0.x bet. Revisit if it matures

**Homebrew via official .pkg installer:**

- `setup-macos` now installs Homebrew from the `Homebrew.pkg` asset on the latest GitHub release (`releases/latest/download/` is a stable URL — no version pinning, no API call) instead of curl-piping `install.sh` into bash. One `sudo installer` invocation, resolved by the Touch ID sudo set up in step 2, replaces a script that shells out to sudo repeatedly — fewer moving parts to race in a piped, non-TTY bootstrap

### June

**Global `uv` for mise's pipx backend:**

- `brewfiles.d/core.rb` declares `brew 'uv'`. The `pipx:` backend (`snowflake-cli` and friends in `tools.toml`) shells out to `uv`/`uvx` to build isolated tool venvs, but neither was installed — `mise install` died with a misleading errno 2 trying to exec a missing binary, blaming the package version. Lives in `core` not `dev` because the `tools.toml` pipx entries are unconditional, so a role-less machine still needs uv; brew runs pre-mise so the binary exists before mise reaches for it. uv fetches its own CPython, so no system interpreter to pollute. mise auto-detects `uvx` — no `pipx.uvx` setting required
- `config.d/zsh/conf.d/sfw.zsh` wraps interactive `uvx` in Socket Firewall alongside `uv`/`cargo`. mise calls the binary directly so pipx-backend installs bypass sfw regardless — not worth chasing, the wrap only covers interactive use

**Lima payload-detonation sandbox (`jail`):**

- `config.d/lima/isolated.yaml` (symlinked to `~/.config/lima/`) — a throwaway arm64 Ubuntu VM for detonating untrusted samples that hit the org (scripts/JS/Python/macros) and running Claude inside as an autonomous triage agent. The point is to box *Claude itself*: an agent with `--dangerously-skip-permissions` on attacker-controlled input is a prompt-injection target, so it runs where a hijack can't reach the host
- Host fs is invisible to the guest except `~/lima-jail` ↔ `/jail` (the one quarantine mount); no home mount, no SSH-agent forwarding, no env passthrough. Egress stays *on* — the sample (and a tricked agent) can reach the web, which is the tradeoff for observing real C2 behaviour. `tcpdump` auto-starts at boot via a systemd unit writing full pcap to `/jail/capture.pcap`, so the capture lands on the host and survives nuking the VM — every exfil/pivot attempt is on the record
- Claude auth is a throwaway `claude setup-token`, injected at runtime into the agent's process env only (`CLAUDE_CODE_OAUTH_TOKEN` via `limactl shell jail -- env …`) — never baked into the committed YAML, never written to the contaminated `/jail` mount. Revoke after each session; blast radius of a scraped token is capped at "some API spend until revoked". The box pre-seeds `hasCompletedOnboarding`/`bypassPermissionsModeAccepted` so an injected token authenticates without tripping interactive gates — agent runs must be headless (`-p`), the TUI still shows a login screen
- `config.d/zsh/conf.d/lima.zsh` — helpers: `jail-rebuild` (delete + fresh box; config changes only land on first boot, so rebuild = recreate not restart), `jail-mint` (runs `setup-token`, greps the bare `sk-ant-oat…` out of its banner noise, caches in `$JAIL_TOKEN`), `jail-claude` (auto-mints on first use then injects), `jail-send`, `jail-shell`, `jail-pcap`, `jail-nuke`. One fresh box per sample — vz has no clean snapshot-revert, so never reuse a contaminated guest
- Known gap: in-guest capture can be tampered by capture-aware malware wiping `/jail`. Host-side capture via `socket_vmnet` would be tamper-proof — deferred
- `brewfiles.d/virtual.rb` declares `lima` under a new `virtual` brew role (documented in `dotfiles-roles.yml.template`), so a fresh machine reinstalls Lima via `brew bundle`

**Secrets off disk — JIT injection over parked env vars:**

- Killed `NODE_AUTH_TOKEN` / `NPM_AUTH_TOKEN` from `packager.d/mise-secrets.tmpl` (both org tokens dead after the GitHub compromise; npmjs installs are anonymous anyway — `.npmrc` no longer references an auth token, only `publish` needs a write-scoped token, injected just-in-time)
- `BUF_TOKEN` moved to JIT: `buf` is now an `op run` wrapper in `20-op.zsh` that resolves `op://Personal/buf.build/token` into the one process that needs it via an inline `<()`'d reference file — nothing on disk, no secrets file to sync or leak. op's session cache makes it a warm lookup, not a Touch ID per call
- `mise-secrets.tmpl` now empty: zero standing secrets in shell env. The `secrets:populate` machinery stays dormant for genuine always-on-env cases, but JIT is the default. Live `~/.config/mise/conf.d/secrets.toml` wiped

**mise GitHub token via `gh auth token`:**

- `[settings.github] credential_command = "gh auth token"` in `config.d/mise/config.toml`. Restores authed GitHub API access after `20-github.zsh` was deleted in `6d43d37` (commit assumed mise's `gh_cli_tokens = true` would read tokens from `~/.config/gh/hosts.yml` — it doesn't in 2026.5.15, mise only consulted `~/.config/mise/github_tokens.toml` and silently fell back to unauthenticated, hitting the 60/hr rate limit). `credential_command` lazy-shells `gh auth token` per fetch, so no token lives in the env

**Zellij socket-path fix + cwd-named `zj`:**

- `ZELLIJ_SOCKET_DIR=/tmp/zellij` exported in `config.d/zsh/conf.d/utils.zsh`. macOS `$TMPDIR` is a ~50-char `/var/folders/...` path; zellij's per-session unix socket lives under it and the whole path must stay ≤103 bytes (`sun_path` limit). Long, stable session names (e.g. `zp`/autoattach naming a session after `app-professional-profiles`) tipped it past 103 and zellij died on attach — while bare `zellij` survived only because its random names were shorter. Pinning the socket dir somewhere short makes any name fit. Not a serialization/resurrection problem; `session_serialization` stays on
- `zj` is now a function, not an alias: bare `zj` attaches to / creates a session named after `$PWD` (same sanitisation as autoattach); `zj <args>` still passes through to `zellij`

### April

**Terminal overhaul — swap from ghostty to wezterm:**

- `font-geist`, `font-geist-mono`, `font-geist-mono-nerd-font` moved from `install:fonts` task (pinned to v1.7.0) to `brewfiles.d/core.rb` casks. Auto-updates via `brew upgrade`. Whole `install:fonts` / `install:fonts:get` Taskfile machinery deleted along with its DAG entry
- `cask 'wezterm'` added; `cask 'ghostty'` removed (`config.d/ghostty/` kept)
- `.wezterm.lua`: `send_composed_key_when_*_alt_is_pressed = false` so Alt forwards as a real modifier (was breaking zellij Alt+hjkl). UK compose keys already explicit overrides so nothing lost. `format-tab-title` handler added so active pane's OSC title propagates live. `default_prog = { 'zsh', '-ic', 'zps' }` — new WezTerm tab drops into the zellij picker, ESC falls through to a plain shell
- `zps` helper in `config.d/zsh/conf.d/utils.zsh` — thin wrapper around `zp` that always `exec zsh` after
- `icon:wezterm` Taskfile task — copies `config.d/wezterm/wezterm.icns` (mikker's design) to `/Applications/WezTerm.app/Contents/Resources/terminal.icns`, nukes Dock icon caches, `killall Dock`. Checksum-based `status:` so it only re-runs when brew upgrade wipes it. Hooked into `converge` after `brew:bundle`

**Editor + multiplexer:**

- Zed `buffer_font_features`: all Geist Mono stylistic sets (`ss01`–`ss11`, minus skipped `ss05`) enabled. Coding ligatures live under `ss11` in Geist Mono (not `calt`/`liga`) — vercel/geist-font#201 context
- Zellij: `Ctrl+Shift+P` enters pane mode (default `Ctrl+P` kept as in-mode escape). Explicit `web_server false` + `web_sharing "disabled"` to harden against future default flips

- New `sudo:reattach` task — prepends `pam_reattach.so` to `sudo_local` so Touch ID works inside tmux. Depends on `brew:pam-reattach` + `sudo:touchid`
- New `brew:pam-reattach` task — installs formula, status checks `.so` presence. `brew:bundle` depends on it to avoid lock races
- `pam-reattach` added to `brewfiles.d/core.rb`
- Removed `min-release-age=7` from `packager.d/npmrc-security` — was causing unwanted writes to `~/.npmrc`

### March

**Package manager supply chain hardening:**

- New `packager.d/` directory for security configs (mirrors `git.d/`, `ssh.d/` pattern)
- `link:npmrc` converge task: ensures `ignore-scripts=true` exists in `~/.npmrc`, enforces `chmod 600` (file contains auth tokens)
- `link:cargo` task: symlinks `~/.cargo/config.toml` with `git-fetch-with-cli = true` (inherits system git's SSH/credential config from `git.d/`)
- `.bunfig.toml`: disable lifecycle scripts (`postinstall`, `preinstall`, `prepare`), existing 7-day release age retained
- Both tasks run as part of `task converge` via `link:` dependency chain

**Move setup-macos into Taskfile DAG:**

- Setup script reduced to ~20 lines: clone dotfiles, bootstrap go-task, `task setup`
- All bootstrap steps are now Taskfile tasks with `status:` checks (idempotent)
- Interactive tasks (xcode, 1password, gh-auth) run sequentially first
- Everything else (rosetta, claude, link, mise, upd) runs in parallel via DAG
- New tasks: `bootstrap:*`, `mise:install`, `bootstrap:sudo-*`, `bootstrap:unquarantine`

**Migrate `upd` pipeline to go-task (Taskfile):**

- Moved system update tasks from mise.toml to Taskfile.yml — proper `platforms` filtering (darwin/linux), `preconditions` for binary checks, prefixed parallel output
- mise.toml retains project-specific tasks (link, reinstall-bins, use-ssh)
- `upd` alias now calls `task --taskfile ~/.dotfiles/Taskfile.yml upd`

**Replace `upd` TUI with mise task DAG (superseded by Taskfile):**

- Ripped out the ratatui TUI dashboard — all update tasks now defined as mise tasks with `depends` for dependency ordering
- `brew-bundle` → `brew` (serialized), `zsh-completions` depends on `brew`, `brew-bundle`, and `mise` (waits for new binaries)
- Everything else (link, auth, fonts, claude, tmux-plugins) runs in parallel via mise's built-in task scheduler
- `upd` is now a zsh alias to `mise run --cd ~/.dotfiles upd` — no more Rust binary
- Removed `ratatui` and `crossterm` dependencies from Cargo.toml
- Deleted `app.rs`, `tasks.rs`, `ui.rs` modules (~400 lines of TUI code)

**Migrated shell-wrapper crates to zsh functions:**

- `install-terminfo` → zsh autoload function (`infocmp -x | ssh host tic -x -`)
- `echo-to-file` → zsh autoload function (`echo "$@" > $TMPDIR/echo-out-$(id -u)`)
- `gen-diff` → zsh autoload function (ImageMagick `magick` wrapper)
- `git-trigger` → zsh function in `git.zsh` (supports `-n`/`--dry-run`)
- All removed from Cargo.toml, dotfiles.toml completions, and crates source

**Ratatui TUI dashboard for `upd` (superseded):**

- Replaced `indicatif` MultiProgress spinners with a ratatui-powered TUI dashboard showing live panels per task
- Responsive grid layout (3-col on wide terminals, 2-col on medium, 1-col on narrow) with bordered panels per task
- Each panel shows current step, scrolling output, spinner while running, and collapses to status icon on completion
- Errors highlighted in red and stay visible; bottom status bar shows overall progress
- Restructured `upd.rs` monolith into `src/bin/upd/` modules: `main.rs`, `app.rs` (state), `ui.rs` (rendering), `tasks.rs` (subprocess spawning)
- Pre-TUI phase (link, auth, fonts, brew bundle) and post-TUI phase (completions, summary) remain interactive/non-TUI
- Press `q` or `Esc` to exit early; TUI auto-exits 800ms after all tasks complete

**Terminal config sync:**

- Synced Ghostty, WezTerm, and Alacritty configs — Monokai Pro theme, Geist Mono 11pt, matching keybinds (alt compose, alt+backspace, shift+enter), 0.85 opacity + blur across all three
- WezTerm: integrated titlebar (no border), fancy top tab bar, Cmd+K clear scrollback
- Alacritty: fixed font (GeistMono Nerd Font), corrected palette black (#3d3a3e), added option_as_alt
- Ghostty: added background-blur, removed stale commented-out pane navigation

**Unified output formatting:**

- Replaced all `/// .SECTION` headers and mixed output styles across the entire repo with nerdfont icons and consistent ANSI colors
- Icon system: `󰄬` success (green), `󰌷` link (green), `→` action (cyan), `󱁤` build (magenta), `󰛖` font (magenta), `󰅖` error (red), ``warning (yellow),`⟢` section header (magenta bold)
- Affected: all 22 crate binaries, shared lib, setup-macos, mise tasks, zsh functions (upd, fonts!), hooks

**Zsh cleanup:**

- `sheldon.zsh`: collapsed 14-line hand-rolled cache to 3 lines using enhanced `_cached_eval`
- `00-prelude.zsh`: added dependency file support to `_cached_eval` for cache invalidation
- `npm-completion.zsh`: stripped dead bash/ancient-zsh codepaths
- `utils.zsh`: added guard clauses for all tool-specific aliases
- `claude.zsh`: added missing guard clause
- `fm`/`fr`: fixed branch selection bugs, added relative dates and column-aligned output
- `take`/`taketmp`: added error handling with nerdfont output
- Moved bat+fzf alias to `fzf.zsh` where it belongs

**Misc:**

- Added Hammerspoon + WezTerm cask to brewfiles (Hammerspoon later removed — quake terminal via macOS window management too janky)
- `.editorconfig`: added baseline quality settings (LF, final newline, trim trailing whitespace)

### February

**Terminal & multiplexing:**

- Ported all Ghostty settings to WezTerm — font size, monokai-pro palette fix, alt keybinds, shift+enter
- Replaced tmux with WezTerm's unix domain multiplexer for local session persistence — no prefix key, native splits persist across restarts
- Modernized `.wezterm.lua` to use `config_builder()` API

**Brewfile roles:**

- Split monolithic Brewfile into role-based system — `brewfiles.d/` with 15 role files (core, browsers, dev, infra, docker, media, photo, audio-hw, networking, vpn, social, work, gaming, terminals, ai)
- `dotfiles-roles` file (gitignored, per-machine) controls which roles are active — defaults to core-only if missing
- `dotfiles-roles.template` committed as reference for available roles
- Taps moved into their respective role files instead of all loading globally
- `Brewfile.local` support for machine-specific one-off packages (also gitignored)
- Fixed duplicate ffmpeg entry, fixed rar (was `brew`, should be `cask`)

**Crate audit & upd improvements:**

- Comprehensive crate audit: deduplicated `home_dir()`, `available_cores()`, `print_results()` into shared lib — removed ~370 lines of duplication across binaries
- Purged unused deps (`regex`, `toml_edit`, `scraper`), standardized all `env::var("HOME")` to `dirs::home_dir()` wrapper
- Fixed `clean-dls` bug where `is_sample_file` missed multi-dot filenames like `track.sample.mp3`
- Added missing `#[command(name)]` to 6 binaries, standardized `check_command` usage, fixed bare unwraps
- Deduplicated `upd` auth checks into reusable `AuthStatus` struct
- `upd` wrapper no longer rebuilds Rust binaries by default — pass `--rebuild` to pull dotfiles + recompile

**Security & bootstrap hardening:**

- Setup now configures TouchID for sudo via `/etc/pam.d/sudo_local` (survives macOS updates)
- Setup now sets 30-min sudo timeout via `/etc/sudoers.d/timeout`
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
- `gen-diff`, `url2base64`, `parallel-dl-extract`
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
