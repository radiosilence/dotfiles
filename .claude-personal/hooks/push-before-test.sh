#!/usr/bin/env bash
# PreToolUse(Bash): slow local checks run in the background, and never while
# committed work is unpushed. CI runs the same suite, so testing before pushing
# only delays CI. Dirty-tree runs are allowed so test-driven debugging works.
set -euo pipefail

input=$(cat)
cmd=$(jq -r '.tool_input.command // ""' <<<"$input")
cwd=$(jq -r '.cwd // ""' <<<"$input")
bg=$(jq -r '.tool_input.run_in_background // false' <<<"$input")

slow='(^|[;&|[:space:]])((npm|pnpm|yarn|bun|aube|mise|task|just|make)( run)? +(test|typecheck|tsc|check|build|ci)([:[:space:]]|$)|cargo +(test|nextest|build|check|clippy)|go +(test|build|vet)|swift +(test|build)|mix +test|(npx +)?(tsc|vitest|jest|pytest|playwright)([[:space:]]|$)|xcodebuild)'

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput: {
    hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}

grep -Eq "$slow" <<<"$cmd" || exit 0
[ "$bg" = true ] || deny "Slow checks run with run_in_background so the session is not blocked. Re-run this in the background."
grep -q 'git push' <<<"$cmd" && exit 0

cd "${cwd:-.}" 2>/dev/null || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0
git remote | grep -q . || exit 0

if upstream=$(git rev-parse --abbrev-ref '@{u}' 2>/dev/null); then
  ahead=$(git rev-list --count "$upstream..HEAD")
else
  base=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
  ahead=$(git rev-list --count "$base..HEAD" 2>/dev/null || echo 0)
fi
[ "$ahead" -gt 0 ] || exit 0

deny "HEAD has $ahead unpushed commit(s). Push first (open or update the PR), then run slow checks in the background while CI runs."
