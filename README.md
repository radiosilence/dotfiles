# ✨ Dotfiles ✨

## ⚡ Requirements

| 📝 Requirement                |
| ----------------------------- |
| 📄 Recent version of **fish** |

---

## 📂 Includes

This repository contains configuration files for:

| Tool                | Description                        |
| ------------------- | ---------------------------------- |
| 🎧 **beets**        | Music library manager              |
| 🌐 **browser-schedule** | Switch default browser by work hours |
| 📧 **fastmail-cli** | Fastmail JMAP API client           |
| 🐟 **fish**         | Friendly interactive shell         |
| 🤖 **fish-ai**      | AI-powered shell assistant         |
| 👻 **ghostty**      | Minimal terminal theme             |
| 🖌️ **helix**        | Text editor                        |
| 🛠️ **mise**         | Modern environment manager         |
| 💿 **rip-cd**       | CD ripper with metadata management |
| 🚀 **starship**     | Prompt for any shell               |
| 🔧 **git**          | Version control                    |
| 🔐 **ssh**          | Secure shell                       |
| 💻 **wezterm**      | Terminal emulator                  |

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

| Tool                                      | Description                                                |
| ----------------------------------------- | ---------------------------------------------------------- |
| [🍺 homebrew](https://brew.sh/)           | A package manager for macOS                                |
| [🛠️ mise](https://mise.jdx.dev)           | Replacement for asdf, nvm, rvm, etc. (`brew install mise`) |
| [👀 fzf](https://github.com/junegunn/fzf) | Fuzzy matcher for everything (`brew install fzf`)          |

---

## 💣 Installation Guide

**Clone the repository and run the installer:**

```sh
git clone https://github.com/radiosilence/dotfiles ~/.dotfiles
~/.dotfiles/install
```

**🤖 Enable AI Features (Optional):**

```sh
~/.dotfiles/bin/setup-fish-ai
```

This sets up AI-powered shell assistance with:

- **Ctrl + P**: Transform comments to commands and vice versa
- **Ctrl + Space**: Autocomplete commands or suggest fixes

> 💡 **Note**: AI features require an Anthropic API key.

## Package Documentation

Individual packages have their own documentation:

- **[📧 Fastmail CLI](packages/fastmail-cli/README.md)** - Command-line interface for Fastmail JMAP API
- **[🌐 Browser Schedule](packages/browser-schedule/README.md)** - Switch default browser by work hours  
- **[😴 Sleep Report](packages/sleep-report/README.md)** - macOS sleep health analyzer

---

**Disclaimer: There are some vibecoded utilities in here**

---
