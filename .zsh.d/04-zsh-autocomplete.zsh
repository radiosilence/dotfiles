zstyle ':autocomplete:*' fzf-completion yes
zstyle ':autocomplete:*' min-delay 0.5

zstyle ':autocomplete:*' default-context ''
# '': Start each new command line with normal autocompletion.
# history-incremental-search-backward: Start in live history search mode.

zstyle ':autocomplete:*' recent-dirs zoxide
# cdr:  Use Zsh's `cdr` function to show recent directories as completions.
# no:   Don't show recent directories.
# zsh-z|zoxide|z.lua|z.sh|autojump|fasd: Use this instead (if installed).
# ⚠️ NOTE: This setting can NOT be changed at runtime.

zle -A {.,}history-incremental-search-forward
zle -A {.,}history-incremental-search-backward
