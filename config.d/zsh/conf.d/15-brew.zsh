# Homebrew configuration
# Nothing here applies on Linux, where mise owns every tool brew would provide.
if [[ -d /opt/homebrew ]]; then
  export BREW_PREFIX=/opt/homebrew
elif [[ -x /usr/local/bin/brew ]]; then
  export BREW_PREFIX=/usr/local
else
  return
fi

path=("$BREW_PREFIX/bin" "$BREW_PREFIX/sbin" $path)
export PATH

command -v brew >/dev/null || return

export HOMEBREW_BUNDLE_FILE="~/Brewfile"

# brew bundle's built-in parallel installer defaults to min(cores, 4). Lift the
# cap to all cores — formula installs fan out, casks stay serial (sudo prompts).
export HOMEBREW_BUNDLE_JOBS="$(sysctl -n hw.ncpu 2>/dev/null || nproc)"

alias bb='brew bundle'
