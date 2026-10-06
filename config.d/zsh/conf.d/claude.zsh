\command -v claude >/dev/null || return

export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
export CLAUDE_CODE_NO_FLICKER=1

# Permission mode + remote control live in settings.json, not flags.
# CLAUDE_CONFIG_DIR stays in mise — work roots override it per-directory.

# c runs claude with op authenticated as the claude-code service account
# (read-only on the Claude vault), so op lookups in a remote-controlled session
# never wait on Touch ID. The token lives in the login keychain; plain `claude`
# keeps the desktop-app integration.
unalias c 2>/dev/null
c() {
  local token
  if token=$(security find-generic-password -s op-claude-code -a "$USER" -w 2>/dev/null); then
    OP_SERVICE_ACCOUNT_TOKEN=$token command claude "$@"
  else
    command claude "$@"
  fi
}
