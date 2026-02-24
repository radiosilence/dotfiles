set dotenv-load := false

dotfiles_dir := justfile_directory()

# Build and install rust binaries from crates/
reinstall-bins:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v cargo >/dev/null 2>&1; then
        printf "\033[31m  !! cargo not found\033[0m\n"
        exit 1
    fi
    cd "{{ dotfiles_dir }}/crates"
    bins=$(cargo metadata --no-deps --format-version 1 | jq -r '.packages[].targets[] | select(.kind[] == "bin") | .name')
    for bin in $bins; do
        if [ -f "$HOME/.cargo/bin/$bin" ]; then
            rm "$HOME/.cargo/bin/$bin"
            printf "  removed stale %s from ~/.cargo/bin\n" "$bin"
        fi
    done
    printf "\033[33m  -> building rust binaries...\033[0m\n"
    cargo install --path . --bins --root "{{ dotfiles_dir }}"
    printf "\033[32m  ok binaries -> ~/.dotfiles/bin\033[0m\n"
