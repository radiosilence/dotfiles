# Rust Tooling

Rewrites of bash scripts. Faster, handles errors better, proper parallelism.

## Building

```bash
cd crates
cargo build --release
cargo install --path .
```

## Tools (16 binaries)

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

### Git

- **git-sync** - Clean merged branches
- **git-squash** - Squash commits

### Audio / Media

- **to-audio** - Convert to FLAC/Opus with parallel processing
- **embed-art** - Embed album art in FLAC
- **extract-exif-from-flac** - Extract EXIF data from FLAC
- **imp** - Import music from URLs to beets

### Network / Install

- **url2base64** - URLs to base64
- **parallel-dl-extract** - Parallel download and extract

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
│   ├── update_ffmpeg.rs      # ffmpeg update logic
│   └── bin/                  # 16 binaries
└── Cargo.toml
```
