# Auto-attach to a zellij session named after $PWD on shell startup.
# Lets ghostty's `window-save-state = always` round-trip: restored tabs retain
# their CWD via shell-integration OSC 7, this hops them back into the matching
# session. Fresh tabs (cmd+t) land in $HOME (per ghostty config) and skip below.
command -v zellij >/dev/null || return
[[ -o interactive && -z "$ZELLIJ" && -z "$TMUX" && -t 1 ]] || return
[[ "$PWD" == "$HOME" || "$PWD" == "/" ]] && return

case "$TERM_PROGRAM" in
  ghostty|iTerm.app|Apple_Terminal) ;;
  *) return ;;
esac

_zellij_session_name() {
  local name
  name=$(basename "$PWD" | tr -c '[:alnum:]_-' '-' | sed 's/^-*//;s/-*$//')
  printf '%s' "${name:-home}"
}

exec zellij attach -c "$(_zellij_session_name)"
