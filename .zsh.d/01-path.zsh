paths=(
  ~/.local/bin
  $DOTFILES/bin
  ~/.fastlane/bin
  ~/.yarn/bin
  ~/.config/yarn/global/node_modules/.bin
)

# export path
export PATH="$(join_by : $paths):$PATH"
