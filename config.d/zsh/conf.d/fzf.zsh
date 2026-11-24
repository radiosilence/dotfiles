# FZF configuration
# fzf's shell integration (`fzf --zsh`: Ctrl-T, Alt-C, Ctrl-R, ** completion) is
# not loaded: lig owns completion and history, so there is one picker. fzf stays
# for the scripts and functions that pipe into it.
command -v fzf >/dev/null || return

if command -v bat >/dev/null; then
  alias fzf='fzf \
    --preview "bat --color=always --style=numbers --line-range=:500 {}"'
fi
