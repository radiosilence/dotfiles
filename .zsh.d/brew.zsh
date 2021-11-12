if is_cmd brew; then
  export HOMEBREW_CASK_OPTS=--no-quarantine
  FPATH="$BREW_PREFIX/share/zsh/site-functions:${FPATH}"
  autoload -Uz compinit
  compinit
fi
