# Build and install Rust tooling to bin/
build:
    cd crates && cargo install --path . --root .. --force

# Quick build without install
check:
    cd crates && cargo build --release

# Clean build artifacts
clean:
    cd crates && cargo clean
    rm -rf bin/
    rm -f .crates.toml .crates2.json

# Format code
fmt:
    cd crates && cargo fmt

# Run tests
test:
    cd crates && cargo test --all-targets
