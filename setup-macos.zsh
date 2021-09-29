#!/bin/zsh
# list of programs to install:
# * Code
# * Firefox
# * Chrome
# * Kitty
# * Alacritty if dev is not a jerk
# * Telegram
# * Whatsapp
# * Signal
# * Slack
# * 1Password
# * Discord
# * Spotify
# * Teams
# * Twitch
# * Outlook
# * Office
# * SoundCleod
# * Cog
# * IINA
# * Creative Cloud
# * Paw
# * Figma

echo $TODOS

is_cmd() {
  command -v $1 &>/dev/null
}

if ! is_cmd brew; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

if [ ! -d ~/.zgenom ]; then
  git clone https://github.com/jandamm/zgenom.git ~/.zgenom
fi

brew install \
  asdf \
  broot \
  clang-format \
  fcp \
  fd \
  ffmpeg \
  font-iosevka \
  font-iosevka-nerd-font \
  fzf \
  git \
  gnupg \
  jq \
  lsd \
  nmap \
  pinentry \
  rar \
  ripgrep \
  starship \
  telnet \
  tig \
  tmux \
  youtube-dl \
  zoxide \
  zoxide

if ! is_cmd cargo; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
fi

cargo install \
  fcp

brew tap AdoptOpenJDK/openjdk

brew install --cask \
  adoptopenjdk8 \
  android-sdk
