# npm completion (zsh only, generated via `npm completion`)
command -v npm >/dev/null || return

_npm_completion() {
  local si=$IFS
  compadd -- $(COMP_CWORD=$((CURRENT-1)) \
               COMP_LINE=$BUFFER \
               COMP_POINT=0 \
               npm completion -- "${words[@]}" \
               2>/dev/null)
  IFS=$si
}
compdef _npm_completion npm
