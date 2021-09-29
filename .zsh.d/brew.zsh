if is_cmd brew; then
  FPATH="$BREW_PREFIX/share/zsh/site-functions:${FPATH}"
  autoload -Uz compinit
  compinit
fi
