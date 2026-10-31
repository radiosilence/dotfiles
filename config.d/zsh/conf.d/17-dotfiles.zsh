# Dotfiles configuration
[[ -d ~/.dotfiles ]] || return

# Add dotfiles scripts to PATH (prepend for priority)
path=(~/.dotfiles/scripts $path)
export PATH
