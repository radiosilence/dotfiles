# Atuin (shell history) — zz- prefix so this loads AFTER fzf.zsh: both bind
# ctrl-r and last writer wins. fzf keeps ctrl-t (files) and alt-c (cd).
# --disable-up-arrow keeps native up-arrow; atuin lives on ctrl-r only.
command -v atuin >/dev/null || return

_cached_eval "atuin" "atuin init zsh --disable-up-arrow" "$(command -v atuin)"
