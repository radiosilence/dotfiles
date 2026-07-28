# GitHub configuration
command -v gh >/dev/null || return

# GitHub's remote MCP server only does OAuth for hosts with a pre-registered
# GitHub App (VS Code, Cursor); github.com exposes no DCR endpoint, so Claude
# Code has to send a bearer token instead. Borrow gh's, so there's no second
# credential to rotate.
export GITHUB_MCP_TOKEN="$(gh auth token 2>/dev/null)"
