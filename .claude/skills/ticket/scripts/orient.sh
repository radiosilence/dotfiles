#!/usr/bin/env bash
# Phase 0 orient: deterministic git/gh probes. No LLM needed.
# Run from the worktree you intend to work in.
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
