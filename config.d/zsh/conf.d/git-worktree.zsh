# Git worktree management (wt*)
# Worktrees live in <repo-root>/.worktrees/<name>/
command -v git >/dev/null || return

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

_wt_path() { echo "$(_wt_root)/.worktrees/${1}"; }

_wt_ensure_dir() {
  local dir=$(_wt_root)/.worktrees
  [[ -d $dir ]] || mkdir -p "$dir"
  [[ -f $dir/.gitignore ]] || echo '*' > "$dir/.gitignore"
}

_wt_find() {
  git worktree list --porcelain 2>/dev/null \
    | awk -v b="refs/heads/$1" '/^worktree /{ wt=$2 } /^branch /{ if($2==b) print wt }'
}

_wt_cd() { cd "$2"; }

_wt_tab() {
  local name=$1 wt=$2
  if [[ -n $ZELLIJ ]]; then
    if zellij action query-tab-names 2>/dev/null | grep -qxF "$name"; then
      zellij action go-to-tab-name "$name"
    else
      zellij action new-tab --name "$name" --cwd "$wt" --close-on-exit -- zsh
    fi
  else
    cd "$wt"
  fi
}

_wt_fzf_preview='
  b=$(echo {} | cut -f1)
  p=$(echo {} | cut -f2)
  { mise x -- lsd -A --color=always --icon=always --tree --depth 2 "$p" 2>/dev/null || ls "$p"; } \
  && echo "" \
  && git -C "$p" log --oneline --graph --color=always --stat -10 "$b" 2>/dev/null
'

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
    local selected
    selected=$(git worktree list --porcelain \
      | awk '/^worktree /{ path=$2 } /^branch /{ branch=$2; sub("refs/heads/","",branch); printf "%s\t%s\n", branch, path }' \
      | fzf --ansi --reverse --with-nth=1 --header="worktrees" \
             --preview "$_wt_fzf_preview"
    ) || return
    $go_fn "$(echo "$selected" | cut -f1)" "$(echo "$selected" | cut -f2)"
    return
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

# ── wtt — upsert worktree + zellij tab ──────────────────────────────
wtt() { _wt_core _wt_tab "$@"; }

# ── wtpr <PR-number> ────────────────────────────────────────────────
wtpr() {
  command -v gh >/dev/null || { echo "gh not found"; return 1; }
  local pr=$1
  [[ -z $pr ]] && { echo "usage: wtpr <PR-number>"; return 1; }

  local branch
  branch=$(gh pr view "$pr" --json headRefName -q .headRefName) || return 1
  local wt=$(_wt_path "$branch")

  if [[ -d $wt ]]; then
    _wt_tab "$branch" "$wt"
    return
  fi

  local existing=$(_wt_find "$branch")
  if [[ -n $existing ]]; then
    _wt_tab "$branch" "$existing"
    return
  fi

  _wt_ensure_dir

  git fetch origin "pull/${pr}/head:${branch}" --quiet 2>/dev/null \
    || git fetch origin "$branch" --quiet || return 1

  git worktree add "$wt" "$branch" || return 1
  _wt_tab "$branch" "$wt"
}

# ── wtd <name> ──────────────────────────────────────────────────────
wtd() {
  local name=$1
  [[ -z $name ]] && { echo "usage: wtd <name>"; return 1; }
  local wt=$(_wt_path "$name")
  [[ -d $wt ]] || { echo "no worktree at $wt"; return 1; }
  [[ "$PWD" == "$wt"* ]] && { echo "cd out of the worktree first"; return 1; }
  git worktree remove "$wt" || return 1
  git branch -d "$name" 2>/dev/null
  echo "removed: $name"
}

# ── wtrm [name] ─────────────────────────────────────────────────────
# No args: remove the worktree you're currently inside, cd to repo root
wtrm() {
  local root=$(_wt_root)
  local name wt

  if [[ -n $1 ]]; then
    name=$1
    wt=$(_wt_path "$name")
  else
    # Detect current worktree
    wt=$(git rev-parse --show-toplevel 2>/dev/null)
    [[ $wt == "$root" ]] && { echo "not inside a worktree"; return 1; }
    name=$(basename "$wt")
  fi

  [[ -d $wt ]] || { echo "no worktree at $wt"; return 1; }
  cd "$root"
  git worktree remove "$wt" || return 1
  git branch -d "$name" 2>/dev/null
  echo "removed: $name"
}

# ── wtp ─────────────────────────────────────────────────────────────
alias wtp='git worktree prune -v'

# ── Completions ─────────────────────────────────────────────────────
_wt_branches() {
  local -a branches
  branches=(${(f)"$(git worktree list --porcelain 2>/dev/null \
    | awk '/^branch /{ b=$2; sub("refs/heads/","",b); print b }')"})
  _describe 'worktree' branches
}

_wt_comp() {
  _arguments '--branch[derive from current branch]' '-b[derive from current branch]' \
    '1:branch:_wt_branches' '2:base:'
}
compdef _wt_comp wt
compdef _wt_comp wtt
compdef '_arguments "1:branch:_wt_branches"' wtd
compdef '_arguments "1:branch:_wt_branches"' wtrm

# ── fzf-tab previews ────────────────────────────────────────────────
_wt_tab_preview='
  p=$(git worktree list --porcelain 2>/dev/null \
    | awk -v b="refs/heads/$word" "/^worktree /{ wt=\$2 } /^branch /{ if(\$2==b) print wt }")
  [[ -n $p ]] || exit 0
  { mise x -- lsd -A --color=always --icon=always --tree --depth 2 "$p" 2>/dev/null || ls "$p"; }
  echo ""
  git -C "$p" log --oneline --graph --color=always --stat -10 "$word" 2>/dev/null
'
zstyle ':fzf-tab:complete:wt:*'   fzf-preview "$_wt_tab_preview"
zstyle ':fzf-tab:complete:wtt:*'  fzf-preview "$_wt_tab_preview"
zstyle ':fzf-tab:complete:wtd:*'  fzf-preview "$_wt_tab_preview"
zstyle ':fzf-tab:complete:wtrm:*' fzf-preview "$_wt_tab_preview"
