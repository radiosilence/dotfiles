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

if command -v glow >/dev/null && command -v fd >/dev/null && command -v fzf >/dev/null; then
  gzf() { glow "$(fd -e md | fzf --ansi --reverse --preview 'glow -s dark {}')"; }
fi

converge() {
  git -C ~/.dotfiles pull --quiet
  task --taskfile ~/.dotfiles/Taskfile.yml converge
}
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
