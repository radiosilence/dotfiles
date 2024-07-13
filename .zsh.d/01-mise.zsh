if is_cmd mise; then
  eval "$(mise activate zsh)"
elif [ -x ~/.local/bin/mise ]; then
  eval $(~/.local/bin/mise activate zsh)
else
  echo "mise not found"
fi
