# rip-cd

CD ripper with AccurateRip verification, EAC-style logging, spectrogram generation, and comprehensive metadata management for archival purposes.

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

### Verification & Analysis

- **AccurateRip verification** - Verify rips against the AccurateRip database
- **EAC-style detailed logging** - Comprehensive ripping logs with drive info
- **Spectrogram generation** - Visual frequency analysis of tracks
- **Secure ripping mode** - Enhanced error correction and verification
- **C2 error correction** - Hardware-level error detection
- **Test & Copy mode** - Dual-pass verification
- **Drive capability detection** - Auto-detect read offsets and capabilities
- **Matrix number support** - Track pressing plant and runout information

### Quality & Metadata

- **FLAC compression** - Configurable compression levels for storage efficiency
- **Comprehensive metadata** - Matrix numbers, ISRC, pressing details
- **Audio analysis** - Peak/RMS levels, dynamic range calculation
- **CRC32 verification** - File integrity checking
- **MusicBrainz integration** - Automatic metadata enrichment
- **JSON schema validation** - Type-safe configuration

### Workflow & Integration

- **XLD integration** - macOS CD ripper integration
- **Beets library management** - Automatic import and organization
- **Template generation** - IDE autocompletion support
- **Dry-run testing** - Verify configuration before ripping
- **Configurable workspace** - Organized file structure

## Requirements

- macOS (XLD integration)
- [XLD](https://tmkk.undo.jp/xld/index_e.html) for CD ripping
- [beets](https://beets.io/) (optional, for library management)
- [sox](http://sox.sourceforge.net/) for spectrogram generation
- [ffmpeg](https://ffmpeg.org/) for audio analysis
- Python 3.x with matplotlib, numpy, scipy for advanced analysis

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
# Install essential CD ripping tools (XLD, flac, ffmpeg, sox, beets, etc.)
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

### Shell Completions

```bash
# Fish shell
rip-cd completion fish > ~/.config/fish/completions/rip-cd.fish

# Zsh shell
rip-cd completion zsh > "${fpath[1]}/_rip-cd"

# Bash shell (macOS)
rip-cd completion bash > $(brew --prefix)/etc/bash_completion.d/rip-cd

# Or source directly
source <(rip-cd completion fish)  # Fish
source <(rip-cd completion bash)  # Bash
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
- **Ripper**: XLD settings with quality options
- **Quality**: AccurateRip, C2 error correction, secure ripping modes
- **Analysis**: Spectrogram generation and audio analysis settings
- **Output**: File and directory naming templates
- **Drive**: CD drive capability detection and offset correction
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
rip-cd completion --help
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
│       ├── *.flac           # Audio files
│       ├── metadata.yaml    # Complete metadata
│       ├── rip.log         # EAC-style ripping log
│       └── spectrograms/   # Frequency analysis
│           └── *.png
├── logs/              # Log files
└── temp/              # Temporary files
```

## Enhanced Configuration

### High Quality Settings

```yaml
ripper:
  quality:
    format: "flac"
    compression: 8 # High compression level
    secure_ripping: true # Secure mode
    c2_error_correction: true # Hardware error correction
    test_and_copy: true # Dual-pass verification
    max_retry_attempts: 20 # High retry count

    accurate_rip:
      enabled: true
      min_confidence: 2

    spectrograms:
      enabled: true
      generate_sample: true
      resolution: 2048

    enhanced_logging:
      eac_style: true
      drive_info: true
      matrix_info: true
```

### Matrix Number Support

```yaml
matrix:
  enabled: true
  side_a: "MATRIX-A1"
  side_b: "MATRIX-B1"
  mould_sid: "IFPI L123"
  ifpi_codes: ["IFPI 1234", "IFPI 5678"]
  mastering_code: "STERLING"
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

### Complete Metadata Example

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
  pressing_plant: "EMI Hayes"
  edition: "First Press"
  musicbrainz_id: "a1234567-1234-1234-1234-123456789012"

  matrix:
    side_a: "SHVL-804-A-2U"
    side_b: "SHVL-804-B-2U"
    mould_sid: "IFPI L123"
    ifpi_codes: ["IFPI 1234"]
    mastering_code: "STERLING"

tracks:
  - number: 1
    title: "Speak to Me"
    length: "1:30"
    isrc: "GBUM71505078"
    peak: 0.87
    rms: 0.12
    accurate_rip:
      confidence: 3
      matched: true
      database_hits: 15
  - number: 2
    title: "Breathe (In the Air)"
    length: "2:43"
    peak: 0.92
    rms: 0.15

credits:
  producer: "Pink Floyd"
  engineer: "Alan Parsons"
  recorded_at: "Abbey Road Studios"

ripping:
  drive_info:
    manufacturer: "PLEXTOR"
    model: "PX-W5224A"
    read_offset: 30
    c2_support: true
  settings:
    secure_mode: true
    accurate_rip: true
    compression_level: 8 # High compression
  stats:
    total_tracks: 10
    accurate_rip_matches: 10
    peak_level: 0.95 # Audio analysis results
```

## License

MIT License - see LICENSE file for details.
