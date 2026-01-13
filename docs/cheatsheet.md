# Cheatsheet

Comprehensive reference for this dotfiles setup - custom binaries, aliases, functions, and tooling.

## Custom Binaries (`~/.dotfiles/bin/`)

All written in Rust, built via `cargo install`. Run any with `--help` for full options.

### System & Maintenance

| Command                      | Description                                                            |
| ---------------------------- | ---------------------------------------------------------------------- |
| `upd [-v]`                   | Update everything - pulls dotfiles, rebuilds rust bins, runs brew/mise |
| `kill-port <port> [-n]`      | Kill process on port (`-n` dry-run, `-s` signal)                       |
| `prune [paths] [-s kb] [-y]` | Find and delete small directories (default 3MB threshold)              |
| `regen-zsh-completions`      | Rebuild shell completions from installed tools                         |
| `unfuck-xcode`               | Reset Xcode CLI tools when they're corrupted                           |
| `install-terminfo <host>`    | Install terminfo entries (ghostty, etc) via SSH                        |

### Git Workflow

| Command                    | Description                                                |
| -------------------------- | ---------------------------------------------------------- |
| `git-sync [-y]`            | Delete local branches already merged to main               |
| `git-squash [parent] [-n]` | Squash commits for clean PR history (default parent: main) |
| `git-trigger [-n]`         | Amend + force push to re-trigger CI                        |

### Media & Audio

| Command                         | Description                                              |
| ------------------------------- | -------------------------------------------------------- |
| `to-audio flac\|opus [paths]`   | Convert audio (flac=lossless, opus=lossy efficient)      |
| `embed-art [paths]`             | Embed cover.jpg/png into FLAC files                      |
| `clean-exif [paths]`            | Strip EXIF data from images                              |
| `extract-exif-from-flac <file>` | Check FLAC embedded art for EXIF data                    |
| `update-ffmpeg [-s] [-n]`       | Update ffmpeg URLs in mise config (`-s` snapshot builds) |

### File Operations

| Command                        | Description                                               |
| ------------------------------ | --------------------------------------------------------- |
| `vimv [files]`                 | Batch rename files in $EDITOR - edit names, save to apply |
| `clean-dls [paths] [-n]`       | Remove scene release garbage (nfo, txt, samples)          |
| `gen-diff <img1> <img2> <out>` | Generate visual diff between two images                   |
| `url2base64 <url>`             | Fetch URL content and output as base64 data URL           |

### Downloads & Import

| Command                      | Description                                               |
| ---------------------------- | --------------------------------------------------------- |
| `imp <urls>`                 | Download + extract + beets music import (aria2c parallel) |
| `parallel-dl-extract <urls>` | Parallel download and extract archives                    |
| `install-font-macos <urls>`  | Download and install fonts to ~/Library/Fonts             |

---

## Shell Functions

Located in `~/.config/zsh/functions/`.

| Function             | Description                                                    |
| -------------------- | -------------------------------------------------------------- |
| `fm`                 | **Fuzzy merge** - fzf select branch to merge                   |
| `fr`                 | **Fuzzy rebase** - fzf select branch to rebase onto            |
| `take <path>`        | Create directory and cd into it                                |
| `taketmp`            | Create temp directory and cd into it                           |
| `using <cmd>`        | Check if command exists (returns 0/1)                          |
| `fonts! [-f] <urls>` | Elegant font installer with progress (`-f` force overwrite)    |
| `upd`                | Wrapper that pulls dotfiles, builds bins, then runs upd binary |

---

## Shell Aliases

### Git (`git.zsh`)

80+ aliases. Here are the greatest hits:

**Basics**

```
g          git
gs         git status -sb
gst        git status
gd         git diff
gds        git diff --staged
glog       git log --oneline --graph --decorate
```

**Adding & Committing**

```
gaa        git add --all
gap        git add --patch
gau        git add --update
gcmm <msg> git commit -m <msg>
gc!        git commit --amend
gca!       git commit -a --amend
gcn!       git commit --amend --no-edit
```

**Branches & Checkout**

```
gco <br>   git checkout <branch>
gcb <br>   git checkout -b <branch>
gb         git branch
gba        git branch -a
gbd        git branch -d
gbD        git branch -D
```

**Push & Pull**

```
gp         git push
gpl        git pull
gpf        git push --force-with-lease
gpf!       git push --force
gpsup      git push --set-upstream origin $(current_branch)
gup        git pull --rebase
gupa       git pull --rebase --autostash
```

**Rebase & Merge**

```
grbi       git rebase -i
grba       git rebase --abort
grbc       git rebase --continue
gm         git merge
gma        git merge --abort
```

**Stash**

```
gstaa      git stash apply
gstp       git stash pop
gstl       git stash list
gstall     git stash --all
```

**Reset & Clean**

```
grhh       git reset --hard
groh       git reset origin/$(current_branch) --hard
gpristine  git reset --hard && git clean -dfx
gru        git reset --
```

**Misc**

```
grt        cd to git root
gwip       WIP commit (add all, commit --wip--)
gunwip     undo last WIP commit
glola      log --graph --all
```

### Utilities (`utils.zsh`)

```
whatport <port>   lsof -i :<port> - find what's using a port
listening         lsof -iTCP -sTCP:LISTEN - all listening ports
psg <pattern>     procs --tree | grep - search processes
recent [time]     fd --changed-within <time> - recently modified (default: 1h)
sizes [path]      dust -d 2 - disk usage breakdown
```

### Package Managers

```
b / ba / bi / bt   bun / bun add / bun install / bun test
bb                 brew bundle
m / mi             mise / mise install
```

### Navigation

```
z <partial>   zoxide - smart cd with frecency
..            cd ..
...           cd ../..
```

### Kubernetes (`k8s.zsh`)

All have fzf-tab completion with colored pod/resource previews.

```
klg <pod>     kubectl logs -f (follow logs)
ksh <pod>     kubectl exec -it -- /bin/sh (shell into pod)
kgp <pat>     get pods | rg (search pods)
kgpw <pat>    get pods -w | rg (watch pods)
kcme <cm>     edit configmap
ksv <secret>  view secret (base64 decoded)
kkp           kill pods (fzf multi-select with TAB)
```

### Misc

```
cat           bat (syntax-highlighted)
gh            gh with GITHUB_TOKEN unset (uses keyring)
```

---

## Modern CLI Replacements

These are configured as defaults or available directly.

| Old     | New      | Why                                                |
| ------- | -------- | -------------------------------------------------- |
| `cat`   | `bat`    | Syntax highlighting, line numbers, git integration |
| `ls`    | `lsd`    | Icons, colors, tree view                           |
| `cd`    | `zoxide` | Learns frecency, `z partial-match` jumps anywhere  |
| `du`    | `dust`   | Visual bar charts of disk usage                    |
| `ps`    | `procs`  | Color-coded, tree view, searchable                 |
| `grep`  | `rg`     | Ripgrep - fast, respects .gitignore                |
| `find`  | `fd`     | Simpler syntax, fast, respects .gitignore          |
| `diff`  | `delta`  | Syntax highlighting, word-level diffs              |
| `curl`  | `xh`     | HTTPie-like, colorized, sensible defaults          |
| `wrk`   | `oha`    | HTTP load testing with live TUI                    |
| `wc -l` | `tokei`  | Code stats per language                            |

See [new-tools.md](new-tools.md) for detailed usage.

---

## fzf-tab Completions

Tab completion opens fzf instead of zsh's default menu.

**Keys**

- `Tab` - Open completion popup
- Type to fuzzy filter
- `Enter` - Select
- `<` / `>` - Switch completion groups
- `Ctrl-Space` - Multi-select

**Previews**

- Files: syntax-highlighted content (bat)
- Directories: contents (lsd)
- Processes: pid/user/cpu/mem
- Git branches: recent commits

See [fzf-tab-completions.md](fzf-tab-completions.md) for setup details.

---

## Tool Management

### Mise (Runtime Versions)

```bash
m             # mise
mi            # mise install (from mise.toml)
mise use node@22   # set version for project
mise ls            # list installed
```

Current defaults in `mise.toml`: elixir, erlang, node 24

### Homebrew

```bash
bb            # brew bundle (install from Brewfile)
brew upgrade  # upgrade all packages
```

See `Brewfile` for full package list.

---

## Directory Structure

```
~/.dotfiles/
├── bin/                    # Compiled Rust binaries
├── crates/                 # Rust source
│   └── src/bin/           # Binary implementations
├── config/
│   └── zsh/
│       ├── conf.d/        # Modular zsh configs (30 files)
│       ├── functions/     # Custom shell functions
│       └── completions/   # Generated completions
├── docs/                   # Documentation (you are here)
├── docs-local/            # Work-specific docs (gitignored)
├── git.d/                  # Git config
├── ssh.d/                  # SSH config
├── .zshrc                  # Shell entry point
├── .tmux.conf             # Tmux config
├── .wezterm.lua           # WezTerm config
├── Brewfile               # Homebrew packages
├── mise.toml              # Runtime versions
└── setup                   # Bootstrap script
```

---

## Quick Reference

**Update everything:** `upd`

**Kill port 3000:** `kill-port 3000`

**Clean merged branches:** `git-sync`

**Squash before PR:** `git-squash`

**Re-trigger CI:** `git-trigger`

**Batch rename:** `vimv *.jpg`

**Convert to opus:** `to-audio opus *.flac`

**Check disk usage:** `sizes` or `dust`

**Find recent files:** `recent` or `recent 2d`

**What's on port 8080:** `whatport 8080`
