# path
PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"
PATH="/usr/local/opt/findutils/libexec/gnubin:$PATH"
PATH="/usr/local/opt/uutils-coreutils/libexec/uubin:$PATH"
PATH="/usr/local/opt/gnu-getopt/bin:$PATH"
PATH="/usr/local/bin:$PATH"
PATH="/usr/local/sbin:$PATH"
PATH="$HOME/.local/bin:$PATH"
PATH="$DOTFILES/bin:$PATH"
PATH="$HOME/.fastlane/bin:$PATH"
PATH="$HOME/.cargo/bin:$PATH"
PATH="$HOME/.yarn/bin:$HOME/.config/yarn/global/node_modules/.bin:$PATH"

if is_cmd ruby; then
  PATH="$(ruby -e 'print "%s/bin:%s/bin" % [Gem.user_dir, Gem.dir]'):$PATH"
fi

if is_macos; then
  PATH="$HOME/Library/Python/2.7/bin:$PATH"
  PATH="/Applications/Postgres.app/Contents/Versions/latest/bin:$PATH"
  PATH="$HOME/Library/Android/sdk/tools/bin:$PATH"
  PATH="$HOME/Library/Android/sdk/platform-tools:$PATH"
fi

# export path
export PATH
