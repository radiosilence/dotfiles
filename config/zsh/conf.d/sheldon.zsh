# Sheldon plugin manager - deferred loading for non-essential plugins
command -v sheldon >/dev/null || return

local sheldon_base=~/.local/share/sheldon/repos/github.com

# Essential plugins - load immediately
source "$sheldon_base/zsh-users/zsh-autosuggestions/zsh-autosuggestions.plugin.zsh"
source "$sheldon_base/zsh-users/zsh-completions/zsh-completions.plugin.zsh"
source "$sheldon_base/1160054/claude-code-zsh-completion/claude-code.plugin.zsh"
source "$sheldon_base/zsh-users/zsh-history-substring-search/zsh-history-substring-search.plugin.zsh"

# Heavy plugins - defer until after first prompt
_load_deferred_plugins() {
  source "$sheldon_base/zsh-users/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh"
  source "$sheldon_base/Aloxaf/fzf-tab/fzf-tab.plugin.zsh"
  add-zsh-hook -d precmd _load_deferred_plugins
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _load_deferred_plugins
