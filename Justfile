# Build and install Rust tooling to bin/
build:
    cd tooling-rust && cargo install --path . --root .. --force

# Quick build without install
check:
    cd tooling-rust && cargo build --release

# Clean build artifacts
clean:
    cd tooling-rust && cargo clean
    rm -rf bin/
    rm -f .crates.toml .crates2.json

# Format code
fmt:
    cd tooling-rust && cargo fmt

# Run tests
test:
    cd tooling-rust && cargo test
