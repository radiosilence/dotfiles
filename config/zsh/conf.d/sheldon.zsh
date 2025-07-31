# Sheldon plugin manager
command -v sheldon >/dev/null || return

# Load plugins with performance optimization
eval "$(sheldon source)"
