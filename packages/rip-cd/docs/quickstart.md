# Quickstart Guide

Get up and running with rip-cd in under 5 minutes.

## Prerequisites

- macOS (XLD integration required)
- Homebrew installed

## 1. Setup Dependencies

Install essential CD ripping tools:

```bash
rip-cd setup --verbose
```

This installs:

- **XLD** - CD ripper application
- **flac** - FLAC codec and metadata tools
- **ffmpeg** - Audio processing
- **beets** - Music library management (Python package)
- **musicbrainzngs** - MusicBrainz API client

## 2. Generate Configuration

Create default configuration file:

```bash
rip-cd generate config
```

This creates `~/.rip-cd.yaml` with sensible defaults.

## 3. Setup Workspace

Generate workspace structure and templates:

```bash
# Create workspace and template
rip-cd generate template --workspace ~/my-cd-rips

# Generate validation schema for IDE support
rip-cd generate schema --workspace ~/my-cd-rips
```

This creates:

```
~/my-cd-rips/
├── metadata/
│   └── template.yaml     # Metadata template
├── schemas/
│   └── cd-metadata-schema.json
├── output/              # Ripped files go here
├── logs/
└── temp/
```

## 4. Prepare Your First CD

1. **Insert CD** into your drive
2. **Edit metadata template**:

   ```bash
   cd ~/my-cd-rips
   cp metadata/template.yaml metadata/my-album.yaml
   # Edit metadata/my-album.yaml with your CD info
   ```

3. **Example metadata** (`metadata/my-album.yaml`):

   ```yaml
   album:
     title: "OK Computer"
     artist: "Radiohead"
     date: "1997"
     label: "Parlophone"
     genre: "Alternative Rock"

   tracks:
     - number: 1
       title: "Airbag"
       length: "4:44"
     - number: 2
       title: "Paranoid Android"
       length: "6:23"
     # ... add all tracks
   ```

## 5. Validate and Rip

```bash
# Validate metadata
rip-cd validate metadata/my-album.yaml --workspace ~/my-cd-rips

# Test run (see what would happen)
rip-cd rip metadata/my-album.yaml --workspace ~/my-cd-rips --dry-run

# Actually rip the CD
rip-cd rip metadata/my-album.yaml --workspace ~/my-cd-rips
```

## 6. Find Your Music

Ripped files will be in:

```
~/my-cd-rips/output/Radiohead - OK Computer (1997)/
├── 01 - Airbag.flac
├── 02 - Paranoid Android.flac
├── metadata.yaml       # Complete metadata including rip info
└── ...
```

## Quick Commands Reference

```bash
# Setup
rip-cd setup                           # Install dependencies
rip-cd generate config                 # Create ~/.rip-cd.yaml

# Workspace setup
rip-cd generate template --workspace ~/rips
rip-cd generate schema --workspace ~/rips

# CD ripping workflow
rip-cd validate metadata/album.yaml    # Check metadata
rip-cd rip metadata/album.yaml --dry-run # Test
rip-cd rip metadata/album.yaml         # Rip CD

# Shell completions
rip-cd completion fish > ~/.config/fish/completions/rip-cd.fish
rip-cd completion zsh > "${fpath[1]}/_rip-cd"
rip-cd completion bash > $(brew --prefix)/etc/bash_completion.d/rip-cd

# Help
rip-cd --help                          # General help
rip-cd setup --help                    # Setup options
rip-cd generate --help                 # Generate commands
```

## Next Steps

- **Customize configuration**: Edit `~/.rip-cd.yaml` for your preferences
- **Learn advanced features**: See [Configuration Guide](./configuration.md)
- **Setup XLD profiles**: Create custom ripping profiles in XLD
- **Integrate with beets**: Configure automatic library import

## Troubleshooting

**XLD not found?**

```bash
# Check if XLD is installed
ls /Applications/XLD.app

# If missing, download from: https://tmkk.undo.jp/xld/index_e.html
```

**Dependencies missing?**

```bash
# Check what's installed
brew bundle check --file=~/Brewfile

# Install missing packages
brew bundle install --file=~/Brewfile
```

**Metadata validation errors?**

- Check required fields: `album.title`, `album.artist`, track `number` and `title`
- Verify date format: `YYYY`, `YYYY-MM`, or `YYYY-MM-DD`
- Use IDE with YAML language server for real-time validation

## Tips

- **Use dry runs** to test configurations before ripping
- **Validate metadata** before starting long rips
- **Template reuse**: Copy successful metadata files as templates
- **Backup metadata**: Store metadata files in version control
- **IDE integration**: Use VS Code or similar for autocomplete support
