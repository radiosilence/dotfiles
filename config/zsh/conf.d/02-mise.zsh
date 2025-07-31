# Mise (runtime version manager)
command -v mise >/dev/null || return

eval "$(mise activate zsh)"

alias m='mise'
alias mi='mise i'
