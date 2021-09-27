paths=(
  ~/.local/bin
  $DOTFILES/bin
  ~/.fastlane/bin
  ~/.yarn/bin
  ~/.config/yarn/global/node_modules/.bin
)

# if is_cmd ruby; then
#   paths+=($(ruby -e 'print "%s/bin:%s/bin" % [Gem.user_dir, Gem.dir]'))
# fi

if [ -d /opt/homebrew ]; then
  export BREW_PREFIX=/opt/homebrew
else
  export BREW_PREFIX=/usr/local
fi

if is_macos; then
  paths+=(
    # ~/Library/Python/2.7/bin
    /Applications/Postgres.app/Contents/Versions/latest/bin
    ~/Library/Android/sdk/tools/bin
    ~/Library/Android/sdk/platform-tools
    $BREW_PREFIX/bin
    $BREW_PREFIX/sbin
    # $BREW_PREFIX/opt/coreutils/libexec/gnubin
    # $BREW_PREFIX/opt/findutils/libexec/gnubin
    # $BREW_PREFIX/opt/uutils-coreutils/libexec/uubin
    # $BREW_PREFIX/opt/gnu-getopt/bin
  )
fi

if is_cmd cargo; then
  paths+=(~/.cargo/bin)
fi

paths+=(
  /usr/local/bin
  /usr/local/sbin
  $PATH
)

# export path
export PATH=$(join_by : $paths)
