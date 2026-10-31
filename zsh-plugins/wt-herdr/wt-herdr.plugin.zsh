# wt-herdr — Herdr app backend for wt-core.
# Each worktree is a Herdr space. Herdr's own worktree mod keeps checkouts under
# ~/.herdr/worktrees, outside ~/workspace where the work mise.toml never applies,
# so agents there would run on the personal Claude profile. Paths come from
# wt-core, which derives them from the repo, so they land in the right org tree
# and inherit the right profile; Herdr is only asked to show them.
command -v herdr-app >/dev/null || return

# wt-core calls the backend in a subshell, so the new space's terminal reaches
# _wt_herdr_prime through a file; $$ is the same in both.
_wt_herdr_handoff() { print -r -- "${TMPDIR:-/tmp}/wt-herdr.$$"; }

# Selects the space already made for this worktree, else makes one.
_wt_herdr() {
  local name=$1 wt=$2 id out
  rm -f "$(_wt_herdr_handoff)"
  id=$(herdr-app ls 2>/dev/null | jq -r --arg wt "$wt" \
    'first(.spaces[] | select(.folder == $wt and .machine == null) | .id) // empty')
  if [[ -n $id ]]; then
    herdr-app do space.select --id "$id" >/dev/null
    return
  fi
  out=$(herdr-app do space.new --name "$name" --folder "$wt" 2>&1) || {
    print -u2 "herdr-app: $out"
    return 1
  }
  jq -r '.terminal // empty' <<<"$out" >"$(_wt_herdr_handoff)"
}

# ── wth — upsert worktree + Herdr space ─────────────────────────────
# No args: fzf picker over existing worktrees, or type a name to create one.
wth() { _wt_core _wt_herdr "$@"; }

# Starts Claude on the issue in a space wth just made; an existing space is
# left as it is.
_wt_herdr_prime() {
  local f=$(_wt_herdr_handoff) term
  [[ -s $f ]] || return 0
  term=$(<$f); rm -f "$f"
  hc send "$term" "claude \"Work issue #$1\"" >/dev/null
}

# ── wtpr <PR-or-issue ref> / wti <issue ref> ────────────────────────
wtpr() { _wt_pr    _wt_herdr _wt_herdr_prime "$@"; }
wti()  { _wt_issue _wt_herdr _wt_herdr_prime "$@"; }
