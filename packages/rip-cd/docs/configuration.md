# Configuration Guide

This guide covers all configuration options available in rip-cd, including both global settings and per-CD metadata configuration.

## Table of Contents

- [Global Configuration](#global-configuration)
- [Metadata Configuration](#metadata-configuration)
- [Configuration Examples](#configuration-examples)
- [Best Practices](#best-practices)

## Global Configuration

The global configuration file is located at `~/.rip-cd.yaml` and controls how rip-cd operates across all your CD ripping sessions.

### Generate Default Configuration

```bash
rip-cd generate config
```

This creates a `~/.rip-cd.yaml` file with sensible defaults.

### Configuration Sections

#### Workspace Settings

Controls where rip-cd stores its files and how it organizes them.

```yaml
workspace:
  base_dir: "~/cd_ripping"           # Base directory for all operations
  auto_create_dirs: true             # Automatically create subdirectories
  dir_structure:
    metadata: "metadata"             # Directory for YAML metadata files
    schemas: "schemas"               # Directory for JSON schemas
    output: "output"                 # Directory for ripped audio files
    logs: "logs"                     # Directory for log files
    temp: "temp"                     # Directory for temporary files
```

#### Ripper Settings

Controls the CD ripping engine and quality settings.

```yaml
ripper:
  engine: "xld"                      # Primary ripper (currently only XLD supported)

  xld:
    profile: "flac_rip"              # XLD profile to use
    executable_path: ""              # Path to XLD (empty = auto-detect)
    extra_args: []                   # Additional XLD command line arguments

  quality:
    format: "flac"                   # Output format (flac, mp3, etc.)
    compression: 5                   # FLAC compression level (0-8)
    verify: true                     # Enable verification after ripping
    error_correction: 3              # Number of error correction attempts
```

#### Output Settings

Controls how files and directories are named.

```yaml
output:
  filename_template: "{{.TrackNumber}} - {{.Title}}"     # Template for track filenames
  dir_template: "{{.Artist}} - {{.Album}} ({{.Year}})"  # Template for album directories
  sanitize_filenames: true                               # Remove invalid characters
```

**Available Template Variables:**
- `{{.Artist}}` - Album artist
- `{{.Album}}` - Album title
- `{{.Year}}` - Year extracted from date
- `{{.Date}}` - Full date
- `{{.Label}}` - Record label
- `{{.TrackNumber}}` - Track number (padded)
- `{{.Title}}` - Track title

#### Integration Settings

Controls external service integrations.

```yaml
integrations:
  musicbrainz:
    enabled: true                                    # Enable MusicBrainz lookup
    server_url: "https://musicbrainz.org/ws/2"       # MusicBrainz server URL
    rate_limit: 1.0                                  # Requests per second
    user_agent: "rip-cd/2.0.0"                      # User agent string

  beets:
    enabled: true                                    # Enable beets integration
    executable_path: ""                              # Path to beets (empty = auto-detect)
    config_path: ""                                  # Path to beets config
    auto_import: true                                # Auto-import after ripping
```

## Metadata Configuration

Metadata files describe individual CDs and are stored in YAML format in your workspace's `metadata/` directory.

### Generate Metadata Template

```bash
rip-cd generate template --workspace ~/my-rips
```

This creates a template file with IDE autocompletion support.

### Metadata Structure

#### Album Information

```yaml
album:
  title: "Album Title"                    # Required: Album name
  artist: "Artist Name"                   # Required: Primary artist
  date: "2023-03-15"                      # Optional: Release date (YYYY, YYYY-MM, or YYYY-MM-DD)
  label: "Record Label"                   # Optional: Record label
  catalog_number: "CAT-001"               # Optional: Catalog number
  barcode: "123456789012"                 # Optional: UPC/EAN barcode (12-14 digits)
  genre: "Rock"                           # Optional: Primary genre
  country: "US"                           # Optional: Country code (ISO 3166-1 alpha-2)
  disambiguation: "2023 remaster"        # Optional: Disambiguation comment
  total_time: "45:30"                     # Optional: Total album time (MM:SS or HH:MM:SS)
  packaging: "Jewel Case"                 # Optional: Physical packaging type
```

**Valid Packaging Types:**
- `"Jewel Case"`
- `"Digipak"`
- `"Cardboard Sleeve"`
- `"Gatefold Cover"`
- `"Other"`

#### Track Listing

```yaml
tracks:
  - number: 1                             # Required: Track number (1-99)
    title: "Track Title"                  # Required: Track name
    artist: "Featured Artist"             # Optional: Track-specific artist
    length: "3:45"                        # Optional: Track length (MM:SS)
    isrc: "USRC17607839"                  # Optional: ISRC code (format: LLCCCNNNNNNN)

  - number: 2
    title: "Another Track"
    length: "4:20"
```

#### Credits

Credits can be either strings or arrays of strings.

```yaml
credits:
  producer: "Producer Name"                          # Single producer
  engineer: ["Engineer 1", "Engineer 2"]            # Multiple engineers
  mastered_by: "Mastering Engineer"                  # Mastering credit
  recorded_at: "Abbey Road Studios"                  # Recording location
  mixed_by: "Mix Engineer"                           # Mixing credit
```

#### Additional Information

```yaml
notes: |
  Multi-line notes about this release.
  Special edition information, pressing details, etc.

ripping:
  drive: ""                               # CD drive used (auto-populated)
  ripper: "XLD"                          # Ripper software used (auto-populated)
  date: ""                               # Rip date (auto-populated)
  checksum: ""                           # Verification checksum (auto-populated)
```

### Validation Rules

#### Album Validation
- `title` and `artist` are required
- `date` must be in format `YYYY`, `YYYY-MM`, or `YYYY-MM-DD`
- `barcode` must be 12-14 digits
- `country` must be a 2-letter ISO country code
- `packaging` must be one of the predefined values

#### Track Validation
- `number` and `title` are required for each track
- `number` must be between 1 and 99
- `length` must be in format `MM:SS`
- `isrc` must match format `LLCCCNNNNNNN` (2 letters + 3 alphanumeric + 7 digits)

## Configuration Examples

### Minimal Configuration

**~/.rip-cd.yaml:**
```yaml
workspace:
  base_dir: "~/music-rips"

ripper:
  quality:
    format: "flac"
    compression: 8

output:
  dir_template: "{{.Artist}} - {{.Album}}"
```

**metadata/album.yaml:**
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

### Complete Configuration

**~/.rip-cd.yaml:**
```yaml
workspace:
  base_dir: "~/audiophile-rips"
  auto_create_dirs: true

ripper:
  engine: "xld"
  xld:
    profile: "audiophile_flac"
  quality:
    format: "flac"
    compression: 8
    verify: true
    error_correction: 5

output:
  dir_template: "[{{.Year}}] {{.Artist}} - {{.Album}}"
  filename_template: "{{.TrackNumber}}. {{.Title}}"
  sanitize_filenames: true

integrations:
  musicbrainz:
    enabled: true
    rate_limit: 0.5
  beets:
    enabled: true
    auto_import: true
```

**metadata/pink-floyd-dsotm.yaml:**
```yaml
# yaml-language-server: $schema=../schemas/cd-metadata-schema.json

album:
  title: "The Dark Side of the Moon"
  artist: "Pink Floyd"
  date: "1973-03-01"
  label: "Harvest Records"
  catalog_number: "SHVL 804"
  barcode: "077774655125"
  genre: "Progressive Rock"
  country: "GB"
  packaging: "Gatefold Cover"
  total_time: "42:59"

tracks:
  - number: 1
    title: "Speak to Me"
    length: "1:30"
  - number: 2
    title: "Breathe (In the Air)"
    length: "2:43"
  - number: 3
    title: "On the Run"
    length: "3:36"
  - number: 4
    title: "Time"
    length: "6:53"
  - number: 5
    title: "The Great Gig in the Sky"
    length: "4:36"
  - number: 6
    title: "Money"
    length: "6:23"
  - number: 7
    title: "Us and Them"
    length: "7:49"
  - number: 8
    title: "Any Colour You Like"
    length: "3:26"
  - number: 9
    title: "Brain Damage"
    length: "3:49"
  - number: 10
    title: "Eclipse"
    length: "2:03"

credits:
  producer: "Pink Floyd"
  engineer: "Alan Parsons"
  recorded_at: "Abbey Road Studios"
  mixed_by: "Alan Parsons"

notes: |
  Original 1973 UK pressing.
  Gatefold sleeve with original artwork.
  Matrix numbers: SHVL-804-A-2U / SHVL-804-B-2U
```

## Best Practices

### Global Configuration
1. **Use descriptive directory templates** to organize your collection
2. **Enable verification** for critical archival work
3. **Set appropriate rate limits** for MusicBrainz to be respectful
4. **Use high FLAC compression** for archival purposes (level 8)

### Metadata Configuration
1. **Always validate metadata** before ripping: `rip-cd validate metadata.yaml`
2. **Use dry runs** to test your configuration: `rip-cd rip metadata.yaml --dry-run`
3. **Include as much metadata as possible** for better organization
4. **Use consistent naming conventions** across your collection
5. **Store metadata files in version control** for backup and tracking changes

### Workflow Recommendations
1. Create workspace-specific configurations for different projects
2. Use templates to maintain consistency across similar releases
3. Validate metadata files in your editor using the JSON schema
4. Test with dry runs before committing to the actual rip
5. Backup both your configuration and metadata files regularly

### IDE Integration
The generated templates include YAML Language Server schema references for:
- **VS Code** (with YAML extension)
- **Zed** (built-in YAML support)
- **Neovim** (with yaml-language-server)
- Any editor supporting Language Server Protocol

This provides autocompletion, validation, and documentation while editing metadata files.
