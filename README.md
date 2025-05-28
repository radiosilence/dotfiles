# ✨ Dotfiles ✨

---

## ⚡ Requirements

| 📝 Requirement                |
| ----------------------------- |
| 📄 Recent version of **fish** |

---

## 📂 Includes

This repository contains configuration files for:

| Tool            | Description                |
| --------------- | -------------------------- |
| 🎧 **beets**    | Music library manager      |
| 🐟 **fish**     | Friendly interactive shell |
| 🤖 **fish-ai**  | AI-powered shell assistant |
| 👻 **ghostty**  | Minimal terminal theme     |
| 🖌️ **helix**    | Text editor                |
| 🛠️ **mise**     | Modern environment manager |
| 🚀 **starship** | Prompt for any shell       |
| 🔧 **git**      | Version control            |
| 🔐 **ssh**      | Secure shell               |
| 💻 **wezterm**  | Terminal emulator          |

Additional features:

- 💾 POSIX-compliant utility scripts in `./bin`
- 🔄 Sane default packages for various applications

---

## 🛠️ Install Dependencies (macOS)

**Quick setup:**

```sh
~/.dotfiles/bin/setup-macos
```

### Required Tools

| Tool                                      | Description                                          |
| ----------------------------------------- | ---------------------------------------------------- |
| [🍺 Homebrew](https://brew.sh/)           | A package manager for macOS                          |
| [🛠️ Mise](https://mise.jdx.dev)           | Replacement for nvm, rvm, etc. (`brew install mise`) |
| [👀 Fzf](https://github.com/junegunn/fzf) | Fuzzy matcher for everything (`brew install fzf`)    |

---

## 💣 Installation Guide

**Clone the repository and run the installer:**

```sh
git clone https://github.com/radiosilence/dotfiles ~/.dotfiles
~/.dotfiles/install
```

**🤖 Enable AI Features (Optional):**

First, switch to the AI branch:
```sh
cd ~/.dotfiles && git checkout ai
```

Then run the AI setup:
```sh
~/.dotfiles/bin/setup-fish-ai
```

This sets up AI-powered shell assistance with:
- **Ctrl + P**: Transform comments to commands and vice versa  
- **Ctrl + Space**: Autocomplete commands or suggest fixes

> 💡 **Note**: AI features are currently available on the `ai` branch and require an Anthropic API key.

---

## 🌟 Tips & Tricks

- 🎯 Customize your `starship` prompt to match your workflow.
- 🚦 Use `fzf` for supercharged file navigation and command history search.
- 🧩 Keep your configuration modular for easier maintenance.
