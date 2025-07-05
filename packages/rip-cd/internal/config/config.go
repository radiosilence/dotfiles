package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

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

	// Override workspace if provided
	if workspaceOverride != "" {
		config.Workspace.BaseDir = workspaceOverride
	}

	// Load from file if provided
	if configFile != "" && fileExists(configFile) {
		if err := config.loadFromFile(configFile); err != nil {
			return nil, fmt.Errorf("failed to load config file: %w", err)
		}
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
	c.Ripper.Quality.Compression = 5
	c.Ripper.Quality.Verify = true
	c.Ripper.Quality.ErrorCorrection = 3

	// Output defaults
	c.Output.FilenameTemplate = "{{.TrackNumber}} - {{.Title}}"
	c.Output.DirTemplate = "{{.Artist}} - {{.Album}} ({{.Year}})"
	c.Output.SanitizeFilenames = true

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
