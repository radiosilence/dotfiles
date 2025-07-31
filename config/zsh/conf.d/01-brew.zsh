# Homebrew configuration
if [[ -d /opt/homebrew ]]; then
  export BREW_PREFIX=/opt/homebrew
else
  export BREW_PREFIX=/usr/local
fi

path=("$BREW_PREFIX/bin" "$BREW_PREFIX/sbin" $path)
export PATH

command -v brew >/dev/null || return

export HOMEBREW_BUNDLE_FILE="~/Brewfile"
alias bb='brew bundle'
