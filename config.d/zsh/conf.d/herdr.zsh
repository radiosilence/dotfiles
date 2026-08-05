# Helpers invoked from herdr popups ([[keys.command]] in config.d/herdr/config.toml).
# Popups inherit HERDR_ACTIVE_PANE_CWD, so they act on the pane you launched from
# rather than wherever the popup shell happens to start.
command -v herdr >/dev/null || return

_herdr_cwd() { print -r -- "${HERDR_ACTIVE_PANE_CWD:-$PWD}"; }

# fzf over open PRs in the current repo, or paste any reference wtpr understands
# (URL / owner/repo#N / number). --print-query returns what was typed when it
# matches no row, so a pasted URL falls straight through to wtpr — which also
# means it works for repos other than the one the popup was opened in.
wtpr-pick() {
  command -v gh >/dev/null || { echo "gh not found"; read -k1; return 1; }
  command -v fzf >/dev/null || { echo "fzf not found"; read -k1; return 1; }
  builtin cd "$(_herdr_cwd)" 2>/dev/null

  # Author is its own column so fzf can filter on it; the query starts on your
  # own login, so it opens showing your PRs and backspacing reveals everyone's.
  local me=${GH_LOGIN:-$(gh api user -q .login 2>/dev/null)}

  local out
  out=$(gh pr list --limit 200 \
          --json number,author,headRefName,title,isDraft \
          -q '.[] | "\(.number)\t@\(.author.login)\t\(.headRefName)\t\(if .isDraft then "[draft] " else "" end)\(.title)"' 2>/dev/null \
        | column -t -s $'\t' \
        | fzf --print-query --query="$me " --prompt='PR or URL > ' \
              --height=100% --border --nth=1,2,3 \
              --header='enter on a row · clear query for all authors · or paste a PR url / owner/repo#N' \
              --preview='gh pr view {1} --comments 2>/dev/null | head -80')

  # line 1 is the query, line 2 the selected row (absent when nothing matched).
  # Must split into a real array — ${${(f)out}[1]} indexes characters, not lines.
  local -a lines=("${(@f)out}")
  local query=${lines[1]} sel=${lines[2]}
  local ref
  if [[ -n $sel ]]; then
    ref=${sel%% *}
  elif [[ $query =~ '(https?://[^[:space:]]+)' ]]; then
    ref=$match[1]                      # a paste lands after the author query
  elif [[ $query =~ '([^[:space:]/]+/[^[:space:]#]+#[0-9]+)' ]]; then
    ref=$match[1]
  elif [[ $query =~ '([0-9]+)' ]]; then
    ref=$match[1]
  fi
  [[ -n $ref ]] || return 0

  # The popup dies the moment this returns, so hold it open on failure —
  # otherwise the error flashes and vanishes.
  if ! wtpr "$ref"; then
    print -u2 "\nwtpr failed for: $ref"
    print -u2 "any key to close"
    read -k1
    return 1
  fi
}

# Popup entry for the worktree picker. herdr's native open_worktree/new_worktree
# are prefix-gated instead: they use its global [worktrees] directory, which
# cannot express the per-org layout the profile split depends on.
wth-pick() {
  local cwd=$(_herdr_cwd)
  builtin cd "$cwd" 2>/dev/null || { print -u2 "cannot cd: $cwd"; read -k1; return 1; }
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    print -u2 "not a git repo: $cwd"
    print -u2 "any key to close"; read -k1; return 1
  fi
  if ! wth; then
    print -u2 "\nwth failed in: $cwd"
    print -u2 "any key to close"; read -k1; return 1
  fi
}

# Issue picker → worktree. Same shape as wtpr-pick: --print-query means a pasted
# URL falls through untouched when it matches no row.
wti-pick() {
  command -v gh >/dev/null || { echo "gh not found"; read -k1; return 1; }
  builtin cd "$(_herdr_cwd)" 2>/dev/null

  local me=${GH_LOGIN:-$(gh api user -q .login 2>/dev/null)}
  local out
  out=$(gh issue list --limit 200 --json number,assignees,labels,title \
          -q '.[] | "\(.number)\t\(if (.assignees|length)>0 then "@"+.assignees[0].login else "-" end)\t\([.labels[].name]|join(","))\t\(.title)"' 2>/dev/null \
        | column -t -s $'\t' \
        | fzf --print-query --query="$me " --prompt='issue or URL > ' \
              --height=100% --border --nth=1,2,3 \
              --header='enter on a row · clear query for all · or paste an issue url' \
              --preview='gh issue view {1} --comments 2>/dev/null | head -80')

  local -a lines=("${(@f)out}")
  local query=${lines[1]} sel=${lines[2]} ref
  if [[ -n $sel ]]; then
    ref=${sel%% *}
  elif [[ $query =~ '(https?://[^[:space:]]+)' ]]; then ref=$match[1]
  elif [[ $query =~ '([^[:space:]/]+/[^[:space:]#]+#[0-9]+)' ]]; then ref=$match[1]
  elif [[ $query =~ '([0-9]+)' ]]; then ref=$match[1]
  fi
  [[ -n $ref ]] || return 0

  if ! wti "$ref"; then
    print -u2 "\nwti failed for: $ref"
    print -u2 "any key to close"; read -k1; return 1
  fi
}
