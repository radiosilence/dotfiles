# Suvadu (agent-aware shell history) — records every command for the suvadu
# MCP server (`suv mcp-serve`) to query. `suv init` unconditionally binds
# ctrl-r to its own search widget, but we want fzf on ctrl-r, so we reclaim
# it below. Suvadu keeps the up/down arrows for native history cycling.
command -v suv >/dev/null || return

_cached_eval "suvadu" "suv init zsh" "$(command -v suv)"

# Hand ctrl-r back to fzf (fzf.zsh loads first, then suvadu steals ^R above).
command -v fzf >/dev/null && bindkey '^R' fzf-history-widget
