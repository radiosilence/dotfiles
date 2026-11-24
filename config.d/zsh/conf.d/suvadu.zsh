# Suvadu (agent-aware shell history) — records every command for the suvadu
# MCP server (`suv mcp-serve`) to query. `suv init` unconditionally binds
# ctrl-r to its own search widget. Inside lig, ctrl-r never reaches the shell;
# elsewhere it goes back to fzf (fzf.zsh loads first, then suvadu takes ^R).
command -v suv >/dev/null || return

_cached_eval "suvadu" "suv init zsh" "$(command -v suv)"

[[ -n $LIG_TTY && $LIG_TTY == $TTY ]] || { (( $+widgets[fzf-history-widget] )) && bindkey '^R' fzf-history-widget; }

