# dotfiles

## Requirements

- Recent version of zsh

## Includes

- ViM
- minimal mise file that makes it work with nvm etc...
- various useful zsh crap for working with stuff on macos
- tmux
- VS Code
- alacritty (fast, gl based terminal)
- Terminal.app profile (MacOS terminal, more stable than alacritty)

## Install dependencies (macOS)

Easy:

```
./.dotfile/setup-macos.zsh
```

- [homebrew](https://brew.sh/) a package manager for macOS
- [sheldon](https://github.com/rossmacarthur/sheldon) a package manager for zsh (`brew install sheldon`)
- [mise](https://mise.jdx.dev) a thing to replace nvm, rvm, etc. (`brew install mise`)
- [tpm](https://github.com/tmux-plugins/tpm) a package manager for tmux (`brew install tpm`)
- [fzf](https://github.com/junegunn/fzf) fuzzy matcher for anything (`brew install fzf`)

## Install

```zsh
git clone https://github.com/radiosilence/dotfiles ~/.dotfiles
./dotfiles/install
```

> **NOTE**: Only symlinks .hidden files

## Get sick AF fonts that have the neat ligatures

- [Nerd Fonts](https://github.com/ryanoasis/nerd-fonts/)
- [Ligaturizer](https://github.com/ToxicFrog/Ligaturizer)

## Install SF Mono

```zsh
cp /Applications/Utilities/Terminal.app/Contents/Resources/Fonts/*.otf ~/Library/Fonts/
```
