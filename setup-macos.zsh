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
	font-iosevka \
	font-iosevka-nerd-font \
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
	qemu \
	rar \
	ripgrep \
	rust-analyzer \
	sheldon \
	shellcheck \
	shfmt \
	starship \
	taplo \
	telnet \
	terraform \
	terraform-docs \
	terraform-ls \
	tig \
	tmux \
	yaml-language-server \
	yq \
	yt-dlp \
	zoxide

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

brew install --cask \
	android-sdk
