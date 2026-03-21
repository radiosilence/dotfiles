# Bat (better cat) configuration
command -v bat >/dev/null || return

alias bat='bat \
  --map-syntax="*.kubeconfig:YAML" \
  --map-syntax="config:YAML"'

alias cat='bat'
