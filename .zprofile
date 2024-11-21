#!/usr/bin/env zsh
if [ -d ~/.homebrew ]; then
  export BREW_PREFIX=~/.homebrew
elif [ -d /opt/homebrew ]; then
  export BREW_PREFIX=/opt/homebrew
else
  export BREW_PREFIX=/usr/local
fi

export PATH="$BREW_PREFIX/bin:$BREW_PREFIX/sbin:$PATH"

if command -v mise &>/dev/null; then
  eval "$(mise activate zsh --shims)"
elif [ -x ~/.local/bin/mise ]; then
  eval "$(~/.local/bin/mise activate zsh --shims)"
fi

# Added by OrbStack: command-line tools and integration
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
