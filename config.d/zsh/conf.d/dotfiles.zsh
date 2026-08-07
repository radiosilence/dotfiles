# Dotfiles configuration
[[ -d ~/.dotfiles ]] || return

# Add dotfiles scripts to PATH (prepend for priority)
path=(~/.dotfiles/scripts $path)
export PATH

# The scripts' own function library. Plugins add their own functions/ when
# sheldon sources them; this one belongs to no plugin.
fpath=(~/.dotfiles/scripts/lib/functions $fpath)
