# rip-cd

CD ripper with metadata management, MusicBrainz integration, and strongly-typed configuration.

## 🚀 Quickstart

Get started in under 5 minutes:

```bash
# 1. Install dependencies
rip-cd setup

# 2. Create default config
rip-cd generate config

# 3. Setup workspace
rip-cd generate template --workspace ~/my-cd-rips
rip-cd generate schema --workspace ~/my-cd-rips

# 4. Edit metadata for your CD
cp ~/my-cd-rips/metadata/template.yaml ~/my-cd-rips/metadata/my-album.yaml
# Edit my-album.yaml with your CD information

# 5. Rip your CD
rip-cd validate ~/my-cd-rips/metadata/my-album.yaml
rip-cd rip ~/my-cd-rips/metadata/my-album.yaml --dry-run  # test first
rip-cd rip ~/my-cd-rips/metadata/my-album.yaml            # actual rip
```

📖 **[Full Quickstart Guide](./docs/quickstart.md)** | 📋 **[Configuration Guide](./docs/configuration.md)**

## Features

- High-quality FLAC ripping via XLD integration
- YAML configuration with JSON schema validation
- MusicBrainz metadata lookup
- Beets music library integration
- Configurable workspace directory
- Dry-run support for testing
- Template generation with IDE autocompletion support

## Requirements

- macOS (XLD integration)
- [XLD](https://tmkk.undo.jp/xld/index_e.html) for CD ripping
- [beets](https://beets.io/) (optional, for library management)

## Installation

### Homebrew (Local Tap)

```bash
brew install --formula .dotfiles/Formula/rip-cd.rb
```

### Go Install

```bash
go install github.com/radiosilence/dotfiles/packages/rip-cd/cmd@latest
```

### Build from Source

```bash
git clone https://github.com/radiosilence/dotfiles.git
cd dotfiles/packages/rip-cd
task build
```

The binary will be installed to `~/.dotfiles/bin/rip-cd`.

## Commands

### Setup Dependencies

```bash
# Install essential CD ripping tools (XLD, flac, ffmpeg, beets, etc.)
rip-cd setup --verbose

# See what would be installed without making changes
rip-cd setup --dry-run
```

### Generate Files

```bash
# Create default ~/.rip-cd.yaml configuration
rip-cd generate config

# Generate metadata template
rip-cd generate template --workspace ~/my-rips

# Generate JSON schema for IDE autocompletion
rip-cd generate schema --workspace ~/my-rips
```

### Rip CDs

```bash
# Validate metadata file
rip-cd validate ~/my-rips/metadata/album.yaml

# Test rip (dry run)
rip-cd rip ~/my-rips/metadata/album.yaml --dry-run

# Actually rip the CD
rip-cd rip ~/my-rips/metadata/album.yaml
```

## Configuration

📖 **[Complete Configuration Guide](./docs/configuration.md)**

### Quick Configuration

```bash
# Generate default config with sensible defaults
rip-cd generate config

# Edit configuration
$EDITOR ~/.rip-cd.yaml
```

### Essential Settings

The generated `~/.rip-cd.yaml` includes:

- **Workspace**: Where files are stored and organized
- **Ripper**: XLD settings and audio quality options
- **Output**: File and directory naming templates
- **Integrations**: MusicBrainz and beets configuration

### Metadata Templates

```bash
# Generate template with IDE autocompletion support
rip-cd generate template --workspace ~/rips
rip-cd generate schema --workspace ~/rips

# Edit metadata for your CD
cp ~/rips/metadata/template.yaml ~/rips/metadata/my-album.yaml
$EDITOR ~/rips/metadata/my-album.yaml
```

## Documentation

- 📖 **[Quickstart Guide](./docs/quickstart.md)** - Get up and running in 5 minutes
- 📋 **[Configuration Guide](./docs/configuration.md)** - Complete configuration reference
- 🔧 **Command Reference** - See `rip-cd --help` for all available commands

### Command Line Options

```bash
# Global flags (available on all commands)
--workspace DIR     Override workspace directory (default: ~/cd_ripping)
--config FILE       Config file (default: ~/.rip-cd.yaml)
--verbose          Verbose output
--debug            Debug output
--dry-run          Show what would be done without executing

# Get help for any command
rip-cd --help
rip-cd setup --help
rip-cd generate --help
```

## Workspace Structure

```
workspace/
├── metadata/           # Metadata YAML files
│   └── template.yaml
├── schemas/           # JSON schemas for validation
│   └── cd-metadata-schema.json
├── output/            # Ripped audio files
│   └── Artist - Album (Year)/
├── logs/              # Log files
└── temp/              # Temporary files
```

## IDE Integration

The generated templates include `yaml-language-server` schema references for autocompletion and validation in supported editors:

- VS Code (with YAML extension)
- Zed (built-in YAML support)
- Neovim (with yaml-language-server)
- Any editor supporting Language Server Protocol

## Development

### Prerequisites

- Go 1.24+
- [Task](https://taskfile.dev/) task runner

### Building

```bash
# Build binary
task build

# Run tests
task test

# Run with coverage
task test-coverage

# Format code
task fmt

# Clean build artifacts
task clean
```

### Available Tasks

```bash
task --list
```

### Publishing

```bash
# Create release
task release VERSION=v2.1.0

# Publish to Go modules
task publish VERSION=v2.1.0
```

## Validation Rules

### Album Fields

- `title`: Required, non-empty string
- `artist`: Required, non-empty string
- `date`: Optional, format `YYYY`, `YYYY-MM`, or `YYYY-MM-DD`
- `barcode`: Optional, 12-14 digits
- `country`: Optional, 2-letter ISO 3166-1 alpha-2 code
- `packaging`: Optional, predefined values only

### Track Fields

- `number`: Required, integer 1-99
- `title`: Required, non-empty string
- `length`: Optional, format `MM:SS`
- `isrc`: Optional, format `LLCCCNNNNNNN` (2 letters + 3 alphanumeric + 7 digits)

## Examples

### Basic Album

```yaml
album:
  title: "OK Computer"
  artist: "Radiohead"
  date: "1997"

tracks:
  - number: 1
    title: "Airbag"
  - number: 2
    title: "Paranoid Android"
```

### Complete Metadata

```yaml
album:
  title: "Dark Side of the Moon"
  artist: "Pink Floyd"
  date: "1973-03-01"
  label: "Harvest Records"
  catalog_number: "SHVL 804"
  barcode: "077774655125"
  genre: "Progressive Rock"
  country: "GB"
  packaging: "Gatefold Cover"

tracks:
  - number: 1
    title: "Speak to Me"
    length: "1:30"
  - number: 2
    title: "Breathe (In the Air)"
    length: "2:43"

credits:
  producer: "Pink Floyd"
  engineer: "Alan Parsons"
  recorded_at: "Abbey Road Studios"
```

## License

MIT License - see LICENSE file for details.
