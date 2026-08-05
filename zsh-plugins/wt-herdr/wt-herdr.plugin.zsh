# wt-herdr — herdr backend for wt-core.
# herdr's own [worktrees] directory is a single global root with no {org}
# placeholder, so it cannot express a per-org layout; paths come from
# wt-core instead and herdr is only asked to open them.
command -v herdr >/dev/null || return


# herdr's own worktree management is unusable here: [worktrees] directory is a
# single global root with no {org} placeholder, so it cannot reproduce the
# per-org layout, and its default (~/.herdr/worktrees) sits outside ~/workspace
# where the work mise.toml never applies — agents there would run on the
# personal Claude profile. Paths computed here derive from the repo, so they
# land in the right org tree and inherit the right profile.
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

# ── wtpr <PR-number|PR-url|owner/repo#N> ────────────────────────────
# Opens the PR's worktree as a herdr workspace, creating either if absent.
wtpr() {
  command -v gh >/dev/null || { echo "gh not found"; return 1; }
  command -v herdr >/dev/null || { echo "herdr not found"; return 1; }
  local arg=$1
  [[ -z $arg ]] && { echo "usage: wtpr <PR-number|PR-url|owner/repo#N>"; return 1; }

  local owner repo pr root
  if [[ $arg =~ '^https?://[^/]+/([^/]+)/([^/]+)/pull/([0-9]+)' ]]; then
    owner=$match[1] repo=$match[2] pr=$match[3]
    root=$(_wt_repo_root "$owner" "$repo") || return 1
  elif [[ $arg =~ '^([^/]+)/([^#]+)#([0-9]+)$' ]]; then
    owner=$match[1] repo=$match[2] pr=$match[3]
    root=$(_wt_repo_root "$owner" "$repo") || return 1
  elif [[ $arg == <-> ]]; then
    pr=$arg
    root=$(_wt_root) || { echo "not in a git repo — pass a PR url"; return 1; }
  else
    echo "unrecognised PR reference: $arg"; return 1
  fi

  local branch
  if [[ -n $owner ]]; then
    branch=$(gh pr view "$pr" --repo "$owner/$repo" --json headRefName -q .headRefName)
  else
    branch=$(cd "$root" && gh pr view "$pr" --json headRefName -q .headRefName)
  fi
  [[ -n $branch ]] || { echo "could not resolve PR #$pr"; return 1; }

  # PR head may not exist locally; refs/pull works for forks too
  git -C "$root" fetch origin "pull/${pr}/head:${branch}" --quiet 2>/dev/null \
    || git -C "$root" fetch origin "$branch" --quiet 2>/dev/null

  # herdr resolves the repo from --cwd and owns workspace creation
  herdr worktree open --cwd "$root" --branch "$branch" --focus 2>/dev/null && return 0
  herdr worktree create --cwd "$root" --branch "$branch" \
    --path "$(dirname "$root")/worktrees/$(basename "$root")/${branch:t}" --focus
}

# Slug matching the convention already used across these repos:
# <issue-number>-<kebab-title>, e.g. 931-rating-reconciliation
_wt_issue_slug() {
  local n=$1 title=$2 slug
  slug=${title:l}
  slug=${slug//[^a-z0-9]/-}          # non-alnum -> dash
  while [[ $slug == *--* ]]; do slug=${slug//--/-}; done
  slug=${slug##-}; slug=${slug%%-}
  slug=${slug[1,48]}; slug=${slug%%-}
  print -r -- "${n}-${slug}"
}

# ── wti <issue-number|issue-url> ────────────────────────────────────
# Worktree named <n>-<slug> for a GitHub issue, opened as a herdr workspace,
# with claude primed on /ticket <n>. `claude <prompt>` starts interactively —
# -p is what makes it non-interactive — so the session is live, not batch.
wti() {
  command -v gh >/dev/null || { echo "gh not found"; return 1; }
  local arg=$1
  [[ -z $arg ]] && { echo "usage: wti <issue-number|issue-url>"; return 1; }

  local owner repo num root
  if [[ $arg =~ '^https?://[^/]+/([^/]+)/([^/]+)/issues/([0-9]+)' ]]; then
    owner=$match[1] repo=$match[2] num=$match[3]
    root=$(_wt_repo_root "$owner" "$repo") || return 1
  elif [[ $arg =~ '^([^/]+)/([^#]+)#([0-9]+)$' ]]; then
    owner=$match[1] repo=$match[2] num=$match[3]
    root=$(_wt_repo_root "$owner" "$repo") || return 1
  elif [[ $arg == <-> ]]; then
    num=$arg
    root=$(_wt_root) || { echo "not in a git repo — pass an issue url"; return 1; }
  else
    echo "unrecognised issue reference: $arg"; return 1
  fi

  local title
  if [[ -n $owner ]]; then
    title=$(gh issue view "$num" --repo "$owner/$repo" --json title -q .title)
  else
    title=$(builtin cd "$root" && gh issue view "$num" --json title -q .title)
  fi
  [[ -n $title ]] || { echo "could not resolve issue #$num"; return 1; }

  local slug=$(_wt_issue_slug "$num" "$title")
  print -r -- "→ $slug"
  (builtin cd "$root" && _wt_core _wt_herdr "$slug") || return 1

  # Prime the new pane. worktree open --focus leaves it current.
  local pane
  pane=$(herdr pane current --current 2>/dev/null \
         | python3 -c 'import sys,json;print(json.load(sys.stdin)["result"]["pane"]["pane_id"])' 2>/dev/null)
  [[ -n $pane ]] || return 0
  herdr pane send-text "$pane" "claude \"/ticket $num\"" >/dev/null 2>&1
  herdr pane send-keys "$pane" enter >/dev/null 2>&1
}
