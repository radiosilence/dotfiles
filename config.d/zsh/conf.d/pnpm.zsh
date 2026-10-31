# PNPM completion — aliases are handled by @antfu/ni now.
# Direct `pnpm <TAB>` still wants completion: pnpm's first-party
# `pnpm completion zsh` doesn't read package.json scripts, so we keep the
# g-plane plugin (installed via mise) for that. Globbed from mise's install dir
# rather than `mise where`, which costs a ~50ms fork on every shell start.
command -v pnpm >/dev/null || return

# pnpm() {
#   NPM_AUTH_TOKEN=$(op read "op://Personal/npm-work/token") command pnpm "$@"
# }

_pnpm_completion=( ${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/installs/pnpm-shell-completion/*/pnpm-shell-completion.plugin.zsh(N-.nOn[1]) )
(( $#_pnpm_completion )) && source $_pnpm_completion
unset _pnpm_completion
