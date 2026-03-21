# FZF configuration
command -v fzf >/dev/null || return

_cached_eval "fzf" "fzf --zsh"

if command -v bat >/dev/null; then
  alias fzf='fzf \
    --preview "bat --color=always --style=numbers --line-range=:500 {}"'
fi
