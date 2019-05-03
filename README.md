# dotfiles

## Requirements

- Recent version of zsh
- [antibody](https://getantibody.github.io) (`brew install getantibody/tap/antibody`)

## Includes

- ViM
- tmux
- VS Code
- alacritty (fast, gl based terminal)
- Hyper (slow, electron based terminal)

## Install dependencies (macOS)

```zsh
brew install antigen
```

or without homebrew/on Linux:

```zsh
curl -sL git.io/antibody | sh -s
```
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
