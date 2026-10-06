#!/usr/bin/env bash
# Gives every Bash command in a session the claude-code 1Password service
# account (read-only on the Claude vault), however claude was launched, so op
# never waits on Touch ID. The env file holds a command substitution, so the
# token is read from the login keychain when sourced and never written to disk.
[[ -n ${CLAUDE_ENV_FILE:-} ]] || exit 0
security find-generic-password -s op-claude-code -a "$USER" >/dev/null 2>&1 || exit 0
echo 'export OP_SERVICE_ACCOUNT_TOKEN="$(security find-generic-password -s op-claude-code -a "$USER" -w 2>/dev/null)"' >> "$CLAUDE_ENV_FILE"
