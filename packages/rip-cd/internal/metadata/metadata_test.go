package metadata

import (
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/radiosilence/dotfiles/packages/rip-cd/internal/config"
)

func TestParse(t *testing.T) {
	// Create a temporary YAML file for testing
	tmpDir := t.TempDir()
	metadataFile := filepath.Join(tmpDir, "test.yaml")

	yamlContent := `
album:
  title: "Test Album"
  artist: "Test Artist"
  date: "2023"
  label: "Test Label"
  catalog_number: "TEST-001"
  barcode: "123456789012"
  genre: "Rock"
  country: "US"
  packaging: "Jewel Case"
  total_time: "45:30"

tracks:
  - number: 1
    title: "Track One"
    length: "3:45"
  - number: 2
    title: "Track Two"
    length: "4:20"

credits:
  producer: "Test Producer"
  engineer: "Test Engineer"

notes: "Test notes"
`

	if err := os.WriteFile(metadataFile, []byte(yamlContent), 0644); err != nil {
		t.Fatalf("Failed to write test file: %v", err)
	}

	// Test parsing
	metadata, err := Parse(metadataFile)
	if err != nil {
		t.Fatalf("Parse failed: %v", err)
	}

	// Validate parsed data
	if metadata.Album.Title != "Test Album" {
		t.Errorf("Expected album title 'Test Album', got '%s'", metadata.Album.Title)
	}
	if metadata.Album.Artist != "Test Artist" {
		t.Errorf("Expected album artist 'Test Artist', got '%s'", metadata.Album.Artist)
	}
	if len(metadata.Tracks) != 2 {
		t.Errorf("Expected 2 tracks, got %d", len(metadata.Tracks))
	}
	if metadata.Tracks[0].Number != 1 {
		t.Errorf("Expected track number 1, got %d", metadata.Tracks[0].Number)
	}
	if metadata.Tracks[0].Title != "Track One" {
		t.Errorf("Expected track title 'Track One', got '%s'", metadata.Tracks[0].Title)
	}
}

func TestParseInvalidFile(t *testing.T) {
	// Test parsing non-existent file
	_, err := Parse("nonexistent.yaml")
	if err == nil {
		t.Error("Expected error for non-existent file, got nil")
	}
}

func TestParseInvalidYAML(t *testing.T) {
	// Create a temporary invalid YAML file
	tmpDir := t.TempDir()
	metadataFile := filepath.Join(tmpDir, "invalid.yaml")

	invalidYAML := `
album:
  title: "Test Album"
  artist: "Test Artist"
tracks:
  - number: 1
    title: "Track One"
  - number: invalid_number
    title: "Track Two"
`

	if err := os.WriteFile(metadataFile, []byte(invalidYAML), 0644); err != nil {
		t.Fatalf("Failed to write test file: %v", err)
	}

	// Test parsing - should fail during validation
	_, err := Parse(metadataFile)
	if err == nil {
		t.Error("Expected error for invalid YAML, got nil")
	}
}

func TestValidateMetadata(t *testing.T) {
	// Test valid metadata
	validMetadata := &CDMetadata{
		Album: Album{
			Title:  "Test Album",
			Artist: "Test Artist",
		},
		Tracks: []Track{
			{Number: 1, Title: "Track One"},
			{Number: 2, Title: "Track Two"},
		},
	}

	if err := validateMetadata(validMetadata); err != nil {
		t.Errorf("Expected no error for valid metadata, got: %v", err)
	}

	// Test invalid metadata - missing title
	invalidMetadata := &CDMetadata{
		Album: Album{
			Artist: "Test Artist",
		},
		Tracks: []Track{
			{Number: 1, Title: "Track One"},
		},
	}

	if err := validateMetadata(invalidMetadata); err == nil {
		t.Error("Expected error for missing album title, got nil")
	}

	// Test invalid metadata - no tracks
	noTracksMetadata := &CDMetadata{
		Album: Album{
			Title:  "Test Album",
			Artist: "Test Artist",
		},
		Tracks: []Track{},
	}

	if err := validateMetadata(noTracksMetadata); err == nil {
		t.Error("Expected error for no tracks, got nil")
	}
}

func TestValidateBusinessRules(t *testing.T) {
	// Test valid metadata
	validMetadata := &CDMetadata{
		Album: Album{
			Title:   "Test Album",
			Artist:  "Test Artist",
			Date:    "2023-12-01",
			Barcode: "123456789012",
			Country: "US",
		},
		Tracks: []Track{
			{Number: 1, Title: "Track One", Length: "3:45"},
			{Number: 2, Title: "Track Two", Length: "4:20"},
		},
	}

	if err := validateBusinessRules(validMetadata); err != nil {
		t.Errorf("Expected no error for valid business rules, got: %v", err)
	}

	// Test invalid date format
	invalidDateMetadata := &CDMetadata{
		Album: Album{
			Title:  "Test Album",
			Artist: "Test Artist",
			Date:   "invalid-date",
		},
		Tracks: []Track{
			{Number: 1, Title: "Track One"},
		},
	}

	if err := validateBusinessRules(invalidDateMetadata); err == nil {
		t.Error("Expected error for invalid date format, got nil")
	}

	// Test invalid barcode
	invalidBarcodeMetadata := &CDMetadata{
		Album: Album{
			Title:   "Test Album",
			Artist:  "Test Artist",
			Barcode: "invalid-barcode",
		},
		Tracks: []Track{
			{Number: 1, Title: "Track One"},
		},
	}

	if err := validateBusinessRules(invalidBarcodeMetadata); err == nil {
		t.Error("Expected error for invalid barcode, got nil")
	}

	// Test invalid country code
	invalidCountryMetadata := &CDMetadata{
		Album: Album{
			Title:   "Test Album",
			Artist:  "Test Artist",
			Country: "USA", // Should be 2 letters
		},
		Tracks: []Track{
			{Number: 1, Title: "Track One"},
		},
	}

	if err := validateBusinessRules(invalidCountryMetadata); err == nil {
		t.Error("Expected error for invalid country code, got nil")
	}

	// Test invalid track number
	invalidTrackMetadata := &CDMetadata{
		Album: Album{
			Title:  "Test Album",
			Artist: "Test Artist",
		},
		Tracks: []Track{
			{Number: 0, Title: "Track Zero"}, // Invalid track number
		},
	}

	if err := validateBusinessRules(invalidTrackMetadata); err == nil {
		t.Error("Expected error for invalid track number, got nil")
	}
}

func TestGenerateTemplate(t *testing.T) {
	// Create a temporary config
	tmpDir := t.TempDir()
	cfg := &config.Config{
		Paths: config.PathConfig{
			MetadataDir: tmpDir,
			SchemasDir:  tmpDir,
		},
	}

	// Test template generation
	if err := GenerateTemplate(cfg, "yaml"); err != nil {
		t.Errorf("GenerateTemplate failed: %v", err)
	}

	// Check if template file was created
	templateFile := filepath.Join(tmpDir, "template.yaml")
	if _, err := os.Stat(templateFile); os.IsNotExist(err) {
		t.Error("Template file was not created")
	}

	// Read and verify template content
	content, err := os.ReadFile(templateFile)
	if err != nil {
		t.Fatalf("Failed to read template file: %v", err)
	}

	contentStr := string(content)
	if !strings.Contains(contentStr, "yaml-language-server") {
		t.Error("Template should contain yaml-language-server comment")
	}
	if !strings.Contains(contentStr, "Album Title Here") {
		t.Error("Template should contain sample data")
	}

	// Test invalid format
	if err := GenerateTemplate(cfg, "invalid"); err == nil {
		t.Error("Expected error for invalid format, got nil")
	}
}

func TestGenerateSchema(t *testing.T) {
	// Create a temporary config
	tmpDir := t.TempDir()
	cfg := &config.Config{
		Paths: config.PathConfig{
			SchemasDir: tmpDir,
		},
	}

	// Test schema generation
	if err := GenerateSchema(cfg, "json"); err != nil {
		t.Errorf("GenerateSchema failed: %v", err)
	}

	// Check if schema file was created
	schemaFile := filepath.Join(tmpDir, "cd-metadata-schema.json")
	if _, err := os.Stat(schemaFile); os.IsNotExist(err) {
		t.Error("Schema file was not created")
	}

	// Read and verify schema content
	content, err := os.ReadFile(schemaFile)
	if err != nil {
		t.Fatalf("Failed to read schema file: %v", err)
	}

	contentStr := string(content)
	if !strings.Contains(contentStr, "json-schema.org") {
		t.Error("Schema should contain JSON schema reference")
	}
	if !strings.Contains(contentStr, "CD Metadata Schema") {
		t.Error("Schema should contain title")
	}

	// Test invalid format
	if err := GenerateSchema(cfg, "invalid"); err == nil {
		t.Error("Expected error for invalid format, got nil")
	}
}

func TestValidate(t *testing.T) {
	// Create a temporary config and valid metadata file
	tmpDir := t.TempDir()
	cfg := &config.Config{
		Paths: config.PathConfig{
			MetadataDir: tmpDir,
			SchemasDir:  tmpDir,
		},
	}

	metadataFile := filepath.Join(tmpDir, "test.yaml")
	validYAML := `
album:
  title: "Test Album"
  artist: "Test Artist"
  date: "2023"

tracks:
  - number: 1
    title: "Track One"
  - number: 2
    title: "Track Two"
`

	if err := os.WriteFile(metadataFile, []byte(validYAML), 0644); err != nil {
		t.Fatalf("Failed to write test file: %v", err)
	}

	// Test validation
	if err := Validate(cfg, metadataFile); err != nil {
		t.Errorf("Validate failed: %v", err)
	}

	// Test validation with invalid file
	if err := Validate(cfg, "nonexistent.yaml"); err == nil {
		t.Error("Expected error for non-existent file, got nil")
	}
}

func TestCreateSampleMetadata(t *testing.T) {
	sample := createSampleMetadata()

	if sample.Album.Title == "" {
		t.Error("Sample metadata should have album title")
	}
	if sample.Album.Artist == "" {
		t.Error("Sample metadata should have album artist")
	}
	if len(sample.Tracks) == 0 {
		t.Error("Sample metadata should have tracks")
	}
	if sample.Credits == nil {
		t.Error("Sample metadata should have credits")
	}
	if sample.Ripping == nil {
		t.Error("Sample metadata should have ripping info")
	}
}

func TestCreateJSONSchema(t *testing.T) {
	schema := createJSONSchema()

	if schema["$schema"] == nil {
		t.Error("Schema should have $schema property")
	}
	if schema["title"] == nil {
		t.Error("Schema should have title property")
	}
	if schema["properties"] == nil {
		t.Error("Schema should have properties")
	}

	// Check required fields
	required, ok := schema["required"].([]string)
	if !ok {
		t.Error("Schema should have required array")
	}
	if len(required) < 2 {
		t.Error("Schema should have at least 2 required fields")
	}
}
