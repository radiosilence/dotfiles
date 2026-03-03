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

