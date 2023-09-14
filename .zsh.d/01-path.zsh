paths=(
  ~/.local/bin
  $DOTFILES/bin
  ~/.fastlane/bin
  ~/.yarn/bin
  ~/.config/yarn/global/node_modules/.bin
)

if is_macos; then
  paths+=(
    /Applications/Postgres.app/Contents/Versions/latest/bin
  )
fi

if is_cmd cargo; then
  paths+=(~/.cargo/bin)
fi

paths+=(
  /usr/local/bin
  /usr/local/sbin
)

# export path
export PATH="$(join_by : $paths):$PATH"
