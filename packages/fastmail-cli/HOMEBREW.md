# Homebrew Installation

## Install via Homebrew Tap

### Add the tap
```bash
brew tap radiosilence/dotfiles https://github.com/radiosilence/dotfiles.git
```

### Install fastmail-cli
```bash
brew install fastmail-cli
```

### Update to latest version
```bash
brew update
brew upgrade fastmail-cli
```

## Install from HEAD (development version)
```bash
brew install --HEAD fastmail-cli
```

## Uninstall
```bash
brew uninstall fastmail-cli
brew untap radiosilence/dotfiles
```

## Troubleshooting

### Formula not found
If you get "No available formula with name", make sure you've added the tap first:
```bash
brew tap radiosilence/dotfiles https://github.com/radiosilence/dotfiles.git
```

### Update tap
```bash
brew update
```

### Reinstall from scratch
```bash
brew uninstall fastmail-cli
brew untap radiosilence/dotfiles
brew tap radiosilence/dotfiles https://github.com/radiosilence/dotfiles.git
brew install fastmail-cli
```