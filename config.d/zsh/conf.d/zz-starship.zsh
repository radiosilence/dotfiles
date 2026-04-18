# Starship prompt
command -v starship >/dev/null || return

export STARSHIP_CONFIG=~/.config/starship/config.toml
_cached_eval "starship" "starship init zsh" "$(command -v starship)"
