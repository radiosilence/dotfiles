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

**📧 Install Fastmail CLI (Optional):**

```sh
brew tap radiosilence/dotfiles https://github.com/radiosilence/dotfiles.git
brew install fastmail-cli
```

Then authenticate with your Fastmail API token:

```sh
fastmail-cli auth YOUR_API_TOKEN_HERE
```

> 💡 **Note**: Get your API token from Fastmail Settings → Privacy & Security → Integrations.

## 🌐 Browser Schedule

Switch default browser based on work hours. Chrome during work, personal browser otherwise.

**Setup:**
```sh
cd ~/.dotfiles/packages/browser-schedule
task install
```

This creates `~/.config/browser-schedule/config.json` with default settings.

**Config:** Edit `~/.config/browser-schedule/config.json`:
```json
{
  "work_browser": "Google Chrome",
  "personal_browser": "Zen",
  "work_start_hour": 9,
  "work_end_hour": 18,
  "work_days": "1-5",
  "log_path": "~/.config/browser-schedule/browser-schedule.log"
}
```

**Commands:**
- `task status` - Check installation status
- `task config` - Show current config
- `task logs` - View activity logs

---

**Disclaimer: There are some vibecoded utilities in here**

---
