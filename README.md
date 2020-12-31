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
- Terminal.app profile (MacOS terminal, more stable than alacritty)

## Install dependencies (macOS)

- [homebrew](https://brew.sh/) a package manager for macOS (`/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"`)
- [antibody](https://getantibody.github.io) a package manager for zsh (`brew install getantibody/tap/antibody` or `curl -sL git.io/antibody | sh -s`)
- [asdf](https://asdf-vm.com/#/) a thing to replace nvm, rvm, etc. (`git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.7.1`)
- [vundle](https://github.com/VundleVim/Vundle.vim) a package manager for vim (`git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim`)
- [tpm](https://github.com/tmux-plugins/tpm) a package manager for tmux (`git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm`)
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
