command -v sheldon >/dev/null || return

_cached_eval "sheldon" "sheldon source" "${XDG_CONFIG_HOME:-$HOME/.config}/sheldon/plugins.toml"
