paths=(
  ~/.local/bin
  $DOTFILES/bin
  ~/.fastlane/bin
)

# export path
export PATH="$(join_by : $paths):$PATH"
