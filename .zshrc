# Ultra-performant Zsh configuration
# Equivalent to Fish shell setup

# Performance: Load in specific order for optimal startup
source ~/.config/zsh/conf.d/performance.zsh
source ~/.config/zsh/conf.d/00-path.zsh
source ~/.config/zsh/conf.d/01-brew.zsh
source ~/.config/zsh/conf.d/02-mise.zsh

# Load remaining configuration modules (starship must be last)
for config in ~/.config/zsh/conf.d/*.zsh; do
  case "$(basename "$config")" in
  performance.zsh | 00-path.zsh | 01-brew.zsh | 02-mise.zsh | starship.zsh) continue ;;
  *) [[ -r "$config" ]] && source "$config" ;;
  esac
done

# Load starship last to ensure it sees all environment changes
[[ -r ~/.config/zsh/conf.d/starship.zsh ]] && source ~/.config/zsh/conf.d/starship.zsh
