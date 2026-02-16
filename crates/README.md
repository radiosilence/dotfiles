# Rust Tooling

Rewrites of bash scripts. Faster, handles errors better, proper parallelism.

## Building

```bash
cd crates
cargo build --release
cargo install --path .
```

## Tools (23 binaries)

### Process / System

- **kill-port** - Kill process on port
- **upd** - System update orchestrator
- **unfuck-xcode** - Reset Xcode CLI tools
- **update-ffmpeg** - Update ffmpeg from evermeet

### Files

- **prune** - Delete small directories
- **prune-gen** - Generate prune configs
- **clean-dls** - Remove scene release garbage
- **clean-exif** - Strip EXIF from images
- **vimv** - Batch rename with editor
- **echo-to-file** - Write stdin to file
- **gen-diff** - Generate image diffs

### Git

- **git-sync** - Clean merged branches
- **git-squash** - Squash commits
- **git-trigger** - Amend + force push

### Audio / Media

- **to-audio** - Convert to FLAC/Opus with parallel processing
- **embed-art** - Embed album art in FLAC
- **extract-exif-from-flac** - Extract EXIF data from FLAC
- **imp** - Import music from URLs to beets

### Network / Install

- **url2base64** - URLs to base64
- **parallel-dl-extract** - Parallel download and extract
- **install-font-macos** - Install fonts from URLs
- **install-terminfo** - Install terminfo entries

### Meta

- **regen-zsh-completions** - Regenerate shell completions for all tools

## Dev

```bash
cargo check
cargo clippy --all-targets -- -D warnings
cargo test --all-targets
```

## Architecture

```
crates/
├── src/
│   ├── lib.rs               # Shared code
│   ├── audio.rs              # Audio utils
│   ├── install.rs            # Install helpers
│   ├── parallel.rs           # Parallel processing
│   ├── regen_completions.rs  # Completion generation
│   ├── update_ffmpeg.rs      # ffmpeg update logic
│   └── bin/                  # 23 binaries
└── Cargo.toml
```
