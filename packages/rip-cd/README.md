# rip-cd

CD ripper with metadata management, MusicBrainz integration, and strongly-typed configuration.

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

## Quick Start

```bash
# Generate workspace and template
rip-cd generate template --workspace ~/my-rips

# Edit the template with your CD information
$EDITOR ~/my-rips/metadata/template.yaml

# Validate metadata
rip-cd validate ~/my-rips/metadata/template.yaml --workspace ~/my-rips

# Test what would happen (dry run)
rip-cd rip ~/my-rips/metadata/template.yaml --workspace ~/my-rips --dry-run

# Rip the CD
rip-cd rip ~/my-rips/metadata/template.yaml --workspace ~/my-rips
```

## Configuration

### Global Configuration

Create `~/.rip-cd.yaml`:

```yaml
workspace:
  base_dir: "~/music-rips"
  auto_create_dirs: true

ripper:
  engine: "xld"
  quality:
    format: "flac"
    compression: 5
    verify: true

output:
  dir_template: "{{.Artist}} - {{.Album}} ({{.Year}})"
  filename_template: "{{.TrackNumber}} - {{.Title}}"

integrations:
  musicbrainz:
    enabled: true
    rate_limit: 1.0
  beets:
    enabled: true
    auto_import: true
```

### Metadata Files

Metadata files use YAML with JSON schema validation:

```yaml
# yaml-language-server: $schema=../schemas/cd-metadata-schema.json
album:
  title: "Album Title"
  artist: "Artist Name"
  date: "2023"
  label: "Record Label"
  catalog_number: "CAT-001"
  barcode: "123456789012"
  genre: "Rock"
  country: "US"
  packaging: "Jewel Case"

tracks:
  - number: 1
    title: "First Track"
    length: "3:45"
  - number: 2
    title: "Second Track"
    length: "4:20"

credits:
  producer: "Producer Name"
  engineer: "Engineer Name"
```

## Commands

### Generate Templates and Schemas

```bash
# Generate metadata template
rip-cd generate template [--workspace DIR]

# Generate JSON schema
rip-cd generate schema [--workspace DIR]
```

### Validate Metadata

```bash
rip-cd validate <metadata-file> [--workspace DIR]
```

### Rip CDs

```bash
# Dry run (shows what would happen)
rip-cd rip <metadata-file> --dry-run [--workspace DIR]

# Actual ripping
rip-cd rip <metadata-file> [--workspace DIR]
```

### Global Options

```bash
--workspace DIR     Override workspace directory (default: ~/cd_ripping)
--config FILE       Config file (default: ~/.rip-cd.yaml)
--verbose          Verbose output
--debug            Debug output
--dry-run          Show what would be done without executing
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
