# dotfiles

Personal dev environment. macOS/Linux, zsh, Rust tooling.

## Setup

```sh
git clone https://github.com/radiosilence/dotfiles ~/.dotfiles
~/.dotfiles/setup
```

The `setup` script installs Rust if needed, builds the tools, then run `upd` to finish setup.

## What's here

**Shell & Editor configs** - zsh (modular), git, ssh, starship, ghostty, helix, zed

**Runtime management** - mise for languages/tools, Brewfile for system packages

**22 Rust binaries** in `crates/` - built via `cargo install --path . --bins`

## Tools

### System

| Command                     | Description                                    |
| --------------------------- | ---------------------------------------------- |
| `upd`                       | Parallel system updater (brew, apt, mise, etc) |
| `kill-port <port>`          | Kill process on port                           |
| `prune [path] [size_kb]`    | Delete small directories                       |
| `vimv [files]`              | Batch rename in $EDITOR                        |
| `unfuck-xcode`              | Fix corrupt Xcode CLI tools                    |
| `install-font-macos <urls>` | Install fonts from URLs                        |
| `install-terminfo <host>`   | Install terminfo via SSH                       |
| `regen-zsh-completions`     | Rebuild shell completions                      |

### Git

| Command               | Description                  |
| --------------------- | ---------------------------- |
| `git-sync`            | Delete merged local branches |
| `git-squash [branch]` | Squash commits on branch     |
| `git-trigger`         | Empty commit to trigger CI   |

### Audio

| Command                         | Description                      |
| ------------------------------- | -------------------------------- |
| `to-audio opus/flac [paths]`    | Convert audio formats (parallel) |
| `embed-art [paths]`             | Embed artwork into FLACs         |
| `clean-exif [paths]`            | Strip EXIF from images           |
| `extract-exif-from-flac <file>` | Check FLAC art for EXIF          |

### Downloads

| Command                      | Description                       |
| ---------------------------- | --------------------------------- |
| `imp <urls>`                 | Download + extract + beets import |
| `parallel-dl-extract <urls>` | Parallel download + unzip         |
| `url2base64 <url>`           | Fetch URL as base64 data URL      |

### Misc

| Command                        | Description                       |
| ------------------------------ | --------------------------------- |
| `clean-dls [paths]`            | Remove scene release garbage      |
| `gen-diff <img1> <img2> <out>` | Visual image diff                 |
| `prune-gen`                    | Generate test directory structure |
| `echo-to-file <text>`          | Write to /tmp/echo-out            |

## Building

```sh
cd crates
cargo build --release
cargo install --path . --bins --root ~/.dotfiles
```

## Docker

```sh
docker build -t dotfiles .
docker run -it dotfiles zsh
```

All tools support `--help` and shell completions via `<tool> completion <shell>`.

## Shell Completions

Uses fzf-tab for fuzzy completions with previews. After setup, tab completion opens an fzf popup instead of the standard menu.

**Keys:**

- `Tab` - Open completion menu (fzf)
- Type to fuzzy filter
- `Enter` - Select
- `<` / `>` - Switch between completion groups (files, dirs, options, etc)
- `Ctrl-Space` - Multi-select

**Previews:**

- Files show syntax-highlighted content (bat)
- Directories show contents (lsd)
- Processes show pid/user/cpu/mem
- Git branches show recent commits

Run `regen-zsh-completions` after installing new CLI tools to generate their completions.
