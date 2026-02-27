# Mise (runtime version manager)
command -v mise >/dev/null || return

_cached_eval "mise" "mise activate zsh"

alias m='mise'
alias mi='mise i'
