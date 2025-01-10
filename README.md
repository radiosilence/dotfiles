# ✨ Dotfiles ✨

## Requirements

- 📄 Recent version of **fish**

## Includes

This repository contains configuration files for:

- 🎧 **beets** (music library manager)
- 🐟 **fish** (friendly interactive shell)
- 👻 **ghostty** (minimal terminal)
- 🧬 **helix** (text editor)
- 🛠️ **mise** (modern environment manager)
- 🚀 **starship** (prompt for any shell)
- 🔧 **git** (version control)
- 🔐 **ssh** (secure shell)
- 💻 **wezterm** (terminal emulator)

Additional features:

- 💾 POSIX-compliant utility scripts in `./bin`
- 🔄 Sane default packages for various applications

---

## 🔧 Install Dependencies (macOS)

Quick setup:

```sh
~/.dotfiles/bin/setup-macos
```

### Required Tools

- [🍺 Homebrew](https://brew.sh/) - a package manager for macOS
- [🛠️ Mise](https://mise.jdx.dev) - a replacement for nvm, rvm, etc. (`brew install mise`)
- [👀 Fzf](https://github.com/junegunn/fzf) - a fuzzy matcher for everything (`brew install fzf`)

---

## ⚙️ Install

Clone the repository and run the installer:

```sh
git clone https://github.com/radiosilence/dotfiles ~/.dotfiles
~/.dotfiles/install
```
