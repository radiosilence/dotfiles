# Bat (better cat) configuration
command -v bat >/dev/null || return

alias bat='bat \
  --map-syntax="*.kubeconfig:YAML" \
  --map-syntax="config:YAML"'

# cat should dump, never page — plain `bat` paged big files a screenful (or, with a
# broken pager, a line) at a time and could hang waiting on less.
alias cat='bat --paging=never'

# One real pager for everything (git, --help, bat's own paging). -F quits when the
# output fits one screen; -R keeps colours. No -X — it breaks -F's screen detection
# and was the root of the one-line-at-a-time / hanging pager mess.
export LESS='-FR'
export PAGER='less'
export BAT_PAGER='less'

# man → bat. `col -bx` strips the backspace overstrike man emits (without it bat shows
# garbage and pages a line at a time); MANROFFOPT=-c stops groff re-adding it.
export MANPAGER="sh -c 'col -bx | bat --language=man --style=plain'"
export MANROFFOPT='-c'
