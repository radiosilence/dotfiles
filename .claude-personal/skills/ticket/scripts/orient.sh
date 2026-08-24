#!/usr/bin/env bash
# Where am I, and has this already been done? Deterministic git/gh probes.
# Run from the worktree you intend to work in. Optional arg: issue number or URL.
set -uo pipefail

section() { printf '\n=== %s ===\n' "$1"; }

section "cwd"
pwd

section "branch"
git symbolic-ref --short HEAD 2>/dev/null || echo "(detached HEAD)"

section "repo root"
git rev-parse --show-toplevel 2>/dev/null || echo "(not a git repo)"

section "commits since main"
git log --oneline main..HEAD 2>/dev/null || echo "(no main branch reachable, or no diverging commits)"

section "working tree status"
git status --short

section "existing PR for this branch"
branch=$(git branch --show-current 2>/dev/null)
if [[ -n "$branch" ]]; then
  gh pr list --head "$branch" --json number,title,state,url,isDraft 2>/dev/null \
    || echo "(gh not available or no PR for branch '$branch')"
else
  echo "(no current branch)"
fi

issue="${1:-}"
if [[ -n "$issue" ]]; then
  section "issue"
  gh issue view "$issue" --json number,title,state,url,labels,assignees,closedAt 2>/dev/null \
    || echo "(could not read issue '$issue')"

  section "PRs mentioning the issue"
  gh pr list --search "$issue" --state all --json number,title,state,url 2>/dev/null \
    || echo "(none, or gh unavailable)"
fi
