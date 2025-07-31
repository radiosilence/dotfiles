# FZF configuration
command -v fzf >/dev/null || return

eval "$(fzf --zsh)"
