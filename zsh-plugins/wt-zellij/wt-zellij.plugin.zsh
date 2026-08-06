# wt-zellij — zellij backend for wt-core.
# Load order is irrelevant: zsh resolves function bodies at call time.
command -v zellij >/dev/null || return
typeset -gx WT_ZELLIJ_BIN=${0:A:h}/bin


_wt_tab() {
  local name=$1 wt=$2
  if [[ -n $ZELLIJ ]]; then
    if zellij action query-tab-names 2>/dev/null | grep -qxF "$name"; then
      zellij action go-to-tab-name "$name"
    else
      zellij action new-tab --name "$name" --cwd "$wt" --close-on-exit -- "$WT_ZELLIJ_BIN/wt-shell" "$wt" "$name"
    fi
  else
    cd "$wt"
  fi
}

# write-chars targets the focused pane, which new-tab just made current. The
# tab's shell is still starting, hence the wait.
_wt_tab_prime() {
  [[ -n $ZELLIJ ]] || return 0
  sleep 0.5
  zellij action write-chars "claude \"/ticket $1\""
  zellij action write 13
}

# ── wtt — upsert worktree + zellij tab ──────────────────────────────
wtt()   { _wt_core  _wt_tab "$@"; }
wttpr() { _wt_pr    _wt_tab _wt_tab_prime "$@"; }
wtti()  { _wt_issue _wt_tab _wt_tab_prime "$@"; }
(( $+functions[compdef] )) && compdef _wt_comp wtt
zstyle ':fzf-tab:complete:wtt:*'  fzf-preview "$WT_CORE_BIN/wt-preview $word"
