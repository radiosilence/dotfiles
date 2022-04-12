if [ -d ~/.homebrew ]; then
  export BREW_PREFIX=~/.homebrew
elif [ -d /opt/homebrew ]; then
  export BREW_PREFIX=/opt/homebrew
elif [ -d /usr/local/homebrew ]; then
  export BREW_PREFIX=/usr/local/homebrew
fi

export HOMEBREW_CASK_OPTS=--no-quarantine
export PATH="$BREW_PREFIX/bin:$BREW_PREFIX/sbin:$PATH"

if is_cmd brew; then
  FPATH="$BREW_PREFIX/share/zsh/site-functions:${FPATH}"
  autoload -Uz compinit
  compinit -u
fi
