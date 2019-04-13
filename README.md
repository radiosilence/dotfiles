# dotfiles

## Requirements

- Recent version of zsh
- [antibody](https://getantibody.github.io) (`brew install getantibody/tap/antibody`)
- [asdf](https://asdf-vm.com/#/) (`git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.7.1`)

## Includes

- ViM
- tmux
- VS Code
- alacritty (fast, gl based terminal)
- Hyper (slow, electron based terminal)

## Install dependencies (macOS)

```zsh
git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim
```

## Install

```zsh
git clone https://github.com/radiosilence/dotfiles ~/.dotfiles
./dotfiles/install.zsh
```

> **NOTE**: Only symlinks .hidden files


## Install SF Mono

```zsh
cp /Applications/Utilities/Terminal.app/Contents/Resources/Fonts/*.otf ~/Library/Fonts/
```
