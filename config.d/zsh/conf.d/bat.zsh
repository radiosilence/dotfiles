# Bat (better cat) configuration
command -v bat >/dev/null || return

export PAGER='bat --style=plain'
export MANPAGER='bat --style=plain --language=man'

alias bat='bat \
  --map-syntax="*.kubeconfig:YAML" \
  --map-syntax="config:YAML"'

alias cat='bat'
