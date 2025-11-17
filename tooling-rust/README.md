# Rust Tooling

High-performance replacements for shell scripts with cyberpunk aesthetic.

## Why Rust?

- **Type safety** - No unbound variable errors
- **Performance** - Native parallelism, compiled speed
- **Error handling** - Proper error types with context
- **Cross-platform** - Works on Linux/macOS
- **Testing** - Unit and integration tests built in

## Building

Requires Rust 1.70+:

```bash
# From repo root
just build    # Build and install to bin/

# From tooling-rust/
cargo build --release
cargo install --path . --root ..
```

## Architecture

```
tooling-rust/
├── src/
│   ├── lib.rs          # Shared library
│   ├── audio.rs        # Audio processing
│   ├── banner.rs       # Cyberpunk UI
│   ├── cli.rs          # CLI helpers
│   ├── parallel.rs     # Parallel processing
│   ├── process.rs      # Process management
│   └── bin/            # 26 binary implementations
├── Cargo.toml          # Single package, multiple binaries
└── Justfile
```

## Development

```bash
cargo check           # Quick compile check
cargo test           # Run tests
cargo clippy         # Lint
cargo fmt            # Format
```

## Cyberpunk Aesthetic

All tools use retro terminal styling:

- ASCII art banners with glitch effects
- Status: `□` info, `!` warning, `✓` success, `✗` error
- Progress bars: `█▓▒░`
- Colors: cyan, magenta, green, yellow, red
- No emojis - pure 80s/90s aesthetic

## Performance

Rust tools are significantly faster than shell equivalents due to:

- Parallel by default (rayon)
- No process spawning overhead
- Compiled binaries
- Zero-cost abstractions

Example: `to-opus` converting 100 FLAC files:

- Shell + GNU parallel: ~180s
- Rust + rayon: ~90s
