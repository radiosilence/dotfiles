# Rust Tooling

Tools that genuinely benefit from Rust: parallelism, binary format parsing, git2 library, cross-protocol socket introspection.

## Building

```bash
cd crates
cargo build --release
cargo install --path .
```

## Tools (10 binaries)

### Process / System

- **kill-port** - Kill process on port (netstat2 + nix signal handling)

### Files

- **prune** - Delete small directories (walkdir + dialoguer)
- **clean-dls** - Remove scene release garbage (word-boundary matching)
- **clean-exif** - Strip EXIF from images (img-parts binary rewriting)

### Git

- **git-sync** - Clean merged branches (git2 branch tracking)
- **git-squash** - Squash commits (git2 merge-base + revwalk)

### Audio / Media

- **to-audio** - Convert to FLAC/Opus with parallel processing (rayon + indicatif)
- **embed-art** - Embed album art in FLAC (img-parts EXIF stripping)
- **extract-exif-from-flac** - Extract EXIF data from FLAC (binary format verification)

### Meta

- **regen-zsh-completions** - Regenerate shell completions for all tools

## Demoted to shell scripts

These were over-engineered Rust wrappers around CLI tools. Now live in `scripts/`:

`unfuck-xcode`, `url2base64`, `install-font-macos`, `parallel-dl-extract`, `prune-gen`, `vimv`, `imp`

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
│   ├── parallel.rs           # Parallel processing
│   ├── config.rs             # Config loading
│   ├── regen_completions.rs  # Completion generation
│   └── bin/                  # 10 binaries
└── Cargo.toml
```
