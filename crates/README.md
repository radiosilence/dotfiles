# Rust Tooling

Rewrites of bash scripts with cyberpunk aesthetic. Faster, handles errors better.

## Why Rust?

Type safety, native parallelism, better error handling. Shell scripts were hitting limits.

## Building

```bash
cd crates
cargo build --release

# Install to ../bin/
just install
```

## Tools

### Process

- **kill-port** - Kill process on port
- **upd** - System update orchestrator

### Files

- **prune** - Delete small directories
- **clean-dls** - Remove scene release garbage
- **clean-exif** - Strip EXIF from images
- **vimv** - Batch rename with editor

### Git

- **git-sync** - Clean merged branches
- **git-squash** - Squash commits
- **git-trigger** - Amend + force push

### Audio

- **to-audio** - Convert to FLAC/Opus with parallel processing
- **embed-art** - Embed album art in FLAC
- **imp** - Import music from URLs to beets

### Misc

- **url2base64** - URLs to base64
- **install-font-macos** - Install fonts from URLs
- **unfuck-xcode** - Reset Xcode CLI tools

## Dev

```bash
cargo check
cargo test
just run kill-port 3000
just watch
```

## Architecture

```
crates/
├── src/
│   ├── lib.rs          # Shared code
│   ├── audio.rs        # Audio utils
│   ├── banner.rs       # Terminal UI
│   └── bin/            # 26 binaries
└── Cargo.toml
```

Shared modules: audio, banner, cli, parallel processing.
