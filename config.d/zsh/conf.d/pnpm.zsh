# PNPM configuration
command -v pnpm >/dev/null || return

alias p='pnpm'
alias pi='pnpm install'
alias pt='pnpm test'
alias ptu='pnpm test -u'
alias pa='pnpm add'
alias paW='pnpm add -W'
alias paD='pnpm add -D'
alias paDW='pnpm add -DW'

# npm-style mirrors (n/ni/nr/nd → pn/pni/pnr/pnd)
alias pn='pnpm'
alias pni='pnpm install'
alias pnr='pnpm run'
alias pnd='pnpm run dev'

# Completions — pnpm 10 dropped built-in completion. Use g-plane/pnpm-shell-completion (installed via mise github backend).
_pnpm_plugin=( ${MISE_DATA_DIR:-$HOME/.local/share/mise}/installs/github-g-plane-pnpm-shell-completion/*/pnpm-shell-completion.plugin.zsh(N[-1]) )
[[ -n "$_pnpm_plugin" ]] && source $_pnpm_plugin
unset _pnpm_plugin

# Make aliases inherit pnpm's completion
for _a in p pi pt ptu pa paW paD paDW pn pni pnr pnd; do
  compdef $_a=pnpm 2>/dev/null
done
unset _a
