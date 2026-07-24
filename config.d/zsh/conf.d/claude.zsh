command -v claude >/dev/null || return

alias claude='claude --dangerously-skip-permissions'
alias c='claude --dangerously-skip-permissions'

# claude-me / cjc — run Claude as the PERSONAL account.
#
# CLAUDE_CONFIG_DIR gives the personal profile its own everything — OAuth login,
# settings, MCP servers, session history — fully isolated from the default work
# login in ~/.claude. It's a real browser /login (not an OAuth token), so
# subscription-only features like /remote work. First run: `claude-me` then
# `/login` with the personal account. Only cjc gets --remote-control: the work
# org disables Remote Control by policy, so the flag is dead weight there.
#
# We copy the work CLAUDE.md into the personal profile on each launch so the
# persona + rules stay in sync (this clobbers any personal-only edits to that
# file — swap the `cp` for a `[[ -f ]] ||` guard if you'd rather seed it once).
export CLAUDE_PERSONAL_DIR="${CLAUDE_PERSONAL_DIR:-$HOME/.claude-personal}"

claude-me() {
  mkdir -p "$CLAUDE_PERSONAL_DIR"
  [[ -f "$HOME/.claude/CLAUDE.md" ]] && cp "$HOME/.claude/CLAUDE.md" "$CLAUDE_PERSONAL_DIR/CLAUDE.md"
  CLAUDE_CONFIG_DIR="$CLAUDE_PERSONAL_DIR" command claude --dangerously-skip-permissions --remote-control "$@"
}
alias cjc='claude-me'
