# Utility aliases and functions

whatport() { lsof -i :"$1"; }
alias listening='lsof -iTCP -sTCP:LISTEN -P -n'

if command -v fd >/dev/null; then
  recent() { fd --type f --changed-within "${1:-1h}" | head -20; }
fi

if command -v dust >/dev/null; then
  alias sizes='dust -d 2'
fi

if command -v procs >/dev/null; then
  psg() { procs --tree | grep -i "$1"; }
fi

# if command -v sesh >/dev/null && command -v fzf >/dev/null; then
#   alias sp='sesh connect "$(sesh list --icons --hide-duplicates | fzf --ansi --reverse --header="sessions / dirs" --preview "sesh preview {}")"'
# fi

if command -v zellij >/dev/null && command -v fzf >/dev/null; then
  zp() {
    local sessions selected target name
    local ic_s=$'\uf489' ic_d=$'\uf07c'
    sessions=$(zellij list-sessions --short 2>/dev/null)
    selected=$(
      {
        if [ -n "$sessions" ]; then
          echo "$sessions" | while IFS= read -r s; do
            [ -n "$s" ] && printf "\e[32m%s %s\e[0m\n" "$ic_s" "$s"
          done
        fi
        zoxide query --list 2>/dev/null | head -20 | while IFS= read -r d; do
          [ -n "$d" ] && printf "\e[34m%s %s\e[0m\n" "$ic_d" "${d/#$HOME/~}"
        done
      } | fzf --ansi --reverse --header="zellij sessions / dirs" \
              --preview 'p=$(echo {} | sed "s/^[^ ]* //"); p="${p/#\~/$HOME}"; [ -d "$p" ] && mise x -- lsd -A --color=always --icon=always --tree --depth 2 "$p" 2>/dev/null || ls "$p" 2>/dev/null || echo "session: $p"'
    )
    [ -z "$selected" ] && return
    target="${selected#* }"
    if [ -n "$sessions" ] && echo "$sessions" | grep -qxF "$target"; then
      zellij attach "$target"
    else
      target="${target/#\~/$HOME}"
      name=$(basename "$target")
      cd "$target" && zellij attach -c "$name"
    fi
  }
fi

if command -v glow >/dev/null && command -v fd >/dev/null && command -v fzf >/dev/null; then
  gzf() { glow "$(fd -e md | fzf --ansi --reverse --preview 'glow -s dark {}')"; }
fi

alias converge='task --taskfile ~/.dotfiles/Taskfile.yml converge'
alias upd='converge'

if command -v gh >/dev/null; then
  alias ghprv='gh pr view'
  alias ghprb='gh pr view --web'
  alias ghprcw='gh pr checks --watch'
  alias ccr='gh pr comment --body "@claude review"'
  alias ccrf='gh pr comment --body "@claude review and fix all issues"'
  alias ccrr='gh pr comment --body "@claude re-review"'
  alias ccrrf='gh pr comment --body "@claude re-review and fix all outstanding issues"'
fi
