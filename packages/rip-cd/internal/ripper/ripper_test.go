package ripper

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/radiosilence/dotfiles/packages/rip-cd/internal/config"
	"github.com/radiosilence/dotfiles/packages/rip-cd/internal/metadata"
)

func TestDryRun(t *testing.T) {
	// Create a temporary config
	tmpDir := t.TempDir()
	cfg := &config.Config{
		Paths: config.PathConfig{
			OutputDir: tmpDir,
		},
		Ripper: config.RipperConfig{
			Engine: "xld",
			XLD: config.XLDConfig{
				Profile: "flac_rip",
			},
			Quality: config.QualityConfig{
				Format:      "flac",
				Compression: 5,
			},
		},
		Output: config.OutputConfig{
			DirTemplate: "{{.Artist}} - {{.Album}} ({{.Year}})",
		},
		Integrations: config.IntegrationConfig{
			Beets: config.BeetsConfig{
				Enabled:    true,
				AutoImport: true,
			},
		},
	}

	// Create test metadata
	meta := &metadata.CDMetadata{
		Album: metadata.Album{
			Title:  "Test Album",
			Artist: "Test Artist",
			Date:   "2023",
		},
		Tracks: []metadata.Track{
			{Number: 1, Title: "Track One"},
			{Number: 2, Title: "Track Two"},
		},
	}

	// Test dry run (should not fail even if XLD is not installed)
	err := DryRun(cfg, meta)
	// We don't check for error here since XLD might not be installed
	// The important thing is that it doesn't panic
	if err != nil {
		t.Logf("DryRun completed with warnings: %v", err)
	}
}

func TestSetupOutputDirectory(t *testing.T) {
	tmpDir := t.TempDir()
	cfg := &config.Config{
		Paths: config.PathConfig{
			OutputDir: tmpDir,
		},
		Output: config.OutputConfig{
			DirTemplate: "{{.Artist}} - {{.Album}} ({{.Year}})",
		},
	}

	meta := &metadata.CDMetadata{
		Album: metadata.Album{
			Title:  "Test Album",
			Artist: "Test Artist",
			Date:   "2023",
		},
	}

	outputDir, err := setupOutputDirectory(cfg, meta)
	if err != nil {
		t.Fatalf("setupOutputDirectory failed: %v", err)
	}

	expectedDir := filepath.Join(tmpDir, "Test Artist - Test Album (2023)")
	if outputDir != expectedDir {
		t.Errorf("Expected output dir '%s', got '%s'", expectedDir, outputDir)
	}

	// Check that directory was created
	if _, err := os.Stat(outputDir); os.IsNotExist(err) {
		t.Error("Output directory was not created")
	}
}

func TestGenerateDirName(t *testing.T) {
	meta := &metadata.CDMetadata{
		Album: metadata.Album{
			Title:  "Test Album",
			Artist: "Test Artist",
			Date:   "2023-12-01",
			Label:  "Test Label",
		},
	}

	tests := []struct {
		template string
		expected string
	}{
		{
			template: "{{.Artist}} - {{.Album}}",
			expected: "Test Artist - Test Album",
		},
		{
			template: "{{.Artist}} - {{.Album}} ({{.Year}})",
			expected: "Test Artist - Test Album (2023)",
		},
		{
			template: "[{{.Label}}] {{.Artist}} - {{.Album}}",
			expected: "[Test Label] Test Artist - Test Album",
		},
		{
			template: "{{.Date}} - {{.Album}}",
			expected: "2023-12-01 - Test Album",
		},
	}

	for _, test := range tests {
		result := generateDirName(test.template, meta)
		if result != test.expected {
			t.Errorf("Template '%s': expected '%s', got '%s'",
				test.template, test.expected, result)
		}
	}
}

func TestGenerateFilename(t *testing.T) {
	track := metadata.Track{
		Number: 1,
		Title:  "Test Track Title",
	}

	meta := &metadata.CDMetadata{
		Album: metadata.Album{
			Title:  "Test Album",
			Artist: "Test Artist",
		},
	}

	filename := generateFilename(track, meta)
	expected := "01 - Test Track Title.flac"
	if filename != expected {
		t.Errorf("Expected filename '%s', got '%s'", expected, filename)
	}
}

func TestSanitizeFilename(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{
			input:    "Normal Filename",
			expected: "Normal Filename",
		},
		{
			input:    "File/With\\Slashes",
			expected: "File_With_Slashes",
		},
		{
			input:    "File<With>Invalid:Characters",
			expected: "File_With_Invalid_Characters",
		},
		{
			input:    "File\"With|Quotes*And?Wildcards",
			expected: "File_With_Quotes_And_Wildcards",
		},
		{
			input:    "  Spaced   Filename  ",
			expected: "Spaced Filename",
		},
		{
			input:    "Multiple    Spaces    Between",
			expected: "Multiple Spaces Between",
		},
	}

	for _, test := range tests {
		result := sanitizeFilename(test.input)
		if result != test.expected {
			t.Errorf("Input '%s': expected '%s', got '%s'",
				test.input, test.expected, result)
		}
	}
}

func TestExtractYear(t *testing.T) {
	tests := []struct {
		input    string
		expected string
	}{
		{
			input:    "2023",
			expected: "2023",
		},
		{
			input:    "2023-12",
			expected: "2023",
		},
		{
			input:    "2023-12-01",
			expected: "2023",
		},
		{
			input:    "",
			expected: "",
		},
		{
			input:    "23",
			expected: "23",
		},
		{
			input:    "invalid",
			expected: "inva",
		},
	}

	for _, test := range tests {
		result := extractYear(test.input)
		if result != test.expected {
			t.Errorf("Input '%s': expected '%s', got '%s'",
				test.input, test.expected, result)
		}
	}
}

func TestGenerateExpectedFiles(t *testing.T) {
	meta := &metadata.CDMetadata{
		Album: metadata.Album{
			Title:  "Test Album",
			Artist: "Test Artist",
		},
		Tracks: []metadata.Track{
			{Number: 1, Title: "Track One"},
			{Number: 2, Title: "Track Two"},
			{Number: 10, Title: "Track Ten"},
		},
	}

	outputDir := "/test/output"
	files := generateExpectedFiles(meta, outputDir)

	if len(files) != 3 {
		t.Errorf("Expected 3 files, got %d", len(files))
	}

	expectedFiles := []string{
		"/test/output/01 - Track One.flac",
		"/test/output/02 - Track Two.flac",
		"/test/output/10 - Track Ten.flac",
	}

	for i, expected := range expectedFiles {
		if i >= len(files) {
			t.Errorf("Missing expected file: %s", expected)
			continue
		}
		if files[i] != expected {
			t.Errorf("Expected file '%s', got '%s'", expected, files[i])
		}
	}
}

func TestDetectDrive(t *testing.T) {
	cfg := &config.Config{}

	// detectAndAnalyzeDrive returns drive info on macOS
	// This is correct behavior since XLD can detect drive capabilities
	driveInfo, err := detectAndAnalyzeDrive(cfg)
	if err != nil {
		t.Errorf("detectAndAnalyzeDrive failed: %v", err)
	}

	// DriveInfo should be populated
	if driveInfo != nil {
		t.Logf("Drive detected: %s %s", driveInfo.Manufacturer, driveInfo.Model)
	}
}

func TestFindCreatedFiles(t *testing.T) {
	// Create a temporary directory with some test files
	tmpDir := t.TempDir()

	// Create some test files
	testFiles := []string{
		"track01.flac",
		"track02.flac",
		"track03.mp3",
		"cover.jpg",
		"metadata.yaml",
	}

	for _, filename := range testFiles {
		filePath := filepath.Join(tmpDir, filename)
		if err := os.WriteFile(filePath, []byte("test"), 0644); err != nil {
			t.Fatalf("Failed to create test file: %v", err)
		}
	}

	// Find audio files
	files, err := findCreatedFiles(tmpDir)
	if err != nil {
		t.Fatalf("findCreatedFiles failed: %v", err)
	}

	// Should find 3 audio files (2 FLAC + 1 MP3)
	if len(files) != 3 {
		t.Errorf("Expected 3 audio files, got %d", len(files))
	}

	// Check that only audio files are included
	for _, file := range files {
		ext := strings.ToLower(filepath.Ext(file))
		if ext != ".flac" && ext != ".mp3" && ext != ".wav" && ext != ".m4a" {
			t.Errorf("Non-audio file found: %s", file)
		}
	}
}

func TestSaveMetadata(t *testing.T) {
	tmpDir := t.TempDir()
	cfg := &config.Config{}

	meta := &metadata.CDMetadata{
		Album: metadata.Album{
			Title:  "Test Album",
			Artist: "Test Artist",
		},
		Tracks: []metadata.Track{
			{Number: 1, Title: "Track One"},
		},
		Ripping: &metadata.Ripping{
			Drive:    "test-drive",
			Ripper:   "XLD",
			Date:     "2023-12-01 10:00:00",
			Checksum: "abc123",
		},
	}

	err := saveMetadata(cfg, meta, tmpDir)
	if err != nil {
		t.Fatalf("saveMetadata failed: %v", err)
	}

	// Check that metadata file was created
	metadataFile := filepath.Join(tmpDir, "metadata.yaml")
	if _, err := os.Stat(metadataFile); os.IsNotExist(err) {
		t.Error("Metadata file was not created")
	}

	// Read and verify content
	content, err := os.ReadFile(metadataFile)
	if err != nil {
		t.Fatalf("Failed to read metadata file: %v", err)
	}

	contentStr := string(content)
	if !strings.Contains(contentStr, "Test Album") {
		t.Error("Metadata file should contain album title")
	}
	if !strings.Contains(contentStr, "XLD") {
		t.Error("Metadata file should contain ripper info")
	}
}
