# FZF configuration
command -v fzf >/dev/null || return

_cached_eval "fzf" "fzf --zsh"
