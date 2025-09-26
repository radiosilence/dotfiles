# Performance optimizations for Zsh
# Skip global compinit for faster startup
skip_global_compinit=1

#    ><(((º>   I loved Fish shell, but Zsh is my new home   <º)))><
#              Thanks for all the fish-y memories! 🐟→🚀

# Zsh options for performance
setopt NO_BEEP
setopt AUTO_CD
setopt GLOB_COMPLETE
setopt ALWAYS_TO_END
setopt COMPLETE_IN_WORD
setopt CORRECT
setopt EXTENDED_GLOB
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_REDUCE_BLANKS
setopt HIST_SAVE_NO_DUPS
setopt HIST_VERIFY
setopt INC_APPEND_HISTORY
setopt INTERACTIVE_COMMENTS
setopt SHARE_HISTORY

# History configuration
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000

# Add custom completions to fpath before compinit
if [[ -d ~/.config/zsh/completions ]]; then
  fpath=(~/.config/zsh/completions $fpath)
fi

# Load completions
autoload -Uz compinit

# Force autoload of custom completions
if [[ -d ~/.config/zsh/completions ]]; then
  for completion in ~/.config/zsh/completions/_*; do
    [[ -r $completion ]] && autoload -Uz "${completion:t}"
  done
fi

# Completion styling
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' squeeze-slashes true
