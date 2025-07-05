package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"text/template"

	"github.com/spf13/viper"
	"gopkg.in/yaml.v3"
)

// Config represents the application configuration
type Config struct {
	// Workspace settings
	Workspace WorkspaceConfig `yaml:"workspace" mapstructure:"workspace"`

	// Ripper settings
	Ripper RipperConfig `yaml:"ripper" mapstructure:"ripper"`

	// Output settings
	Output OutputConfig `yaml:"output" mapstructure:"output"`

	// Integration settings
	Integrations IntegrationConfig `yaml:"integrations" mapstructure:"integrations"`

	// Drive and matrix information
	Drive  DriveConfig  `yaml:"drive" mapstructure:"drive"`
	Matrix MatrixConfig `yaml:"matrix" mapstructure:"matrix"`

	// Paths (computed at runtime)
	Paths PathConfig `yaml:"-" mapstructure:"-"`
}

// WorkspaceConfig defines workspace-related settings
type WorkspaceConfig struct {
	// Base directory for all ripping operations
	BaseDir string `yaml:"base_dir" mapstructure:"base_dir"`

	// Whether to create subdirectories automatically
	AutoCreateDirs bool `yaml:"auto_create_dirs" mapstructure:"auto_create_dirs"`

	// Directory structure template
	DirStructure DirStructureConfig `yaml:"dir_structure" mapstructure:"dir_structure"`
}

// DirStructureConfig defines the directory structure within workspace
type DirStructureConfig struct {
	Metadata string `yaml:"metadata" mapstructure:"metadata"`
	Schemas  string `yaml:"schemas" mapstructure:"schemas"`
	Output   string `yaml:"output" mapstructure:"output"`
	Logs     string `yaml:"logs" mapstructure:"logs"`
	Temp     string `yaml:"temp" mapstructure:"temp"`
}

// RipperConfig defines ripper-specific settings
type RipperConfig struct {
	// Primary ripper to use (xld, cdparanoia, etc.)
	Engine string `yaml:"engine" mapstructure:"engine"`

	// XLD-specific settings
	XLD XLDConfig `yaml:"xld" mapstructure:"xld"`

	// Quality settings
	Quality QualityConfig `yaml:"quality" mapstructure:"quality"`
}

// XLDConfig defines XLD-specific settings
type XLDConfig struct {
	// XLD profile to use
	Profile string `yaml:"profile" mapstructure:"profile"`

	// Path to XLD executable (if not in PATH)
	ExecutablePath string `yaml:"executable_path" mapstructure:"executable_path"`

	// Additional XLD arguments
	ExtraArgs []string `yaml:"extra_args" mapstructure:"extra_args"`
}

// QualityConfig defines quality-related settings
type QualityConfig struct {
	// Output format (flac, mp3, etc.)
	Format string `yaml:"format" mapstructure:"format"`

	// Compression level (for FLAC)
	Compression int `yaml:"compression" mapstructure:"compression"`

	// Verification settings
	Verify bool `yaml:"verify" mapstructure:"verify"`

	// Error correction attempts
	ErrorCorrection int `yaml:"error_correction" mapstructure:"error_correction"`

	// C2 error correction (hardware-level)
	C2ErrorCorrection bool `yaml:"c2_error_correction" mapstructure:"c2_error_correction"`

	// Maximum retry attempts for bad sectors
	MaxRetryAttempts int `yaml:"max_retry_attempts" mapstructure:"max_retry_attempts"`

	// Secure ripping mode (slowest but most accurate)
	SecureRipping bool `yaml:"secure_ripping" mapstructure:"secure_ripping"`

	// Test & Copy mode for maximum accuracy
	TestAndCopy bool `yaml:"test_and_copy" mapstructure:"test_and_copy"`

	// AccurateRip verification
	AccurateRip AccurateRipConfig `yaml:"accurate_rip" mapstructure:"accurate_rip"`

	// Spectrogram generation
	Spectrograms SpectrogramConfig `yaml:"spectrograms" mapstructure:"spectrograms"`

	// Enhanced logging for archival purposes
	EnhancedLogging LoggingConfig `yaml:"enhanced_logging" mapstructure:"enhanced_logging"`
}

// AccurateRipConfig defines AccurateRip verification settings
type AccurateRipConfig struct {
	// Enable AccurateRip verification
	Enabled bool `yaml:"enabled" mapstructure:"enabled"`

	// AccurateRip database path
	DatabasePath string `yaml:"database_path" mapstructure:"database_path"`

	// Require AccurateRip match for successful rip
	RequireMatch bool `yaml:"require_match" mapstructure:"require_match"`

	// Minimum confidence level (number of matching submissions)
	MinConfidence int `yaml:"min_confidence" mapstructure:"min_confidence"`
}

// SpectrogramConfig defines spectrogram generation settings
type SpectrogramConfig struct {
	// Enable spectrogram generation
	Enabled bool `yaml:"enabled" mapstructure:"enabled"`

	// Generate spectrograms for all tracks
	GenerateAll bool `yaml:"generate_all" mapstructure:"generate_all"`

	// Generate spectrogram for random sample track
	GenerateSample bool `yaml:"generate_sample" mapstructure:"generate_sample"`

	// Spectrogram resolution (higher = more detailed)
	Resolution int `yaml:"resolution" mapstructure:"resolution"`

	// Output format (png, svg)
	Format string `yaml:"format" mapstructure:"format"`
}

// LoggingConfig defines enhanced logging settings
type LoggingConfig struct {
	// Enable EAC-style detailed logging
	EACStyle bool `yaml:"eac_style" mapstructure:"eac_style"`

	// Include drive information in logs
	DriveInfo bool `yaml:"drive_info" mapstructure:"drive_info"`

	// Include matrix/runout numbers
	MatrixInfo bool `yaml:"matrix_info" mapstructure:"matrix_info"`

	// Include detailed error information
	DetailedErrors bool `yaml:"detailed_errors" mapstructure:"detailed_errors"`

	// Save log files
	SaveLogs bool `yaml:"save_logs" mapstructure:"save_logs"`
}

// DriveConfig defines CD drive-specific settings
type DriveConfig struct {
	// Auto-detect best drive
	AutoDetect bool `yaml:"auto_detect" mapstructure:"auto_detect"`

	// Specific drive path (if not auto-detecting)
	DevicePath string `yaml:"device_path" mapstructure:"device_path"`

	// Drive read offset correction
	ReadOffset int `yaml:"read_offset" mapstructure:"read_offset"`

	// Drive capabilities
	SupportsCDText         bool `yaml:"supports_cd_text" mapstructure:"supports_cd_text"`
	SupportsC2             bool `yaml:"supports_c2" mapstructure:"supports_c2"`
	SupportsAccurateStream bool `yaml:"supports_accurate_stream" mapstructure:"supports_accurate_stream"`
}

// MatrixConfig defines matrix/runout number detection
type MatrixConfig struct {
	// Enable matrix number detection
	Enabled bool `yaml:"enabled" mapstructure:"enabled"`

	// Manual matrix numbers
	SideA string `yaml:"side_a" mapstructure:"side_a"`
	SideB string `yaml:"side_b" mapstructure:"side_b"`

	// Mould SID codes
	MouldSID string `yaml:"mould_sid" mapstructure:"mould_sid"`

	// IFPI codes
	IFPICodes []string `yaml:"ifpi_codes" mapstructure:"ifpi_codes"`
}

// OutputConfig defines output-related settings
type OutputConfig struct {
	// Filename template
	FilenameTemplate string `yaml:"filename_template" mapstructure:"filename_template"`

	// Directory template
	DirTemplate string `yaml:"dir_template" mapstructure:"dir_template"`

	// Whether to sanitize filenames
	SanitizeFilenames bool `yaml:"sanitize_filenames" mapstructure:"sanitize_filenames"`
}

// IntegrationConfig defines external integration settings
type IntegrationConfig struct {
	// MusicBrainz integration
	MusicBrainz MusicBrainzConfig `yaml:"musicbrainz" mapstructure:"musicbrainz"`

	// Beets integration
	Beets BeetsConfig `yaml:"beets" mapstructure:"beets"`
}

// MusicBrainzConfig defines MusicBrainz integration settings
type MusicBrainzConfig struct {
	// Whether to enable MusicBrainz lookup
	Enabled bool `yaml:"enabled" mapstructure:"enabled"`

	// MusicBrainz server URL
	ServerURL string `yaml:"server_url" mapstructure:"server_url"`

	// Rate limiting (requests per second)
	RateLimit float64 `yaml:"rate_limit" mapstructure:"rate_limit"`

	// User agent for requests
	UserAgent string `yaml:"user_agent" mapstructure:"user_agent"`
}

// BeetsConfig defines beets integration settings
type BeetsConfig struct {
	// Whether to enable beets integration
	Enabled bool `yaml:"enabled" mapstructure:"enabled"`

	// Path to beets executable
	ExecutablePath string `yaml:"executable_path" mapstructure:"executable_path"`

	// Beets config file path
	ConfigPath string `yaml:"config_path" mapstructure:"config_path"`

	// Whether to auto-import after ripping
	AutoImport bool `yaml:"auto_import" mapstructure:"auto_import"`
}

// PathConfig contains computed paths (not serialized)
type PathConfig struct {
	WorkspaceDir string
	MetadataDir  string
	SchemasDir   string
	OutputDir    string
	LogsDir      string
	TempDir      string
}

// Load loads configuration from file or creates default config
func Load(configFile, workspaceOverride string) (*Config, error) {
	config := &Config{}

	// Set defaults
	config.setDefaults()

	// Load from file if provided, or try default config file
	var configToLoad string
	if configFile != "" {
		configToLoad = configFile
	} else {
		// Try default config file
		home, err := os.UserHomeDir()
		if err == nil {
			defaultConfig := filepath.Join(home, ".rip-cd.yaml")
			if fileExists(defaultConfig) {
				configToLoad = defaultConfig
			}
		}
	}

	if configToLoad != "" && fileExists(configToLoad) {
		if err := config.loadFromFile(configToLoad); err != nil {
			return nil, fmt.Errorf("failed to load config file: %w", err)
		}
	}

	// Override workspace if provided (takes precedence over config file)
	if workspaceOverride != "" {
		config.Workspace.BaseDir = workspaceOverride
	}

	// Compute paths
	if err := config.computePaths(); err != nil {
		return nil, fmt.Errorf("failed to compute paths: %w", err)
	}

	// Create directories if auto-create is enabled
	if config.Workspace.AutoCreateDirs {
		if err := config.createDirectories(); err != nil {
			return nil, fmt.Errorf("failed to create directories: %w", err)
		}
	}

	return config, nil
}

// setDefaults sets default configuration values
func (c *Config) setDefaults() {
	// Get user home directory
	home, err := os.UserHomeDir()
	if err != nil {
		home = "/tmp" // fallback
	}

	// Workspace defaults
	c.Workspace.BaseDir = filepath.Join(home, "cd_ripping")
	c.Workspace.AutoCreateDirs = true
	c.Workspace.DirStructure = DirStructureConfig{
		Metadata: "metadata",
		Schemas:  "schemas",
		Output:   "output",
		Logs:     "logs",
		Temp:     "temp",
	}

	// Ripper defaults
	c.Ripper.Engine = "xld"
	c.Ripper.XLD.Profile = "flac_rip"
	c.Ripper.Quality.Format = "flac"
	c.Ripper.Quality.Compression = 8 // Maximum compression for archival
	c.Ripper.Quality.Verify = true
	c.Ripper.Quality.ErrorCorrection = 10 // Maximum error correction attempts
	c.Ripper.Quality.C2ErrorCorrection = true
	c.Ripper.Quality.MaxRetryAttempts = 20
	c.Ripper.Quality.SecureRipping = true
	c.Ripper.Quality.TestAndCopy = true

	// AccurateRip defaults
	c.Ripper.Quality.AccurateRip.Enabled = true
	c.Ripper.Quality.AccurateRip.RequireMatch = false // Don't fail if no match
	c.Ripper.Quality.AccurateRip.MinConfidence = 2

	// Spectrogram defaults
	c.Ripper.Quality.Spectrograms.Enabled = true
	c.Ripper.Quality.Spectrograms.GenerateSample = true
	c.Ripper.Quality.Spectrograms.Resolution = 2048
	c.Ripper.Quality.Spectrograms.Format = "png"

	// Enhanced logging defaults
	c.Ripper.Quality.EnhancedLogging.EACStyle = true
	c.Ripper.Quality.EnhancedLogging.DriveInfo = true
	c.Ripper.Quality.EnhancedLogging.MatrixInfo = true
	c.Ripper.Quality.EnhancedLogging.DetailedErrors = true
	c.Ripper.Quality.EnhancedLogging.SaveLogs = true

	// Output defaults
	c.Output.FilenameTemplate = "{{.TrackNumber}} - {{.Title}}"
	c.Output.DirTemplate = "{{.Artist}} - {{.Album}} ({{.Year}})"
	c.Output.SanitizeFilenames = true

	// Drive defaults
	c.Drive.AutoDetect = true
	c.Drive.ReadOffset = 0 // Will be auto-detected
	c.Drive.SupportsCDText = true
	c.Drive.SupportsC2 = true
	c.Drive.SupportsAccurateStream = true

	// Matrix defaults
	c.Matrix.Enabled = true

	// Integration defaults
	c.Integrations.MusicBrainz.Enabled = true
	c.Integrations.MusicBrainz.ServerURL = "https://musicbrainz.org/ws/2"
	c.Integrations.MusicBrainz.RateLimit = 1.0
	c.Integrations.MusicBrainz.UserAgent = "rip-cd/2.0.0"

	c.Integrations.Beets.Enabled = true
	c.Integrations.Beets.AutoImport = true
}

// loadFromFile loads configuration from a file
func (c *Config) loadFromFile(configFile string) error {
	// Determine file format
	ext := strings.ToLower(filepath.Ext(configFile))

	switch ext {
	case ".yaml", ".yml":
		return c.loadFromYAML(configFile)
	default:
		return fmt.Errorf("unsupported config file format: %s (only .yaml/.yml supported)", ext)
	}
}

// loadFromYAML loads configuration from YAML file
func (c *Config) loadFromYAML(configFile string) error {
	viper.SetConfigFile(configFile)
	viper.SetConfigType("yaml")

	if err := viper.ReadInConfig(); err != nil {
		return err
	}

	return viper.Unmarshal(c)
}

// computePaths computes all the runtime paths
func (c *Config) computePaths() error {
	// Expand workspace directory
	workspaceDir := expandPath(c.Workspace.BaseDir)

	c.Paths.WorkspaceDir = workspaceDir
	c.Paths.MetadataDir = filepath.Join(workspaceDir, c.Workspace.DirStructure.Metadata)
	c.Paths.SchemasDir = filepath.Join(workspaceDir, c.Workspace.DirStructure.Schemas)
	c.Paths.OutputDir = filepath.Join(workspaceDir, c.Workspace.DirStructure.Output)
	c.Paths.LogsDir = filepath.Join(workspaceDir, c.Workspace.DirStructure.Logs)
	c.Paths.TempDir = filepath.Join(workspaceDir, c.Workspace.DirStructure.Temp)

	return nil
}

// createDirectories creates all necessary directories
func (c *Config) createDirectories() error {
	dirs := []string{
		c.Paths.WorkspaceDir,
		c.Paths.MetadataDir,
		c.Paths.SchemasDir,
		c.Paths.OutputDir,
		c.Paths.LogsDir,
		c.Paths.TempDir,
	}

	for _, dir := range dirs {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return fmt.Errorf("failed to create directory %s: %w", dir, err)
		}
	}

	return nil
}

// Save saves the configuration to a file
func (c *Config) Save(configFile string) error {
	data, err := yaml.Marshal(c)
	if err != nil {
		return fmt.Errorf("failed to marshal config: %w", err)
	}

	if err := os.WriteFile(configFile, data, 0644); err != nil {
		return fmt.Errorf("failed to write config file: %w", err)
	}

	return nil
}

// GenerateDefault creates a default configuration file at ~/.rip-cd.yaml
func GenerateDefault(overwrite bool) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get home directory: %w", err)
	}

	configPath := filepath.Join(home, ".rip-cd.yaml")

	// Check if file already exists
	if fileExists(configPath) && !overwrite {
		return fmt.Errorf("configuration file already exists: %s (use --overwrite to replace)", configPath)
	}

	// Create config with defaults
	config := &Config{}
	config.setDefaults()

	// Create the file with comments
	file, err := os.Create(configPath)
	if err != nil {
		return fmt.Errorf("failed to create config file: %w", err)
	}
	defer file.Close()

	// Write comprehensive configuration with detailed comments
	if err := writeDetailedConfig(file, config); err != nil {
		return fmt.Errorf("failed to write detailed config: %w", err)
	}

	fmt.Printf("✅ Created default configuration file: %s\n", configPath)
	fmt.Println("📝 Edit this file to customize your CD ripping settings")

	return nil
}

// configTemplate defines the configuration file template with detailed comments
const configTemplate = `# rip-cd Configuration File
# Zero-configuration CD ripping with sane defaults
# All settings are optional - defaults work out of the box
# Uncomment and modify values to customize behavior

# Workspace Configuration
# Controls where files are stored and organized
workspace:
  # Base directory for all ripping operations (default: {{.Workspace.BaseDir}})
  base_dir: "{{.Workspace.BaseDir}}"

  # Automatically create subdirectories (default: {{.Workspace.AutoCreateDirs}})
  # auto_create_dirs: {{.Workspace.AutoCreateDirs}}

  # Directory structure within workspace
  # dir_structure:
  #   metadata: "{{.Workspace.DirStructure.Metadata}}"    # YAML metadata files
  #   schemas: "{{.Workspace.DirStructure.Schemas}}"     # JSON validation schemas
  #   output: "{{.Workspace.DirStructure.Output}}"      # Ripped audio files
  #   logs: "{{.Workspace.DirStructure.Logs}}"        # Ripping log files
  #   temp: "{{.Workspace.DirStructure.Temp}}"        # Temporary files

# CD Ripper Configuration
# ripper:
  # Ripping engine to use (options: xld) (default: {{.Ripper.Engine}})
  # engine: "{{.Ripper.Engine}}"

  # XLD-specific settings
  # xld:
    # XLD profile name (default: {{.Ripper.XLD.Profile}})
    # profile: "{{.Ripper.XLD.Profile}}"
    # Path to XLD executable (empty = auto-detect) (default: "{{.Ripper.XLD.ExecutablePath}}")
    # executable_path: "{{.Ripper.XLD.ExecutablePath}}"
    # Additional command line arguments
    # extra_args: []

  # Audio quality and verification settings
  # quality:
    # Output format (options: flac, mp3) (default: {{.Ripper.Quality.Format}})
    # format: "{{.Ripper.Quality.Format}}"
    # FLAC compression level (0-8, higher = smaller files) (default: {{.Ripper.Quality.Compression}})
    # compression: {{.Ripper.Quality.Compression}}
    # Enable verification after ripping (default: {{.Ripper.Quality.Verify}})
    # verify: {{.Ripper.Quality.Verify}}
    # Number of error correction attempts (default: {{.Ripper.Quality.ErrorCorrection}})
    # error_correction: {{.Ripper.Quality.ErrorCorrection}}
    # Use C2 error correction if drive supports it (default: {{.Ripper.Quality.C2ErrorCorrection}})
    # c2_error_correction: {{.Ripper.Quality.C2ErrorCorrection}}
    # Maximum retry attempts for bad sectors (default: {{.Ripper.Quality.MaxRetryAttempts}})
    # max_retry_attempts: {{.Ripper.Quality.MaxRetryAttempts}}
    # Use secure ripping mode (slower but more accurate) (default: {{.Ripper.Quality.SecureRipping}})
    # secure_ripping: {{.Ripper.Quality.SecureRipping}}
    # Use Test & Copy mode for dual-pass verification (default: {{.Ripper.Quality.TestAndCopy}})
    # test_and_copy: {{.Ripper.Quality.TestAndCopy}}

    # AccurateRip verification settings
    # accurate_rip:
      # Enable AccurateRip database verification (default: {{.Ripper.Quality.AccurateRip.Enabled}})
      # enabled: {{.Ripper.Quality.AccurateRip.Enabled}}
      # Require AccurateRip match for successful rip (default: {{.Ripper.Quality.AccurateRip.RequireMatch}})
      # require_match: {{.Ripper.Quality.AccurateRip.RequireMatch}}
      # Minimum confidence level (number of matching submissions) (default: {{.Ripper.Quality.AccurateRip.MinConfidence}})
      # min_confidence: {{.Ripper.Quality.AccurateRip.MinConfidence}}

    # Spectrogram generation settings
    # spectrograms:
      # Enable spectrogram generation (requires sox) (default: {{.Ripper.Quality.Spectrograms.Enabled}})
      # enabled: {{.Ripper.Quality.Spectrograms.Enabled}}
      # Generate spectrograms for all tracks (default: {{.Ripper.Quality.Spectrograms.GenerateAll}})
      # generate_all: {{.Ripper.Quality.Spectrograms.GenerateAll}}
      # Generate spectrogram for sample track only (default: {{.Ripper.Quality.Spectrograms.GenerateSample}})
      # generate_sample: {{.Ripper.Quality.Spectrograms.GenerateSample}}
      # Spectrogram resolution (higher = more detailed) (default: {{.Ripper.Quality.Spectrograms.Resolution}})
      # resolution: {{.Ripper.Quality.Spectrograms.Resolution}}
      # Output format (options: png, svg) (default: {{.Ripper.Quality.Spectrograms.Format}})
      # format: "{{.Ripper.Quality.Spectrograms.Format}}"

    # Enhanced logging settings
    # enhanced_logging:
      # Generate EAC-style detailed logs (default: {{.Ripper.Quality.EnhancedLogging.EACStyle}})
      # eac_style: {{.Ripper.Quality.EnhancedLogging.EACStyle}}
      # Include drive information in logs (default: {{.Ripper.Quality.EnhancedLogging.DriveInfo}})
      # drive_info: {{.Ripper.Quality.EnhancedLogging.DriveInfo}}
      # Include matrix/runout numbers (default: {{.Ripper.Quality.EnhancedLogging.MatrixInfo}})
      # matrix_info: {{.Ripper.Quality.EnhancedLogging.MatrixInfo}}
      # Include detailed error information (default: {{.Ripper.Quality.EnhancedLogging.DetailedErrors}})
      # detailed_errors: {{.Ripper.Quality.EnhancedLogging.DetailedErrors}}
      # Save log files to disk (default: {{.Ripper.Quality.EnhancedLogging.SaveLogs}})
      # save_logs: {{.Ripper.Quality.EnhancedLogging.SaveLogs}}

# Output File Configuration
# output:
  # Template for track filenames (default: {{.Output.FilenameTemplate}})
  # Available variables: TrackNumber, Title, Artist
  # filename_template: "{{.Output.FilenameTemplate}}"
  # Template for album directories (default: {{.Output.DirTemplate}})
  # Available variables: Artist, Album, Year, Date, Label
  # dir_template: "{{.Output.DirTemplate}}"
  # Remove invalid characters from filenames (default: {{.Output.SanitizeFilenames}})
  # sanitize_filenames: {{.Output.SanitizeFilenames}}

# CD Drive Configuration
# drive:
  # Automatically detect best available drive (default: {{.Drive.AutoDetect}})
  # auto_detect: {{.Drive.AutoDetect}}
  # Specific drive device path (empty = auto-detect) (default: "{{.Drive.DevicePath}}")
  # device_path: "{{.Drive.DevicePath}}"
  # Drive read offset correction in samples (default: {{.Drive.ReadOffset}})
  # read_offset: {{.Drive.ReadOffset}}
  # Drive supports CD-Text reading (default: {{.Drive.SupportsCDText}})
  # supports_cd_text: {{.Drive.SupportsCDText}}
  # Drive supports C2 error correction (default: {{.Drive.SupportsC2}})
  # supports_c2: {{.Drive.SupportsC2}}
  # Drive supports accurate stream mode (default: {{.Drive.SupportsAccurateStream}})
  # supports_accurate_stream: {{.Drive.SupportsAccurateStream}}

# Matrix/Runout Number Configuration
# matrix:
  # Enable matrix number detection and recording (default: {{.Matrix.Enabled}})
  # enabled: {{.Matrix.Enabled}}
  # Manual matrix numbers (found etched in the dead wax)
  # side_a: ""
  # side_b: ""
  # Mould SID code (IFPI identifier)
  # mould_sid: ""
  # IFPI codes (anti-piracy identifiers)
  # ifpi_codes: []

# External Service Integration
# integrations:
  # MusicBrainz metadata service
  # musicbrainz:
    # Enable MusicBrainz metadata lookup (default: {{.Integrations.MusicBrainz.Enabled}})
    # enabled: {{.Integrations.MusicBrainz.Enabled}}
    # MusicBrainz server URL (default: {{.Integrations.MusicBrainz.ServerURL}})
    # server_url: "{{.Integrations.MusicBrainz.ServerURL}}"
    # Request rate limit (requests per second) (default: {{.Integrations.MusicBrainz.RateLimit}})
    # rate_limit: {{.Integrations.MusicBrainz.RateLimit}}
    # User agent string for requests (default: {{.Integrations.MusicBrainz.UserAgent}})
    # user_agent: "{{.Integrations.MusicBrainz.UserAgent}}"

  # Beets music library management
  # beets:
    # Enable beets integration (default: {{.Integrations.Beets.Enabled}})
    # enabled: {{.Integrations.Beets.Enabled}}
    # Path to beets executable (empty = auto-detect) (default: "{{.Integrations.Beets.ExecutablePath}}")
    # executable_path: "{{.Integrations.Beets.ExecutablePath}}"
    # Path to beets config file (empty = default) (default: "{{.Integrations.Beets.ConfigPath}}")
    # config_path: "{{.Integrations.Beets.ConfigPath}}"
    # Automatically import after ripping (default: {{.Integrations.Beets.AutoImport}})
    # auto_import: {{.Integrations.Beets.AutoImport}}
`

// writeDetailedConfig writes a comprehensive configuration file using templates
func writeDetailedConfig(file *os.File, config *Config) error {
	tmpl, err := template.New("config").Parse(configTemplate)
	if err != nil {
		return fmt.Errorf("failed to parse config template: %w", err)
	}

	return tmpl.Execute(file, config)
}

// fileExists checks if a file exists
func fileExists(filename string) bool {
	_, err := os.Stat(filename)
	return err == nil
}

// expandPath expands ~ to home directory
func expandPath(path string) string {
	if strings.HasPrefix(path, "~/") {
		home, err := os.UserHomeDir()
		if err != nil {
			return path
		}
		return filepath.Join(home, path[2:])
	}
	return path
}
