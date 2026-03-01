# Mise (runtime version manager)
command -v mise >/dev/null || return

_cached_eval "mise-shims" "mise activate zsh --shims"

alias m='mise'
alias mi='mise i'
