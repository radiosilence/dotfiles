#!/bin/zsh
set -e

# Activate mise shims
eval "$(mise activate zsh --shims)"

# Auto-clone if REPO is set and workspace is empty
if [[ -n "$DEVBOX_REPO" ]] && [[ ! -d /workspace/.git ]]; then
  printf '\033[35m󱁤\033[0m cloning %s\n' "$DEVBOX_REPO"
  git clone "$DEVBOX_REPO" /workspace
fi

# Install project-specific tools if config exists in workspace
if [[ -f /workspace/mise.toml ]] || [[ -f /workspace/.mise.toml ]] || [[ -f /workspace/.tool-versions ]]; then
  mise trust /workspace 2>/dev/null || true
  mise install 2>/dev/null || true
fi

# Warn about git deps in npm lockfiles
if [[ -f /workspace/package-lock.json ]]; then
  if grep -q '"resolved": "git[+:]' /workspace/package-lock.json 2>/dev/null; then
    printf '\033[31m!! git dependencies detected in lockfile — these bypass ignore-scripts\033[0m\n'
    grep '"resolved": "git[+:]' /workspace/package-lock.json
  fi
fi

exec "$@"
