# Rust Tooling

High-performance replacements for shell scripts with cyberpunk aesthetic.

## Why Rust?

- **Type safety** - No more unbound variable errors
- **Performance** - Native parallelism with rayon, compiled speed
- **Error handling** - Proper error types with context
- **Cross-platform** - Works on Linux/macOS without modification
- **Testing** - Unit and integration tests built in
- **Progress bars** - Beautiful CLI feedback with indicatif

## Building

Requires Rust 1.70+. Install with `mise` or from [rustup.rs](https://rustup.rs/).

```bash
# Build all tools
cd tooling-rust
cargo build --release

# Install to ../bin/
just install

# Or build+install in one go
just
```

## Implemented Tools

### Process Management
- **kill-port** - Kill process listening on port (native lsof integration)

### File Management  
- **prune** - Find and delete small directories (with size preview)

### Git Utilities
- **git-sync** - Clean up merged branches (native git2 library)
- **git-squash** - Squash commits for PRs (native git2, interactive editor)
- **git-trigger** - Amend + force push to trigger CI
- **git-update** - Alias for git-trigger

### Audio Tools
- **to-opus** - Convert audio to Opus (parallel ffmpeg wrapper)
- **to-flac** - Convert audio to FLAC (parallel ffmpeg wrapper)
- **clean-exif** - Strip EXIF metadata from images (privacy protection)

### Utilities
- **url2base64** - Convert URLs to base64 data URLs (async HTTP with reqwest)
- **clean-dls** - Remove scene release garbage files

## Architecture

```
tooling-rust/
├── src/
│   ├── lib.rs          # Shared library
│   ├── audio.rs        # Audio processing utilities
│   ├── banner.rs       # Cyberpunk ASCII art
│   ├── cli.rs          # CLI helpers
│   ├── parallel.rs     # Parallel processing
│   ├── process.rs      # Process management
│   └── bin/            # Binary implementations
│       ├── kill-port.rs
│       ├── prune.rs
│       ├── to-opus.rs
│       └── ...
├── Cargo.toml          # Single package, multiple binaries
└── Justfile            # Build automation
```

## Shared Libraries

All tools share common code:

- **audio.rs** - FFmpeg wrappers, file finding, parallel processing
- **banner.rs** - Cyberpunk-styled terminal output
- **cli.rs** - Confirmation prompts, CPU detection
- **parallel.rs** - Rayon-based parallel file processing with progress bars
- **process.rs** - Process management via lsof

## Development

```bash
# Check code
cargo check

# Run tests
cargo test

# Run single tool in dev mode
just run kill-port 3000

# Watch and rebuild on changes
just watch

# Lint
just lint

# Format
just fmt
```

## Testing

Unit tests are inline:

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_bitrate_validation() {
        assert!(160 >= 32 && 160 <= 512);
    }
}
```

Integration tests go in `tests/`:

```rust
#[test]
fn test_kill_port_help() {
    Command::new("kill-port")
        .arg("--help")
        .assert()
        .success();
}
```

## TODO: Not Yet Implemented

- **vimv** - Batch file renaming (needs complex git integration)
- **embed-art** - FLAC artwork embedding (needs metaflac library)
- **gen-diff** - Image diff generation (needs image processing)
- **unfuck-xcode** - Xcode CLI tools reset
- **imp** - Music import utility

## Style Guide

### Cyberpunk Aesthetic

All tools use retro cyberpunk styling:

- ASCII art banners with glitch effects
- Status indicators: `□` for info, `!` for warnings, `◉` for success, `✖` for errors
- Progress bars with unicode blocks: `█▓░`
- Color scheme: cyan, magenta, green, yellow, red
- No emojis - pure 80s/90s terminal aesthetic

### Error Messages

Errors include full context:

```
   ✖ Failed to convert audio/track.wav
      caused by: ffmpeg process exited with code 1
```

### Progress Tracking

All parallel operations show real-time progress:

```
   ▸ [████████████████░░░░] 45/60 track.flac
```

## Performance

Rust tools are significantly faster than shell equivalents:

- **Parallel by default** - Uses all CPU cores automatically
- **No process spawning overhead** - Compiled binaries
- **Efficient I/O** - Buffered reads/writes
- **Zero-cost abstractions** - Rayon parallelism is free

Example: `to-opus` converting 100 FLAC files:
- Shell version: ~180s (GNU parallel + bash overhead)
- Rust version: ~90s (native rayon parallelism)

## Distribution

Binaries are copied to `../bin/` and committed to the repo.

For external distribution:
```bash
# Install from git
cargo install --git https://github.com/radiosilence/dotfiles --root ~/.local tooling-rust

# Or use pre-compiled binaries from releases
```
