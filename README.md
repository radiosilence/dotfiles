# dotfiles

## Requirements

- Recent version of zsh

## Includes

- ViM
- minimal asdf file that makes it work with nvm etc...
- various useful zsh crap for working with stuff on macos
- tmux
- VS Code
- alacritty (fast, gl based terminal)
- Hyper (slow, electron based terminal)

## Install dependencies (macOS)

- [homebrew](https://brew.sh/) (`/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"`)
- [antibody](https://getantibody.github.io) (`brew install getantibody/tap/antibody`)
- [asdf](https://asdf-vm.com/#/) (`git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.7.1`)
- [vundle](https://github.com/VundleVim/Vundle.vim) (`git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim`)


## Install

```zsh
git clone https://github.com/radiosilence/dotfiles ~/.dotfiles
./dotfiles/install.zsh
```

> **NOTE**: Only symlinks .hidden files

## Get sick AF fonts that have the neat ligatures

- [Ligaturizer](https://github.com/ToxicFrog/Ligaturizer) (get Fantasque Sans Mono or Alacritty wont work)

## Install SF Mono

```zsh
cp /Applications/Utilities/Terminal.app/Contents/Resources/Fonts/*.otf ~/Library/Fonts/
```
