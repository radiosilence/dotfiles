# PNPM completion — aliases are handled by @antfu/ni now.
# Direct `pnpm <TAB>` still wants completion: pnpm's first-party
# `pnpm completion zsh` doesn't read package.json scripts, so we keep the
# g-plane plugin (installed via mise) for that. Locate it via `mise where`.
command -v pnpm >/dev/null || return

if (( $+commands[mise] )); then
  _pnpm_completion_dir=$(mise where pnpm-shell-completion 2>/dev/null)
  [[ -n "$_pnpm_completion_dir" && -r "$_pnpm_completion_dir/pnpm-shell-completion.plugin.zsh" ]] \
    && source "$_pnpm_completion_dir/pnpm-shell-completion.plugin.zsh"
  unset _pnpm_completion_dir
fi
