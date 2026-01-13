# Starship prompt
command -v starship >/dev/null || return

export STARSHIP_CONFIG=~/.config/starship/config.toml
eval "$(starship init zsh)"
