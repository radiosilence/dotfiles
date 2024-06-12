if [ -d ~/.homebrew ]; then
  export BREW_PREFIX=~/.homebrew
elif [ -d /opt/homebrew ]; then
  export BREW_PREFIX=/opt/homebrew
else
  export BREW_PREFIX=/usr/local
fi

export PATH="$BREW_PREFIX/bin:$BREW_PREFIX/sbin:$PATH"
export HOMEBREW_BUNDLE_FILE="~/Brewfile"
