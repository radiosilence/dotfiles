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
brew tap homebrew/cask-fonts
brew install \
	asdf \
	awscli \
	azure-cli \
	bat \
	broot \
	clang-format \
	efm-langserver \
	fcp \
	fd \
	ffmpeg \
	fzf \
	gh \
	git \
	gnupg \
	helix \
	jq \
	kubernetes-cli \
	lsd \
	lua-language-server \
	make \
	nmap \
	pinentry \
	pinentry-mac \
	pulumi \
	pipx \
	qemu \
	rar \
	ripgrep \
	ruby \
	cocoapods \
	fastlane \
	rust-analyzer \
	sheldon \
	shellcheck \
	shfmt \
	starship \
	taplo \
	telnet \
	tig \
	tmux \
	yaml-language-server \
	yq \
	yt-dlp \
	zoxide

brew tap hashicorp/tap && brew install hashicorp/tap/terraform
brew tap facebook/fb && brew install idb-companion
pipx install fb-idb

brew install --cask \
	zulu \
	rar \
	wezterm \
	mpv

ASDF_PLUGINS=(
	java
	golang
	nodejs
	python
	rust
)

for plugin in $ASDF_PLUGINS; do
	asdf plugin-add $plugin
	asdf install $plugin latest
	asdf global $plugin latest
done

rustup default stable
cargo install \
	fcp

sudo softwareupdate --install-rosetta
