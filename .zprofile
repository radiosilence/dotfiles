#!/usr/bin/env zsh
if command -v mise &>/dev/null; then
  eval "$(mise activate zsh)"
elif [ -x ~/.local/bin/mise ]; then
  eval "$(~/.local/bin/mise activate zsh)"
fi

# Added by OrbStack: command-line tools and integration
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
