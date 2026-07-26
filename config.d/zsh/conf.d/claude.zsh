command -v claude >/dev/null || return

# claude / c — auto-pick the profile for $PWD from ~/.config/ai-profiles/claude.yaml.
# ~/.claude is claude's NATIVE home (config at ~/.claude.json in $HOME) — pointing
# CLAUDE_CONFIG_DIR at it makes claude hunt for ~/.claude/.claude.json and re-onboard.
# So only override for a real isolated profile (e.g. ~/.claude-personal); otherwise run
# native. No config / no matching root -> native.
claude() {
  local dir args
  IFS=$'\t' read -r dir args < <(_ai_profile ~/.config/ai-profiles/claude.yaml)
  if [[ -n $dir && $dir != $HOME/.claude ]]; then
    CLAUDE_CONFIG_DIR="$dir" command claude --dangerously-skip-permissions ${=args} "$@"
  else
    command claude --dangerously-skip-permissions ${=args} "$@"
  fi
}
alias c=claude

# cjc — force the PERSONAL profile regardless of cwd. --remote-control is personal-only
# (the work org disables Remote Control by policy). First run: `cjc` then `/login`.
cjc() {
  CLAUDE_CONFIG_DIR="$HOME/.claude-personal" command claude --dangerously-skip-permissions --remote-control "$@"
}
