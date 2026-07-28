\command -v claude >/dev/null || return

export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
export CLAUDE_CODE_NO_FLICKER=1

# Permission mode + remote control live in settings.json, not flags.
# CLAUDE_CONFIG_DIR stays in mise — work roots override it per-directory.
alias c='claude '
