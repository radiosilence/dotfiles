# path
PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"
PATH="/usr/local/opt/findutils/libexec/gnubin:$PATH"
PATH="/usr/local/opt/uutils-coreutils/libexec/uubin:$PATH"
PATH="/usr/local/opt/gnu-getopt/bin:$PATH"
PATH="/usr/local/bin:$PATH"
PATH="/usr/local/sbin:$PATH"
PATH="$HOME/.local/bin:$PATH"
PATH="$DOTFILES/bin:$PATH"
PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"
PATH="$HOME/Library/Android/sdk/tools/bin:$PATH"
PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"
PATH="$HOME/.fastlane/bin:$PATH"
PATH="$HOME/.cargo/bin:$PATH"

[[ -x $(which ruby) ]] && PATH="$(ruby -e 'print "%s/bin:%s/bin" % [Gem.user_dir, Gem.dir]'):$PATH"

PATH="$HOME/Library/Python/2.7/bin:$PATH"

PATH="$HOME/.cargo/bin:$PATH"

# export path
export PATH
