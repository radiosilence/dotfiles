# Suvadu (agent-aware shell history, trialling alongside atuin) — `suv init`
# has no flag to pick keybinds, so load order decides: this sorts after
# fzf.zsh and before zz-atuin.zsh, leaving suvadu the up/down arrows and
# atuin ctrl-r. Both record every command; drop whichever loses the trial.
command -v suv >/dev/null || return

_cached_eval "suvadu" "suv init zsh" "$(command -v suv)"
