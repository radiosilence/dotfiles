# Suvadu (agent-aware shell history) — records every command for the suvadu
# MCP server (`suv mcp-serve`) to query. `suv init` unconditionally binds
# ctrl-r to its own search widget; lig intercepts ctrl-r in its pty before the
# shell sees it, so the binding is moot. Suvadu keeps the up/down arrows.
command -v suv >/dev/null || return

_cached_eval "suvadu" "suv init zsh" "$(command -v suv)"

