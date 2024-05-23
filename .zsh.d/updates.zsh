updates() {
  if [ -d "$DOTFILES" ]; then
    echo "updating dotfiles $DOTFILES"
    (cd "$DOTFILES" && git pull)
  fi

  if is_cmd mise; then
    echo "updating mise"
    mise up
  fi

  if is_cmd sheldon; then
    sheldon lock --update
  fi

  if is_cmd yt-dlp; then
    echo "updating yt-dlp"
    yt-dlp --update-to master
  fi

  if is_macos; then
    echo "updating brew"
    brew update
    brew upgrade
    brew upgrade --no-quarantine --cask
    brew cleanup
    brew doctor
  fi
}
