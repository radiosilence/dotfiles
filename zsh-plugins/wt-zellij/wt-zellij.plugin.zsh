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

# ── wtt — upsert worktree + zellij tab ──────────────────────────────
wtt() { _wt_core _wt_tab "$@"; }
compdef _wt_comp wtt
zstyle ':fzf-tab:complete:wtt:*'  fzf-preview '~/.dotfiles/scripts/wt-preview $word'
