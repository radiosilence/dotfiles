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
	bat \
	broot \
	clang-format \
	efm-langserver \
	fastlane \
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
	mise \
	nmap \
	pinentry \
	pinentry-mac \
	pipx \
	pulumi \
	qemu \
	rar \
	rclone \
	ripgrep \
	rsync \
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

brew install --cask \
	zulu \
	rar \
	wezterm \
	mpv

rustup default stable

mise install

cargo install \
	fcp

sudo softwareupdate --install-rosetta

install_font() {
	mkdir -p /tmp/font
	aria2c $1 -d /tmp/font
	unzip /tmp/font/*.zip -d /tmp/font
	cp -v /tmp/font/*.{ttf,otf} ~/Library/Fonts
	rm -rf /tmp/font
}

install_font https://github.com/gaplo917/Ligatured-Hack/releases/download/v3.003%2BNv2.1.0%2BFC%2BJBMv2.242/HackLigatured-v3.003+FC3.1+JBMv2.242.zip
