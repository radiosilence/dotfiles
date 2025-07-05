package config

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestLoad(t *testing.T) {
	// Test loading default config
	cfg, err := Load("", "")
	if err != nil {
		t.Fatalf("Load with defaults failed: %v", err)
	}

	// Check default values
	if cfg.Ripper.Engine != "xld" {
		t.Errorf("Expected default ripper engine 'xld', got '%s'", cfg.Ripper.Engine)
	}
	if cfg.Ripper.Quality.Format != "flac" {
		t.Errorf("Expected default format 'flac', got '%s'", cfg.Ripper.Quality.Format)
	}
	if !cfg.Workspace.AutoCreateDirs {
		t.Error("Expected auto create dirs to be true by default")
	}
	if !cfg.Integrations.MusicBrainz.Enabled {
		t.Error("Expected MusicBrainz to be enabled by default")
	}
}

func TestLoadWithWorkspaceOverride(t *testing.T) {
	tmpDir := t.TempDir()
	customWorkspace := filepath.Join(tmpDir, "custom_workspace")

	cfg, err := Load("", customWorkspace)
	if err != nil {
		t.Fatalf("Load with workspace override failed: %v", err)
	}

	if cfg.Workspace.BaseDir != customWorkspace {
		t.Errorf("Expected workspace '%s', got '%s'", customWorkspace, cfg.Workspace.BaseDir)
	}
}

func TestLoadFromFile(t *testing.T) {
	// Create a temporary config file
	tmpDir := t.TempDir()
	configFile := filepath.Join(tmpDir, "config.yaml")

	configContent := `
workspace:
  base_dir: "/custom/workspace"
  auto_create_dirs: false

ripper:
  engine: "cdparanoia"
  quality:
    format: "mp3"
    compression: 3

integrations:
  musicbrainz:
    enabled: false
  beets:
    enabled: false
`

	if err := os.WriteFile(configFile, []byte(configContent), 0644); err != nil {
		t.Fatalf("Failed to write config file: %v", err)
	}

	cfg, err := Load(configFile, "")
	if err != nil {
		t.Fatalf("Load from file failed: %v", err)
	}

	// Check loaded values
	if cfg.Workspace.BaseDir != "/custom/workspace" {
		t.Errorf("Expected workspace '/custom/workspace', got '%s'", cfg.Workspace.BaseDir)
	}
	if cfg.Workspace.AutoCreateDirs {
		t.Error("Expected auto create dirs to be false")
	}
	if cfg.Ripper.Engine != "cdparanoia" {
		t.Errorf("Expected ripper engine 'cdparanoia', got '%s'", cfg.Ripper.Engine)
	}
	if cfg.Ripper.Quality.Format != "mp3" {
		t.Errorf("Expected format 'mp3', got '%s'", cfg.Ripper.Quality.Format)
	}
	if cfg.Integrations.MusicBrainz.Enabled {
		t.Error("Expected MusicBrainz to be disabled")
	}
}

func TestLoadFromInvalidFile(t *testing.T) {
	// Test loading non-existent file (should use defaults)
	cfg, err := Load("nonexistent.yaml", "")
	if err != nil {
		t.Fatalf("Load with non-existent file failed: %v", err)
	}

	// Should still have defaults
	if cfg.Ripper.Engine != "xld" {
		t.Errorf("Expected default ripper engine 'xld', got '%s'", cfg.Ripper.Engine)
	}
}

func TestLoadFromUnsupportedFormat(t *testing.T) {
	// Create a file with unsupported extension
	tmpDir := t.TempDir()
	configFile := filepath.Join(tmpDir, "config.toml")

	if err := os.WriteFile(configFile, []byte("test = true"), 0644); err != nil {
		t.Fatalf("Failed to write config file: %v", err)
	}

	_, err := Load(configFile, "")
	if err == nil {
		t.Error("Expected error for unsupported file format, got nil")
	}
	if !strings.Contains(err.Error(), "unsupported config file format") {
		t.Errorf("Expected unsupported format error, got: %v", err)
	}
}

func TestComputePaths(t *testing.T) {
	cfg := &Config{}
	cfg.setDefaults()

	// Override workspace for testing
	tmpDir := t.TempDir()
	cfg.Workspace.BaseDir = tmpDir

	if err := cfg.computePaths(); err != nil {
		t.Fatalf("computePaths failed: %v", err)
	}

	// Check computed paths
	if cfg.Paths.WorkspaceDir != tmpDir {
		t.Errorf("Expected workspace dir '%s', got '%s'", tmpDir, cfg.Paths.WorkspaceDir)
	}

	expectedMetadataDir := filepath.Join(tmpDir, "metadata")
	if cfg.Paths.MetadataDir != expectedMetadataDir {
		t.Errorf("Expected metadata dir '%s', got '%s'", expectedMetadataDir, cfg.Paths.MetadataDir)
	}

	expectedSchemasDir := filepath.Join(tmpDir, "schemas")
	if cfg.Paths.SchemasDir != expectedSchemasDir {
		t.Errorf("Expected schemas dir '%s', got '%s'", expectedSchemasDir, cfg.Paths.SchemasDir)
	}
}

func TestCreateDirectories(t *testing.T) {
	cfg := &Config{}
	cfg.setDefaults()

	// Override workspace for testing
	tmpDir := t.TempDir()
	cfg.Workspace.BaseDir = tmpDir
	cfg.Workspace.AutoCreateDirs = true

	if err := cfg.computePaths(); err != nil {
		t.Fatalf("computePaths failed: %v", err)
	}

	if err := cfg.createDirectories(); err != nil {
		t.Fatalf("createDirectories failed: %v", err)
	}

	// Check that directories were created
	dirs := []string{
		cfg.Paths.WorkspaceDir,
		cfg.Paths.MetadataDir,
		cfg.Paths.SchemasDir,
		cfg.Paths.OutputDir,
		cfg.Paths.LogsDir,
		cfg.Paths.TempDir,
	}

	for _, dir := range dirs {
		if _, err := os.Stat(dir); os.IsNotExist(err) {
			t.Errorf("Directory was not created: %s", dir)
		}
	}
}

func TestSave(t *testing.T) {
	cfg := &Config{}
	cfg.setDefaults()

	tmpDir := t.TempDir()
	configFile := filepath.Join(tmpDir, "saved_config.yaml")

	if err := cfg.Save(configFile); err != nil {
		t.Fatalf("Save failed: %v", err)
	}

	// Check that file was created
	if _, err := os.Stat(configFile); os.IsNotExist(err) {
		t.Error("Config file was not saved")
	}

	// Try to load the saved config
	loadedCfg, err := Load(configFile, "")
	if err != nil {
		t.Fatalf("Failed to load saved config: %v", err)
	}

	// Check some values
	if loadedCfg.Ripper.Engine != cfg.Ripper.Engine {
		t.Errorf("Saved and loaded ripper engine don't match: %s vs %s",
			cfg.Ripper.Engine, loadedCfg.Ripper.Engine)
	}
}

func TestExpandPath(t *testing.T) {
	// Test home directory expansion
	home, err := os.UserHomeDir()
	if err != nil {
		t.Skip("Cannot get home directory, skipping test")
	}

	expanded := expandPath("~/test/path")
	expected := filepath.Join(home, "test/path")
	if expanded != expected {
		t.Errorf("Expected expanded path '%s', got '%s'", expected, expanded)
	}

	// Test absolute path (should not be changed)
	absPath := "/absolute/path"
	expanded = expandPath(absPath)
	if expanded != absPath {
		t.Errorf("Absolute path should not be changed: got '%s'", expanded)
	}

	// Test relative path (should not be changed)
	relPath := "relative/path"
	expanded = expandPath(relPath)
	if expanded != relPath {
		t.Errorf("Relative path should not be changed: got '%s'", expanded)
	}
}

func TestFileExists(t *testing.T) {
	// Test existing file
	tmpDir := t.TempDir()
	existingFile := filepath.Join(tmpDir, "existing.txt")

	if err := os.WriteFile(existingFile, []byte("test"), 0644); err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}

	if !fileExists(existingFile) {
		t.Error("fileExists should return true for existing file")
	}

	// Test non-existing file
	nonExistingFile := filepath.Join(tmpDir, "nonexistent.txt")
	if fileExists(nonExistingFile) {
		t.Error("fileExists should return false for non-existing file")
	}
}

func TestSetDefaults(t *testing.T) {
	cfg := &Config{}
	cfg.setDefaults()

	// Test workspace defaults
	if cfg.Workspace.BaseDir == "" {
		t.Error("Workspace base dir should not be empty")
	}
	if !cfg.Workspace.AutoCreateDirs {
		t.Error("Auto create dirs should be true by default")
	}

	// Test directory structure defaults
	if cfg.Workspace.DirStructure.Metadata != "metadata" {
		t.Errorf("Expected metadata dir 'metadata', got '%s'", cfg.Workspace.DirStructure.Metadata)
	}
	if cfg.Workspace.DirStructure.Schemas != "schemas" {
		t.Errorf("Expected schemas dir 'schemas', got '%s'", cfg.Workspace.DirStructure.Schemas)
	}

	// Test ripper defaults
	if cfg.Ripper.Engine != "xld" {
		t.Errorf("Expected ripper engine 'xld', got '%s'", cfg.Ripper.Engine)
	}
	if cfg.Ripper.XLD.Profile != "flac_rip" {
		t.Errorf("Expected XLD profile 'flac_rip', got '%s'", cfg.Ripper.XLD.Profile)
	}
	if cfg.Ripper.Quality.Format != "flac" {
		t.Errorf("Expected format 'flac', got '%s'", cfg.Ripper.Quality.Format)
	}
	if cfg.Ripper.Quality.Compression != 5 {
		t.Errorf("Expected compression 5, got %d", cfg.Ripper.Quality.Compression)
	}

	// Test integration defaults
	if !cfg.Integrations.MusicBrainz.Enabled {
		t.Error("MusicBrainz should be enabled by default")
	}
	if cfg.Integrations.MusicBrainz.ServerURL != "https://musicbrainz.org/ws/2" {
		t.Errorf("Unexpected MusicBrainz server URL: %s", cfg.Integrations.MusicBrainz.ServerURL)
	}
	if !cfg.Integrations.Beets.Enabled {
		t.Error("Beets should be enabled by default")
	}
}
