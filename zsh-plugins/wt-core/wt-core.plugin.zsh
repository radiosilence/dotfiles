# wt-core — git worktree management, backend-agnostic.
# Worktrees live at <repo-parent>/worktrees/<repo>/<name>, derived from the
# repo itself so per-org layouts (and any mise env scoped to them) hold —
# outside the repo, so editors and file watchers don't recursively index them.
#
# This file is only a loader. The commands live one function per file in
# functions/ and autoload on first use, so a shell that never touches a
# worktree never defines them.
command -v git >/dev/null || return

# Exported so sibling backends and the bin/ scripts locate shared helpers
# without hardcoding a dotfiles path.
typeset -gx WT_CORE_BIN=${0:A:h}/bin

# Globbed rather than listed, so adding a command needs no edit here.
fpath=(${0:A:h}/functions $fpath)
autoload -Uz ${0:A:h}/functions/*(N:t)

# Read by _wt_core when it builds its picker. Single-quoted on purpose: the
# expansion happens inside fzf's preview shell, not here.
typeset -g _wt_fzf_preview='$WT_CORE_BIN/wt-preview {1}'

# Filled by wtclean's _wt_pr_cache; empty otherwise, which just means every
# lookup queries. Must be declared here, with the reader: an *undeclared*
# _wt_prs makes ${_wt_prs[feat/x]} an arithmetic subscript, and "feat/x"
# evaluates as a division.
typeset -gA _wt_prs

# ── Completions ─────────────────────────────────────────────────────
# compdef only exists once compinit has run. The picker sources this plugin
# non-interactively to reuse its functions, and that must not spew errors.
if (( $+functions[compdef] )); then
  compdef _wt_comp wt
  compdef '_arguments "1:branch:_wt_branches"' wtrm
fi

# ── fzf-tab previews ────────────────────────────────────────────────
zstyle ':fzf-tab:complete:wt:*'   fzf-preview "$WT_CORE_BIN/wt-preview $word"
zstyle ':fzf-tab:complete:wtrm:*' fzf-preview "$WT_CORE_BIN/wt-preview $word"
