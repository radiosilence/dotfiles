# wt-herdr — Herdr app backend for wt-core.
# Each worktree is a Herdr space. Herdr's own worktree mod keeps checkouts under
# ~/.herdr/worktrees, outside ~/workspace where the work mise.toml never applies,
# so agents there would run on the personal Claude profile. Paths come from
# wt-core, which derives them from the repo, so they land in the right org tree
# and inherit the right profile; Herdr is only asked to show them.
command -v herdr-app >/dev/null || return

# wt-core calls the backend in a subshell, so the space reaches its caller
# through a file; $$ is the same in both. Line 1 is the space id, line 2 the
# terminal of a space made just now (empty when an existing one was selected).
_wt_herdr_handoff() { print -r -- "${TMPDIR:-/tmp}/wt-herdr.$$"; }

# Selects the space already made for this worktree, else makes one.
_wt_herdr() {
  local name=$1 wt=$2 id out
  rm -f "$(_wt_herdr_handoff)"
  id=$(herdr-app ls 2>/dev/null | jq -r --arg wt "$wt" \
    'first(.spaces[] | select(.folder == $wt and .machine == null) | .id) // empty')
  if [[ -n $id ]]; then
    herdr-app do space.select --id "$id" >/dev/null
    print -rl -- "$id" "" >"$(_wt_herdr_handoff)"
    return
  fi
  out=$(herdr-app do space.new --name "$name" --folder "$wt" 2>&1) || {
    print -u2 "herdr-app: $out"
    return 1
  }
  jq -r '.space // "", .terminal // ""' <<<"$out" >"$(_wt_herdr_handoff)"
}

# ── wth — upsert worktree + Herdr space ─────────────────────────────
# No args: fzf picker over existing worktrees, or type a name to create one.
wth() { _wt_core _wt_herdr "$@"; }

# Starts Claude on the issue in a space wth just made; an existing space is
# left as it is.
_wt_herdr_prime() {
  local f=$(_wt_herdr_handoff) term
  [[ -s $f ]] || return 0
  term=$(sed -n 2p "$f"); rm -f "$f"
  [[ -n $term ]] || return 0
  hc send "$term" "claude \"Work issue #$1\"" >/dev/null
}

# ── wtpr <PR-or-issue ref> / wti <issue ref> ────────────────────────
wtpr() { _wt_pr    _wt_herdr _wt_herdr_prime "$@"; }
wti()  { _wt_issue _wt_herdr _wt_herdr_prime "$@"; }

# ── wtpr-space <ref> <file> ─────────────────────────────────────────
# wtpr for programs: opens or selects the worktree's space, primes nothing, and
# writes the space id to <file>. No file means it failed; wt-core's output (its
# errors go to stdout) is then left in <file>.log for the caller to show.
wtpr-space() {
  local f=$(_wt_herdr_handoff) out=$2 id
  [[ -n $1 && -n $out ]] || { print -u2 "usage: wtpr-space <ref> <file>"; return 1; }
  rm -f "$f" "$out" "$out.log"
  _wt_pr _wt_herdr : "$1" >"$out.log" 2>&1
  id=$(sed -n 1p "$f" 2>/dev/null); rm -f "$f"
  [[ -n $id ]] || { print -r -- "wtpr-space: no space for $1" >>"$out.log"; return 1; }
  rm -f "$out.log"
  print -r -- "$id" >"$out"
}
