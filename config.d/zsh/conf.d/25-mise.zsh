# Mise (runtime version manager)
# Every PATH edit must sort before this file. mise treats a PATH changed since
# its last hook-env as dirty, so a later edit makes the first prompt redo the
# full environment evaluation (hundreds of ms) instead of taking the fast path.
command -v mise >/dev/null || return

_cached_eval "mise" "mise activate zsh" "$(command -v mise)"

alias m='mise'
alias mi='mise i'
alias mr='mise run '
