# FZF configuration
command -v fzf >/dev/null || return

# Inside lig, fzf's shell integration (Ctrl-T, Alt-C, Ctrl-R, ** completion) is
# not loaded, so completion and history go through one picker. Shells lig does
# not wrap (LIG_DISABLE, no tty, lig missing) keep it.
[[ -n $LIG_TTY && $LIG_TTY == $TTY ]] || _cached_eval "fzf" "fzf --zsh" "$(command -v fzf)"

if command -v bat >/dev/null; then
  alias fzf='fzf \
    --preview "bat --color=always --style=numbers --line-range=:500 {}"'
fi
