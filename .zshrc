# Zsh configuration
# Files in conf.d are loaded in alphabetical order (use numeric prefixes for ordering)

for config in ~/.config/zsh/conf.d/*.zsh; do
  [[ -r "$config" ]] && source "$config"
done

# Zed MCP secrets
[[ -f ~/.config/zed/.secrets ]] && source ~/.config/zed/.secrets
