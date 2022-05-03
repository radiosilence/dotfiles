if is_cmd bat; then
  alias "bat=bat \
    --map-syntax='*.kubeconfig:YAML' \
    --map-syntax='config:YAML' \
  "
  alias "cat=bat"
  # alias "fd=fd -X bat"
  alias "fzf=fzf \
    --preview 'bat --color=always --style=numbers --line-range=:500 {}' \
  "
fi
