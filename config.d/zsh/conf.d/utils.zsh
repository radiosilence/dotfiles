# Utility aliases and functions for common tasks

# Find what's using a port
whatport() { lsof -i :$1 }

# Show recently modified files (default: last hour)
recent() { fd --type f --changed-within ${1:-1h} | head -20 }

# Quick disk usage breakdown
alias sizes='dust -d 2'

# Show all listening ports
alias listening='lsof -iTCP -sTCP:LISTEN -P -n'

# Grep processes with tree view
psg() { procs --tree | grep -i $1 }

# sesh session picker
alias sp='sesh connect "$(sesh list --icons --hide-duplicates | fzf --ansi --reverse --header="sessions / dirs" --preview "sesh preview {}")"'

# glow markdown browser — fzf pick then TUI
gzf() { glow "$(fd -e md | fzf --ansi --reverse --preview 'glow -s dark {}')" }

# request claude code review on current PR
alias ccr='gh pr comment --body "@claude review"'
alias ccrr='gh pr comment --body "@claude re-review"'

