# Rust Rewrite Candidates

## High Priority - Complex Logic & Parallelism

### **kill-port**

**Why Rust:** Process management, error handling, cross-platform port checking
**Benefits:** Type-safe port parsing, better error messages, works on Linux too
**Deps:** `sysinfo` crate for process enumeration
**Complexity:** Low (good starting point)

### **prune**

**Why Rust:** Directory traversal, size calculations, interactive prompts
**Benefits:** Faster directory scanning, structured output, better size formatting
**Deps:** `walkdir`, `byte-unit`, `dialoguer`
**Complexity:** Medium

### **vimv**

**Why Rust:** File operations, git integration, complex rename logic
**Benefits:** Better validation, atomic operations, rollback on failure
**Deps:** `git2`, `tempfile`, `similar` (for diff preview)
**Complexity:** Medium

### **to-opus / to-flac / clean-exif** (Audio Pipeline)

**Why Rust:** Heavy parallel processing, FFmpeg integration, error recovery
**Benefits:** Rayon parallelism >>> GNU parallel, progress bars, resume on failure
**Deps:** `rayon`, `indicatif`, `walkdir`
**Complexity:** High (but shared logic)
**Note:** Could be one tool with subcommands: `audio-tools convert opus`, `audio-tools convert flac`

### **embed-art**

**Why Rust:** FLAC metadata manipulation, image processing, complex workflow
**Benefits:** Native FLAC library (no shelling out), atomic operations
**Deps:** `metaflac`, `image`, `rayon`
**Complexity:** High

### **url2base64**

**Why Rust:** HTTP requests, base64 encoding, streaming for large files
**Benefits:** Async HTTP, better error handling, stdin/stdout streaming
**Deps:** `reqwest`, `base64`, `tokio`
**Complexity:** Low-Medium

## Medium Priority - System Utilities

### **gen-diff**

**Why Rust:** Image manipulation, could avoid ImageMagick dependency
**Benefits:** Pure Rust image diff, faster processing
**Deps:** `image`, `imageproc`
**Complexity:** Medium

### **unfuck-xcode**

**Why Rust:** System commands, better error reporting
**Benefits:** Clearer what it's doing, dry-run mode, safer
**Deps:** `std::process::Command`
**Complexity:** Low

### **imp** (Import music)

**Why Rust:** Download + extract + import pipeline
**Benefits:** Async downloads, better error handling, progress tracking
**Deps:** `reqwest`, `zip`, `tokio`
**Complexity:** Medium

## Low Priority - Keep as Shell

### **git-sync / git-squash / git-trigger**

**Why Keep Shell:** Simple git command wrappers, no complex logic
**Note:** Could bundle into one Rust tool later if desired

### **setup-macos / rip-cd-setup**

**Why Keep Shell:** One-time bootstrap scripts, lots of interactive prompts
**Note:** Too much work to rewrite, shell is fine here

### **pull-music / push-music**

**Why Keep Shell:** Just rclone wrappers, no added value from Rust

### **install-terminfo / install-font-macos**

**Why Keep Shell:** Simple download/extract, shell is adequate

### **regen-zsh-completions**

**Why Keep Shell:** Zsh-specific, needs zsh anyway

## Proposed Rust Tools Structure

```
crates/
├── Cargo.toml              # Workspace manifest
├── audio-tools/            # Audio conversion pipeline
│   ├── Cargo.toml
│   └── src/
│       ├── main.rs         # CLI entry point
│       ├── convert.rs      # to-opus, to-flac
│       ├── metadata.rs     # embed-art, clean-exif
│       └── parallel.rs     # Shared parallel logic
├── kill-port/              # Process management
│   ├── Cargo.toml
│   └── src/main.rs
├── prune/                  # Directory cleanup
│   ├── Cargo.toml
│   └── src/main.rs
├── vimv/                   # Batch file renaming
│   ├── Cargo.toml
│   └── src/main.rs
├── url2base64/             # URL to base64 converter
│   ├── Cargo.toml
│   └── src/main.rs
└── shared/                 # Common utilities
    ├── Cargo.toml
    └── src/
        ├── lib.rs
        ├── parallel.rs     # Rayon helpers
        ├── logging.rs      # Structured logging
        └── cli.rs          # Common CLI patterns
```

## Build Strategy

1. **Cargo workspace** - Single `Cargo.toml` at root manages all tools
2. **Build script** - Copies binaries from `target/release/` to `bin/`
3. **Justfile or Makefile** - `just build` compiles and installs all tools
4. **CI/CD** - GitHub Actions builds on commit, releases binaries

## Migration Path

1. **Phase 1:** kill-port, url2base64 (simple, low risk)
2. **Phase 2:** prune, vimv (medium complexity)
3. **Phase 3:** audio-tools suite (high value, complex)
4. **Phase 4:** Consider remaining tools based on usage

## Key Benefits

- **Type safety:** No more unbound variables or silent failures
- **Performance:** Rayon parallelism + compiled speed
- **Cross-platform:** Works on Linux/macOS without modification
- **Distribution:** Single binary or `cargo install` from git
- **Testing:** Proper unit/integration tests
- **Error handling:** Structured errors with context
- **Progress bars:** Built-in with `indicatif`
- **Logging:** Structured with `tracing` or `env_logger`
