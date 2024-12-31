# dotfiles

## Requirements

- Recent version of fish

## Includes

- minimal mise file that makes it work with nvm etc...
- tmux
- configs for:
  - beets
  - fish
  - ghostty
  - helix
  - mise
  - starship

## Install dependencies (macOS)

Easy:

```
~/.dotfiles/bin/setup-macos
```

- [homebrew](https://brew.sh/) a package manager for macOS
- [mise](https://mise.jdx.dev) a thing to replace nvm, rvm, etc. (`brew install mise`)
- [fzf](https://github.com/junegunn/fzf) fuzzy matcher for anything (`brew install fzf`)

## Install

```sh
git clone https://github.com/radiosilence/dotfiles ~/.dotfiles
./dotfiles/install
```
