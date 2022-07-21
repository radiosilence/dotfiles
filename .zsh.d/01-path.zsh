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

if is_macos; then
  paths+=(
    # ~/Library/Python/2.7/bin
    /Applications/Postgres.app/Contents/Versions/latest/bin
    /usr/local/MacGPG2/bin
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
