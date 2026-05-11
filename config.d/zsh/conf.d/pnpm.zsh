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

# pnpm's first-party `pnpm completion zsh` doesn't read package.json scripts,
# so `pnpm run <TAB>` only suggests flags. g-plane/pnpm-shell-completion fixes
# that. Installed via mise; locate it via `mise where` rather than hardcoding.
if (( $+commands[mise] )); then
  _pnpm_completion_dir=$(mise where pnpm-shell-completion 2>/dev/null)
  [[ -n "$_pnpm_completion_dir" && -r "$_pnpm_completion_dir/pnpm-shell-completion.plugin.zsh" ]] \
    && source "$_pnpm_completion_dir/pnpm-shell-completion.plugin.zsh"
  unset _pnpm_completion_dir
fi
