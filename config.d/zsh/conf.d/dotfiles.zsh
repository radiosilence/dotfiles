# Dotfiles configuration
[[ -d ~/.dotfiles ]] || return

# Add dotfiles bin to PATH (prepend for priority)
path=(~/.dotfiles/bin ~/.dotfiles/scripts $path)
export PATH
