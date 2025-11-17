```
   ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
   ██  DOTFILES //  PERSONAL DEV ENVIRONMENT                        ██
   ██  [!] SYSTEM CONFIG + TOOLING  [!]                              ██
   ▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
```

## REQUIREMENTS

```
▸ macOS (Darwin) or Linux
▸ Zsh shell
▸ Rust toolchain (for bin/ tools)
```

## QUICK START

### Fresh System (macOS or Linux)

```sh
git clone https://github.com/radiosilence/dotfiles ~/.dotfiles
~/.dotfiles/setup
```

That's it. The `setup` script will:

- Install Rust (if needed)
- Build and run `upd` which intelligently:
  - Installs Homebrew (macOS, if missing)
  - Installs fonts (macOS, if needed)
  - Runs brew bundle (macOS, if Brewfile exists)
  - Symlinks dotfiles and configs (idempotent)
  - Installs mise tools (if mise exists)
  - Sets up Rust toolchain (if rustup exists)
  - Updates all package managers

Everything is idempotent - run `upd` anytime to update your system.

## WHAT'S INCLUDED

### Core Environment

- **zsh** - Modular shell config
- **mise** - Universal runtime manager
- **starship** - Fast prompt
- **git** - Modular config via includes
- **ssh** - Security-focused config

### Editors & Terminals

- **zed** - Primary editor (Claude integration)
- **helix** - Terminal editor
- **ghostty** - Terminal emulator

### Rust Tooling (26 binaries)

All tools built from `crates/` workspace. Run `just build` to compile.

---

## SYSTEM TOOLS

### `upd`

**Parallel system update orchestrator**

Updates all package managers and tools in parallel with cyberpunk progress display.

```sh
upd
```

Updates: brew, apt, dnf, mise, yt-dlp, zsh completions, rust tooling

---

### `kill-port <port> [signal]`

**Terminate process on port**

Finds and kills process listening on specified port.

```sh
kill-port 3000
kill-port 8080 SIGKILL
```

---

### `prune <path> [size_kb]`

**Find and delete small directories**

Recursively finds directories under specified size and deletes them.

```sh
prune ~/Downloads 100    # Delete dirs < 100KB
prune . 1024             # Delete dirs < 1MB
```

---

### `vimv [files...]`

**Batch rename with editor**

Opens file list in $EDITOR, renames on save. Uses `git mv` for tracked files.

```sh
vimv                  # All files in current dir
vimv *.txt            # Only .txt files
vimv dir1/ dir2/      # Files in directories
```

---

## GIT TOOLS

### `git-sync`

**Clean up merged branches**

Deletes local branches that have been merged to main/master.

```sh
git-sync
```

---

### `git-squash [branch]`

**Squash commits**

Interactive squash of all commits on current branch.

```sh
git-squash           # Squash current branch
git-squash feature   # Squash specific branch
```

---

### `git-trigger`

**Trigger CI/CD pipeline**

Creates empty commit to trigger CI without code changes.

```sh
git-trigger
```

---

## AUDIO TOOLS

### `to-audio opus [paths...] [--bitrate 160]`

**Convert audio to Opus**

Parallel conversion to Opus format using ffmpeg. Scans directories recursively for convertible audio files.

```sh
to-audio opus .                    # Convert all files in current dir
to-audio opus ~/Music --bitrate 192
to-audio opus . --keep             # Keep originals
to-audio opus . --dry-run          # Preview what would be converted
```

---

### `to-audio flac [paths...]`

**Convert audio to FLAC**

Parallel conversion to FLAC lossless format.

```sh
to-audio flac .                    # Convert all files in current dir
to-audio flac ~/Music/Album1 ~/Music/Album2
to-audio flac . --keep             # Keep originals
to-audio flac . --dry-run          # Preview what would be converted
```

---

### `embed-art [paths...]`

**Embed artwork into FLAC**

Searches for cover images (cover.jpg, folder.jpg, etc.) and embeds into FLAC files. Cleans EXIF data first.

```sh
embed-art .
embed-art ~/Music/Album1 ~/Music/Album2
```

Supports: front cover, back cover, disc art, artist photos

---

### `extract-exif-from-flac <file>`

**Check FLAC embedded artwork for EXIF data**

Verifies embedded artwork has been stripped of sensitive metadata.

```sh
extract-exif-from-flac song.flac
```

---

### `clean-exif [paths...]`

**Strip EXIF data from images**

Removes sensitive metadata from images in parallel.

```sh
clean-exif .
clean-exif *.jpg
```

---

## DOWNLOAD TOOLS

### `parallel-dl-extract <urls...>`

**Parallel download and extract**

Uses aria2c for parallel downloads, auto-extracts zips.

```sh
parallel-dl-extract https://example.com/file1.zip https://example.com/file2.zip
```

---

### `url2base64 <url>`

**Download and base64 encode**

Fetches URL content and outputs base64-encoded data.

```sh
url2base64 https://example.com/image.png
```

---

### `imp <urls...>`

**Music importer**

Downloads music archives from URLs (e.g. Bandcamp), extracts them, and imports to beets library. Uses reqwest for direct downloads with progress bars and rust zip crate for extraction.

```sh
imp https://p4.bcbits.com/download/album/.../flac/...
imp https://bandcamp.com/file1.zip https://bandcamp.com/file2.zip
```

---

## MEDIA SYNC

### `pull-music`

**Sync music from remote**

Pulls music from remote server to local storage using rclone.

```sh
pull-music
```

Source: `oldboy:/mnt/kontent/music` or `/Volumes/music`  
Dest: `/Volumes/Turtlehead/music`

---

### `push-music`

**Sync music to remote**

Pushes local music to remote server using rclone.

```sh
push-music
```

Source: `/Volumes/Turtlehead/music`  
Dest: `oldboy.local:/mnt/kontent/music` or `/Volumes/music`

---

## SYSTEM UTILITIES

### `unfuck-xcode`

**Fix corrupt Xcode CLI tools**

Removes and triggers reinstall of Xcode Command Line Tools.

```sh
unfuck-xcode
```

---

### `install-font-macos <urls...>`

**Install fonts from URLs**

Downloads, extracts, and installs OTF/TTF fonts to ~/Library/Fonts.

```sh
install-font-macos https://github.com/.../font.zip
```

---

### `install-terminfo <host>`

**Install terminfo to remote host**

Exports local terminfo and installs via SSH.

```sh
install-terminfo user@server
```

---

### `regen-zsh-completions`

**Regenerate shell completions**

Rebuilds completions for installed tools (docker, kubectl, gh, etc.).

```sh
regen-zsh-completions
```

---

### `gen-diff <image1> <image2> <output>`

**Generate visual image diff**

Creates difference image using ImageMagick.

```sh
gen-diff before.png after.png diff.png
```

---

### `prune-gen`

**Generate test directory structure**

Creates temp directory with various files for testing prune/cleanup scripts.

```sh
prune-gen
```

---

### `clean-dls [days]`

**Clean old downloads**

Deletes files from ~/Downloads older than specified days.

```sh
clean-dls 30    # Delete files > 30 days old
```

---

### `echo-to-file <text>`

**Write to temp file**

Writes arguments to `/tmp/echo-out`.

```sh
echo-to-file "hello world"
```

---

## DEVELOPMENT

### Build Tooling

```sh
just build    # Build and install to bin/
just check    # Quick build check
just clean    # Remove build artifacts
just fmt      # Format code
just test     # Run tests
```

### Project Structure

```
.
├── bin/                # Rust binaries (generated)
├── config/             # App configs (symlinked to ~/.config)
│   ├── ghostty/
│   ├── git/
│   ├── helix/
│   ├── ssh/
│   ├── starship/
│   └── zsh/
├── crates/             # Rust workspace
│   ├── src/
│   │   ├── bin/        # Binary sources (26 tools)
│   │   ├── lib.rs      # Shared library
│   │   ├── audio.rs    # Audio utilities
│   │   ├── banner.rs   # Terminal UI
│   │   ├── cli.rs      # CLI helpers
│   │   ├── parallel.rs # Parallel processing
│   │   └── process.rs  # Process management
│   └── Cargo.toml
├── Brewfile            # Homebrew packages
├── Justfile            # Build commands
└── install             # Symlink script
```

### Brewfile Organization

Organized by category: CORE, DEV TOOLS, LANGUAGES, BUILD TOOLS, LSPS, INFRA, NETWORKING, CLI UTILS, MEDIA, DATABASE, etc.

---

## CONTAINER USAGE

Full environment via Docker:

```sh
docker build -t dotfiles .
docker run -it dotfiles zsh
```

---

```
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
   [!] All tools support --help flag for detailed usage
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```
