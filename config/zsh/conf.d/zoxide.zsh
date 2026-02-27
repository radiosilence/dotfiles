# Zoxide (smart cd)
command -v zoxide >/dev/null || return

_cached_eval "zoxide" "zoxide init zsh"
