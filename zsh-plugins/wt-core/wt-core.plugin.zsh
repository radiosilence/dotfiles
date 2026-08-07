# wt-core — git worktree management, backend-agnostic.
# Worktrees live at <repo-parent>/worktrees/<repo>/<name>, derived from the
# repo itself so per-org layouts (and any mise env scoped to them) hold.
# Git worktree management (wt*)
# Worktrees live in <repo-parent>/worktrees/<repo>/<name>/ — outside the repo
# so editors / file watchers don't recursively index them.
command -v git >/dev/null || return

# Exported so sibling backends and the bin/ scripts locate shared helpers
# without hardcoding a dotfiles path.
typeset -gx WT_CORE_BIN=${0:A:h}/bin

# ── Helpers ──────────────────────────────────────────────────────────

_wt_root() {
  local common
  common=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || return 1
  echo "${common%/.git}"
}

_wt_base() {
  local ref
  ref=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null) \
    && echo "${ref##refs/remotes/origin/}" || echo "main"
}

_wt_dir() {
  local root=$(_wt_root) || return 1
  echo "$(dirname "$root")/worktrees/$(basename "$root")"
}

_wt_path() { echo "$(_wt_dir)/${1}"; }

_wt_ensure_dir() {
  local dir=$(_wt_dir)
  [[ -d $dir ]] || mkdir -p "$dir"
}

_wt_find() { "$WT_CORE_BIN"/wt-list "$1"; }

# branch<TAB>path, minus detached worktrees — picker fodder.
_wt_named() { "$WT_CORE_BIN"/wt-list | awk -F'\t' '$1 != ""'; }

_wt_cd() { cd "$2"; }

_wt_fzf_preview='$WT_CORE_BIN/wt-preview {1}'

# ── Core upsert logic ───────────────────────────────────────────────
# _wt_core <go_fn> [--branch] [name] [base]
# go_fn is called with (name, path) — either _wt_cd or _wt_tab
_wt_core() {
  local go_fn=$1; shift
  local from_branch=0
  while [[ $# -gt 0 ]]; do
    case $1 in
      --branch|-b) from_branch=1; shift ;;
      --) shift; break ;;
      *) break ;;
    esac
  done

  # No args: fzf picker
  if [[ $# -eq 0 ]] && (( ! from_branch )); then
    if ! command -v fzf >/dev/null; then
      git worktree list
      return
    fi
    local output query selected
    output=$(_wt_named \
      | fzf --ansi --reverse --delimiter=$'\t' --with-nth=1 \
             --header="worktrees (type new name to create)" \
             --popup='center,90%,90%' --preview "$_wt_fzf_preview" --preview-window='right:70%' \
             --print-query
    ) || true
    query=$(echo "$output" | sed -n '1p')
    selected=$(echo "$output" | sed -n '2p')

    if [[ -n $selected ]]; then
      $go_fn "$(echo "$selected" | cut -f1)" "$(echo "$selected" | cut -f2)"
    elif [[ -n $query ]]; then
      # New name typed — delegate to the create path
      set -- "$query"
    else
      return
    fi
    [[ -n $selected ]] && return
  fi

  [[ $# -eq 0 ]] && { echo "usage: wt [-b] <name> [base]"; return 1; }

  local name=$1 base
  local wt=$(_wt_path "$name")

  # Upsert: worktree exists at expected path
  if [[ -d $wt ]]; then
    $go_fn "$name" "$wt"
    return
  fi

  # Upsert: branch checked out in a different location
  local existing=$(_wt_find "$name")
  if [[ -n $existing ]]; then
    $go_fn "$name" "$existing"
    return
  fi

  # Resolve base ref
  if (( from_branch )); then
    base=$(git symbolic-ref --short HEAD 2>/dev/null) || { echo "not on a branch"; return 1; }
  else
    base=${2:-$(_wt_base)}
  fi

  _wt_ensure_dir

  if (( from_branch )); then
    git worktree add "$wt" -b "$name" HEAD || return 1
  else
    git fetch origin "$base" --quiet || return 1
    git fetch origin "$name" --quiet 2>/dev/null

    git worktree add "$wt" "$name" 2>/dev/null \
      || git worktree add "$wt" -b "$name" "origin/$name" 2>/dev/null \
      || git worktree add "$wt" -b "$name" "origin/$base" \
      || return 1
  fi

  $go_fn "$name" "$wt"
}

# ── wt — upsert worktree + cd ───────────────────────────────────────
wt()  { _wt_core _wt_cd "$@"; }

# Local checkout for an owner/repo. GitHub owner matches the directory under
# ~/workspace, so <org>/<repo> lives at the same path.
_wt_repo_root() {
  local owner=$1 repo=$2 p
  # (N) or a miss aborts the loop with "no matches found" before the message below
  for p in "$HOME/workspace/$owner/$repo" "$HOME/workspace"/*/"$repo"(N); do
    [[ -d $p/.git ]] && { echo "$p"; return 0; }
  done
  echo "no local checkout for $owner/$repo under ~/workspace" >&2
  return 1
}

# ── GitHub refs ─────────────────────────────────────────────────────
# <n> | <url> | owner/repo#<n> → "owner<TAB>repo<TAB>num<TAB>root". A bare
# number resolves against the current repo; qualified forms find the checkout
# under ~/workspace. owner/repo stay empty for the bare form.
_wt_ref_parse() {
  local arg=$1 owner repo num root
  if [[ $arg =~ '^https?://[^/]+/([^/]+)/([^/]+)/(pull|issues)/([0-9]+)' ]]; then
    owner=$match[1] repo=$match[2] num=$match[4]
    root=$(_wt_repo_root "$owner" "$repo") || return 1
  elif [[ $arg =~ '^([^/]+)/([^#]+)#([0-9]+)$' ]]; then
    owner=$match[1] repo=$match[2] num=$match[3]
    root=$(_wt_repo_root "$owner" "$repo") || return 1
  elif [[ $arg == <-> ]]; then
    num=$arg
    root=$(_wt_root) || { echo "not in a git repo — pass a url" >&2; return 1; }
  else
    echo "unrecognised reference: $arg" >&2; return 1
  fi
  print -r -- "$owner"$'\t'"$repo"$'\t'"$num"$'\t'"$root"
}

# gh against an explicit repo when the ref named one, else against root's remote
_wt_gh() {
  local root=$1 owner=$2 repo=$3; shift 3
  if [[ -n $owner ]]; then
    gh "$@" --repo "$owner/$repo"
  else
    (builtin cd "$root" && gh "$@")
  fi
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

# ── _wt_pr <go_fn> <prime_fn> <ref> ─────────────────────────────────
# Takes a PR or an issue: a URL disambiguates itself (/pull/ vs /issues/), and
# a bare number is probed — GitHub numbers both from one sequence, and
# `gh pr view` only resolves PRs, so a failure means issue.
_wt_pr() {
  local go_fn=$1 prime_fn=$2 arg=$3
  command -v gh >/dev/null || { echo "gh not found"; return 1; }
  [[ -z $arg ]] && { echo "usage: <number|url|owner/repo#N>  (PR or issue)"; return 1; }
  [[ $arg == *"/issues/"* ]] && { _wt_issue "$go_fn" "$prime_fn" "$arg"; return; }

  local parsed; parsed=$(_wt_ref_parse "$arg") || return 1
  local owner repo num root
  IFS=$'\t' read -r owner repo num root <<< "$parsed"

  _wt_gh "$root" "$owner" "$repo" pr view "$num" --json number -q .number >/dev/null 2>&1 \
    || { _wt_issue "$go_fn" "$prime_fn" "$arg"; return; }

  local branch
  branch=$(_wt_gh "$root" "$owner" "$repo" pr view "$num" --json headRefName -q .headRefName)
  [[ -n $branch ]] || { echo "could not resolve PR #$num"; return 1; }

  # PR head may not exist locally; refs/pull works for forks too
  git -C "$root" fetch origin "pull/${num}/head:${branch}" --quiet 2>/dev/null \
    || git -C "$root" fetch origin "$branch" --quiet 2>/dev/null

  (builtin cd "$root" && _wt_core "$go_fn" "$branch")
}

# ── _wt_issue <go_fn> <prime_fn> <ref> ──────────────────────────────
# Worktree named <n>-<slug>, then prime_fn gets the issue number to hand off to
# claude. `claude <prompt>` starts interactively — -p is what makes it batch —
# so the session that lands in the pane is live.
_wt_issue() {
  local go_fn=$1 prime_fn=$2 arg=$3
  command -v gh >/dev/null || { echo "gh not found"; return 1; }
  [[ -z $arg ]] && { echo "usage: <issue-number|issue-url>"; return 1; }

  local parsed; parsed=$(_wt_ref_parse "$arg") || return 1
  local owner repo num root
  IFS=$'\t' read -r owner repo num root <<< "$parsed"

  local title
  title=$(_wt_gh "$root" "$owner" "$repo" issue view "$num" --json title -q .title)
  [[ -n $title ]] || { echo "could not resolve issue #$num"; return 1; }

  local slug=$(_wt_issue_slug "$num" "$title")
  print -r -- "→ $slug"
  (builtin cd "$root" && _wt_core "$go_fn" "$slug") || return 1
  "$prime_fn" "$num"
}

# ── wtrm [name] ─────────────────────────────────────────────────────
# No args: remove the worktree you're currently inside, cd to repo root
wtrm() {
  local root=$(_wt_root)
  local here=$(git rev-parse --show-toplevel 2>/dev/null)
  local name wt

  if [[ -n $1 ]]; then
    name=$1
    # Registered location wins: a worktree moved off the convention still dies.
    wt=$(_wt_find "$name"); [[ -n $wt ]] || wt=$(_wt_path "$name")
  else
    wt=$here
    [[ -z $wt || $wt == "$root" ]] && { echo "not inside a worktree"; return 1; }
    name=$(basename "$wt")
  fi

  [[ -d $wt ]] || { echo "no worktree at $wt"; return 1; }
  builtin cd "$root"
  git worktree remove "$wt" || return 1
  # -d refuses on squash-merged branches, which is most of them.
  if ! git branch -d "$name" 2>/dev/null; then
    local repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
    case $(_wt_pr_state "$name" "$repo") in
      MERGED|CLOSED) git branch -D "$name" 2>/dev/null ;;
    esac
  fi
  echo "removed: $name"

  # Only when the tab being closed is the one we were standing in — otherwise
  # close-tab kills whichever tab is current, which is the wrong one.
  if [[ -n $ZELLIJ && $here == "$wt" ]]; then
    zellij action close-tab
  fi
}

# ── wtclean [-n] ────────────────────────────────────────────────────
# Runs as bin/wtclean, not as this function: it mutates no shell state, so
# there is no reason for a shell that was started three commits ago to be the
# thing executing it. The shim below re-reads the script every invocation.
# Everything is squash-merged, so a merged branch still looks unmerged to
# `git branch --merged` and nothing ever gets reclaimed. GitHub's PR state is
# the only reliable signal; without gh, a deleted upstream stands in for it.
# Uncommitted work always wins — a dirty worktree is never touched.

# One list call up front — a query per branch turns a sweep into a minute of
# round trips. Branches past the window fall through to a direct query.
typeset -gA _wt_prs
_wt_pr_cache() {
  local repo=$1 branch state
  _wt_prs=()
  [[ -z $repo ]] && return
  while IFS=$'\t' read -r branch state; do
    [[ -n $branch ]] && _wt_prs[$branch]=$state
  done < <(gh pr list -R "$repo" --state all --limit 200 \
    --json headRefName,state --jq '.[] | [.headRefName, .state] | @tsv' 2>/dev/null)
}

# MERGED | CLOSED | OPEN | NONE
_wt_pr_state() {
  local branch=$1 repo=$2 state=${_wt_prs[$1]}
  [[ -n $state ]] && { echo "$state"; return }
  if [[ -n $repo ]]; then
    state=$(gh pr list -R "$repo" --head "$branch" --state all --limit 1 \
      --json state --jq '.[0].state // "NONE"' 2>/dev/null)
    [[ -n $state ]] && { echo "$state"; return }
  fi
  [[ $(git for-each-ref --format='%(upstream:track)' "refs/heads/$branch") == *gone* ]] \
    && echo MERGED || echo NONE
}

# Fan a snippet (which reads its item as "$1") over stdin lines. GNU parallel
# when it's installed, xargs -P otherwise. Both pass the item as a real
# argument rather than substituting it textually, so paths survive intact.
# -k/-I keep output in input order.
_wt_fan() {
  local snippet=$1
  if command -v parallel >/dev/null; then
    parallel --will-cite -k -q sh -c "$snippet" _ {}
  else
    xargs -P 8 -I {} sh -c "$snippet" _ {}
  fi
}

_wt_clean() {
  local root=$(_wt_root)
  [[ -z $root ]] && { echo "not in a git repo"; return 1; }
  local dry=0
  [[ $1 == -n || $1 == --dry-run ]] && dry=1

  local here=$(git rev-parse --show-toplevel 2>/dev/null)
  local repo=$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null)
  [[ -z $repo ]] && echo "  no gh — falling back to deleted-upstream detection"
  git -C "$root" fetch --prune --quiet 2>/dev/null
  _wt_pr_cache "$repo"

  # Classify on cheap facts only — nothing here touches the working tree.
  # Split by hand: tab is IFS-whitespace, so `read` would collapse the empty
  # branch field of a detached worktree and shift the path into it.
  local line wt branch label removed=0 kept=0
  local -a agents candidates cand_branch
  while IFS= read -r line; do
    branch=${line%%$'\t'*}
    wt=${line#*$'\t'}
    [[ -z $wt || $wt == "$root" ]] && continue
    label=${branch:-$wt}
    git worktree unlock "$wt" 2>/dev/null

    # Agent worktrees are session detritus — always force, never probed.
    [[ $wt == */.claude/worktrees/* ]] && { agents+=("$wt"); continue }
    [[ $wt == "$here" ]] && { echo "  kept:    $label (you're in it)"; ((kept++)); continue }
    [[ -z $branch ]] && { echo "  kept:    $label (detached)"; ((kept++)); continue }
    candidates+=("$wt"); cand_branch+=("$branch")
  done < <("$WT_CORE_BIN"/wt-list)

  # `git status` walks the whole working tree, which on a monorepo is the
  # expensive part of the run. Each worktree is independent, so fan them out.
  local -A dirty
  local d
  if (( ${#candidates} )); then
    while IFS=$'\t' read -r wt d; do
      dirty[$wt]=$d
    done < <(printf '%s\n' $candidates \
      | _wt_fan 'printf "%s\t%s\n" "$1" "$(git -C "$1" status --porcelain 2>/dev/null | wc -l | tr -d " ")"')
  fi

  local -a doomed doomed_branch
  local i state
  for (( i = 1; i <= ${#candidates}; i++ )); do
    wt=$candidates[i]; branch=$cand_branch[i]
    if (( ${dirty[$wt]:-0} > 0 )); then
      echo "  kept:    $branch (uncommitted changes)"; ((kept++)); continue
    fi
    state=$(_wt_pr_state "$branch" "$repo")
    case $state in
      MERGED|CLOSED)
        if (( dry )); then
          echo "  would remove: $branch (PR $state)"
        else
          doomed+=("$wt"); doomed_branch+=("$branch")
        fi ;;
      OPEN) echo "  kept:    $branch (PR open)"; ((kept++)) ;;
      *)    echo "  kept:    $branch (no PR)"; ((kept++)) ;;
    esac
  done

  # Removal is almost entirely rm -rf, and concurrent `git worktree remove`
  # touches only its own admin directory — no shared lock to contend on.
  if (( dry )); then
    (( ${#agents} )) && printf '  would nuke (agent): %s\n' $agents
  else
    (( ${#agents} )) && printf '%s\n' $agents | _wt_fan 'git worktree remove --force "$1" 2>/dev/null'
    (( ${#doomed} )) && printf '%s\n' $doomed | _wt_fan 'git worktree remove "$1" 2>/dev/null'

    # Report on what actually went: removal still refuses on a locked or
    # in-use worktree, and a fanned-out exit status won't tell us which.
    for wt in $agents; do
      [[ -d $wt ]] || { echo "  removed (agent): $wt"; ((removed++)) }
    done
    for (( i = 1; i <= ${#doomed}; i++ )); do
      if [[ -d $doomed[i] ]]; then
        echo "  kept:    $doomed_branch[i] (in use)"; ((kept++))
      else
        echo "  removed: $doomed_branch[i]"; ((removed++))
      fi
    done
  fi

  # Branches whose worktree is gone — including the ones just removed, since
  # this reads the registry fresh.
  local base=$(_wt_base) b dropped=0
  local -a live drop
  live=(${(f)"$(_wt_named | cut -f1)"})
  for b in ${(f)"$(git -C "$root" for-each-ref --format='%(refname:short)' refs/heads/)"}; do
    [[ $b == "$base" ]] && continue
    (( ${live[(Ie)$b]} )) && continue
    state=$(_wt_pr_state "$b" "$repo")
    if [[ $state == MERGED || $state == CLOSED ]]; then
      (( dry )) && { echo "  would drop branch: $b (PR $state)"; continue }
      drop+=("$b")
    elif git -C "$root" merge-base --is-ancestor "$b" "origin/$base" 2>/dev/null; then
      (( dry )) && { echo "  would drop branch: $b (merged)"; continue }
      drop+=("$b")
    fi
  done
  # One invocation, not one per branch: many refs is a single packed-refs
  # rewrite, and racing deletions would contend for its lock.
  if (( ${#drop} )); then
    git -C "$root" branch -D $drop >/dev/null 2>&1
    for b in $drop; do
      git -C "$root" show-ref --verify --quiet "refs/heads/$b" \
        || { echo "  dropped branch: $b"; ((dropped++)) }
    done
  fi

  local -a pruneargs=(-v); (( dry )) && pruneargs+=(-n)
  git worktree prune $pruneargs
  _wt_prs=()   # scoped to the run — a stale map misclassifies later calls
  echo "wtclean: removed $removed, kept $kept, dropped $dropped branch(es)"
}

wtclean() { "$WT_CORE_BIN"/wtclean "$@"; }

# ── Completions ─────────────────────────────────────────────────────
_wt_branches() {
  local -a branches
  branches=(${(f)"$(_wt_named | cut -f1)"})
  _describe 'worktree' branches
}

_wt_comp() {
  _arguments '--branch[derive from current branch]' '-b[derive from current branch]' \
    '1:branch:_wt_branches' '2:base:'
}
# compdef only exists once compinit has run. The picker sources this plugin
# non-interactively to reuse its functions, and that must not spew errors.
if (( $+functions[compdef] )); then
  compdef _wt_comp wt
  compdef '_arguments "1:branch:_wt_branches"' wtrm
fi

# ── fzf-tab previews ────────────────────────────────────────────────
zstyle ':fzf-tab:complete:wt:*'   fzf-preview "$WT_CORE_BIN/wt-preview $word"
zstyle ':fzf-tab:complete:wtrm:*' fzf-preview "$WT_CORE_BIN/wt-preview $word"
