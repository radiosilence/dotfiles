# brew-search

Fast Homebrew package search using fzf and cached package indexes.

## Purpose

The default `brew search` command is slow because it queries the API each time. This script leverages Homebrew's cached package index files for instant searching with fuzzy finding capabilities via fzf.

## Features

- 🚀 **Fast search** - Uses local cache instead of API calls
- 🔍 **Fuzzy finding** - Powered by fzf for interactive selection
- 📦 **Multi-select** - Select multiple packages at once
- ✅ **Status indicators** - Shows which packages are already in Brewfile
- 🍺 **Formula & Cask support** - Search both types of packages
- 🚰 **Automatic tap handling** - Adds required taps to Brewfile
- 📋 **Brewfile integration** - Automatically updates ~/Brewfile
- 🎨 **Color-coded output** - Easy to scan results with emojis

## Requirements

- Homebrew
- `jq` - JSON processor (`brew install jq`)
- `fzf` - Fuzzy finder (`brew install fzf`)

## Usage

```bash
brew-search [OPTIONS]
```

### Options

- `-h, --help` - Show help message
- `-v, --version` - Show version information
- `-n, --no-update` - Skip cache update check
- `-f, --formula` - Search only formulae
- `-c, --cask` - Search only casks

### Interactive Controls

- `TAB` - Select/deselect package
- `ENTER` - Confirm selection
- `Ctrl+A` - Select all visible items
- `Ctrl+D` - Deselect all
- `Ctrl+/` - Toggle preview panel
- `ESC` - Cancel

### Status Indicators

- ✅ - Package already in ~/Brewfile (will be skipped)
- 🍺 - Formula (command-line package)
- 🍷 - Cask (GUI application)

## Examples

```bash
# Search all packages
brew-search

# Search only formulae
brew-search --formula

# Search only casks (GUI apps)
brew-search --cask

# Skip cache update for faster startup
brew-search --no-update
```

## How It Works

1. **Cache Check** - Verifies Homebrew's API cache is up to date (< 24 hours old)
2. **Package Loading** - Parses formula.jws.json and cask.jws.json from Homebrew's cache
3. **Interactive Search** - Presents packages in fzf with descriptions
4. **Selection** - Allows multi-selection of packages
5. **Brewfile Update** - Adds selected packages (and their taps) to ~/Brewfile
6. **Installation** - Runs `brew bundle` to install new packages

## Cache Location

The script uses Homebrew's built-in API cache located at:
```
$(brew --cache)/api/
```

This cache is automatically maintained by Homebrew and updated when you run `brew update`.

## Troubleshooting

If you encounter issues with missing cache files:
```bash
brew update --force
```

To verify cache location:
```bash
brew --cache
```