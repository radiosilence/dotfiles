# Sheldon plugin manager
command -v sheldon >/dev/null || return

local cache_dir=~/.cache/zsh/eval
local cache_file="$cache_dir/sheldon.zsh"
local config_file="${XDG_CONFIG_HOME:-$HOME/.config}/sheldon/plugins.toml"

[[ -d $cache_dir ]] || mkdir -p "$cache_dir"

# Regenerate cache if plugins.toml is newer or cache doesn't exist
if [[ ! -f $cache_file ]] || [[ $config_file -nt $cache_file ]]; then
  sheldon source > "$cache_file"
fi
source "$cache_file"
