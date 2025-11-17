# Rust Tooling

Rewrites of bash scripts with cyberpunk aesthetic. Faster, handles errors better.

## Why Rust?

Type safety, native parallelism, better error handling. Shell scripts were hitting limits.

## Building

```bash
cd tooling-rust
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

- **to-opus** - Convert to Opus
- **to-flac** - Convert to FLAC
- **embed-art** - Embed album art in FLAC
- **imp** - Import music archives

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
tooling-rust/
├── src/
│   ├── lib.rs          # Shared code
│   ├── audio.rs        # Audio utils
│   ├── banner.rs       # Terminal UI
│   └── bin/            # 26 binaries
└── Cargo.toml
```

Shared modules: audio, banner, cli, parallel processing.
