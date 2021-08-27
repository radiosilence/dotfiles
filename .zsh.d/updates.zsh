updates() {
  if [ -d "$DOTFILES" ]; then
    echo "updating dotfiles $DOTFILES"
    (cd "$DOTFILES" && git pull)
  fi

  if is_cmd zgenom; then
    zgenom update
    zgenom selfupdate
    zgenom clean
  fi

  if is_cmd asdf; then
    echo "updating asdf..."
    asdf plugin update --all
  fi

  if is_cmd pip3; then
    pip3 install --upgrade pip
    if is_cmd youtube-dlc; then
      echo "updating youtube-dlc"
      pip3 install --upgrade youtube-dlc
    fi
    if is_cmd yt-dlp; then
      echo "updating yt-dlp"
      pip3 install --upgrade yt-dlp
    fi
  fi

  if is_macos; then
    echo "updating brew"
    brew update
    brew upgrade
    brew upgrade --cask
    brew cleanup
    brew doctor
  fi
}
