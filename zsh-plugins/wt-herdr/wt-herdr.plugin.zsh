# wt-herdr — herdr backend for wt-core.
# herdr's own worktree management is unusable here: [worktrees] directory is a
# single global root with no {org} placeholder, so it cannot reproduce the
# per-org layout, and its default (~/.herdr/worktrees) sits outside ~/workspace
# where the work mise.toml never applies — agents there would run on the
# personal Claude profile. Paths come from wt-core, which derives them from the
# repo, so they land in the right org tree and inherit the right profile;
# herdr is only asked to open them.
command -v herdr >/dev/null || return

# --cwd must be the main checkout: herdr rejects a linked worktree as the source
# ("New and open worktree actions start from the repo parent workspace"). It
# also reports errors as JSON with exit 0, so the payload has to be inspected.
_wt_herdr() {
  local wt=$2 root out
  root=$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
  root=${root%/.git}
  out=$(herdr worktree open --cwd "$root" --path "$wt" --focus 2>&1)
  if [[ $out == *'"error"'* ]]; then
    print -u2 "herdr: ${out}"
    return 1
  fi
}

# ── wth — upsert worktree + herdr workspace ─────────────────────────
# No args: fzf picker over existing worktrees, or type a name to create one.
wth() { _wt_core _wt_herdr "$@"; }

# Prime the new pane. worktree open --focus leaves it current.
_wt_herdr_prime() {
  local pane
  pane=$(herdr pane current --current 2>/dev/null | jq -r '.result.pane.pane_id' 2>/dev/null)
  [[ -n $pane && $pane != null ]] || return 0
  herdr pane send-text "$pane" "claude \"/ticket $1\"" >/dev/null 2>&1
  herdr pane send-keys "$pane" enter >/dev/null 2>&1
}

# ── wtpr <PR-or-issue ref> / wti <issue ref> ────────────────────────
wtpr() { _wt_pr    _wt_herdr _wt_herdr_prime "$@"; }
wti()  { _wt_issue _wt_herdr _wt_herdr_prime "$@"; }
