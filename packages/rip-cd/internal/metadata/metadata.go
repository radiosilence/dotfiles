package metadata

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/radiosilence/dotfiles/packages/rip-cd/internal/config"
	"github.com/sirupsen/logrus"
	"gopkg.in/yaml.v3"
)

// CDMetadata represents the complete metadata for a CD
type CDMetadata struct {
	Album   Album    `yaml:"album" json:"album"`
	Tracks  []Track  `yaml:"tracks" json:"tracks"`
	Credits *Credits `yaml:"credits,omitempty" json:"credits,omitempty"`
	Notes   string   `yaml:"notes,omitempty" json:"notes,omitempty"`
	Ripping *Ripping `yaml:"ripping,omitempty" json:"ripping,omitempty"`
}

// Album represents album-level metadata
type Album struct {
	Title          string `yaml:"title" json:"title"`
	Artist         string `yaml:"artist" json:"artist"`
	Date           string `yaml:"date,omitempty" json:"date,omitempty"`
	Label          string `yaml:"label,omitempty" json:"label,omitempty"`
	CatalogNumber  string `yaml:"catalog_number,omitempty" json:"catalog_number,omitempty"`
	Barcode        string `yaml:"barcode,omitempty" json:"barcode,omitempty"`
	Genre          string `yaml:"genre,omitempty" json:"genre,omitempty"`
	Country        string `yaml:"country,omitempty" json:"country,omitempty"`
	Disambiguation string `yaml:"disambiguation,omitempty" json:"disambiguation,omitempty"`
	TotalTime      string `yaml:"total_time,omitempty" json:"total_time,omitempty"`
	Packaging      string `yaml:"packaging,omitempty" json:"packaging,omitempty"`
}

// Track represents individual track metadata
type Track struct {
	Number int    `yaml:"number" json:"number"`
	Title  string `yaml:"title" json:"title"`
	Artist string `yaml:"artist,omitempty" json:"artist,omitempty"`
	Length string `yaml:"length,omitempty" json:"length,omitempty"`
	ISRC   string `yaml:"isrc,omitempty" json:"isrc,omitempty"`
}

// Credits represents production credits
type Credits struct {
	Producer   interface{} `yaml:"producer,omitempty" json:"producer,omitempty"`
	Engineer   interface{} `yaml:"engineer,omitempty" json:"engineer,omitempty"`
	MasteredBy interface{} `yaml:"mastered_by,omitempty" json:"mastered_by,omitempty"`
	RecordedAt string      `yaml:"recorded_at,omitempty" json:"recorded_at,omitempty"`
	MixedBy    interface{} `yaml:"mixed_by,omitempty" json:"mixed_by,omitempty"`
}

// Ripping represents ripping-specific metadata
type Ripping struct {
	Drive    string `yaml:"drive,omitempty" json:"drive,omitempty"`
	Ripper   string `yaml:"ripper,omitempty" json:"ripper,omitempty"`
	Date     string `yaml:"date,omitempty" json:"date,omitempty"`
	Checksum string `yaml:"checksum,omitempty" json:"checksum,omitempty"`
}

// Parse parses a metadata file and returns CDMetadata
func Parse(metadataFile string) (*CDMetadata, error) {
	if !fileExists(metadataFile) {
		return nil, fmt.Errorf("metadata file not found: %s", metadataFile)
	}

	data, err := os.ReadFile(metadataFile)
	if err != nil {
		return nil, fmt.Errorf("failed to read metadata file: %w", err)
	}

	var metadata CDMetadata
	if err := yaml.Unmarshal(data, &metadata); err != nil {
		return nil, fmt.Errorf("failed to parse YAML metadata: %w", err)
	}

	// Validate the parsed metadata
	if err := validateMetadata(&metadata); err != nil {
		return nil, fmt.Errorf("invalid metadata: %w", err)
	}

	logrus.Infof("📀 Parsed metadata: %s - %s (%s)", metadata.Album.Artist, metadata.Album.Title, metadata.Album.Date)
	logrus.Infof("🎵 Track count: %d", len(metadata.Tracks))

	return &metadata, nil
}

// GenerateTemplate generates a metadata template file
func GenerateTemplate(cfg *config.Config, format string) error {
	if format != "yaml" {
		return fmt.Errorf("only YAML format is supported for templates")
	}

	templateFile := filepath.Join(cfg.Paths.MetadataDir, "template.yaml")

	template := createSampleMetadata()

	// Add YAML schema comment at the top
	schemaPath := filepath.Join(cfg.Paths.SchemasDir, "cd-metadata-schema.json")
	relativeSchemaPath, err := filepath.Rel(cfg.Paths.MetadataDir, schemaPath)
	if err != nil {
		relativeSchemaPath = "../schemas/cd-metadata-schema.json"
	}

	file, err := os.Create(templateFile)
	if err != nil {
		return fmt.Errorf("failed to create template file: %w", err)
	}
	defer file.Close()

	// Write schema comment
	fmt.Fprintf(file, "# yaml-language-server: $schema=%s\n", relativeSchemaPath)
	fmt.Fprintf(file, "# CD Metadata Template\n")
	fmt.Fprintf(file, "# Edit this file with your album information\n")
	fmt.Fprintf(file, "# Use 'rip-cd validate' to check your metadata before ripping\n\n")

	// Write YAML content
	encoder := yaml.NewEncoder(file)
	encoder.SetIndent(2)
	if err := encoder.Encode(template); err != nil {
		return fmt.Errorf("failed to write template: %w", err)
	}

	logrus.Infof("✅ Template generated: %s", templateFile)
	logrus.Infof("📝 Edit this file with your album information, then run:")
	logrus.Infof("   rip-cd validate %s", templateFile)
	logrus.Infof("   rip-cd rip %s", templateFile)

	return nil
}

// GenerateSchema generates a JSON schema file
func GenerateSchema(cfg *config.Config, format string) error {
	if format != "json" {
		return fmt.Errorf("only JSON format is supported for schemas")
	}

	schemaFile := filepath.Join(cfg.Paths.SchemasDir, "cd-metadata-schema.json")

	schema := createJSONSchema()

	data, err := json.MarshalIndent(schema, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal schema: %w", err)
	}

	if err := os.WriteFile(schemaFile, data, 0644); err != nil {
		return fmt.Errorf("failed to write schema file: %w", err)
	}

	logrus.Infof("✅ Schema generated: %s", schemaFile)
	logrus.Infof("📋 Use 'rip-cd validate' to check metadata files against this schema")

	return nil
}

// Validate validates a metadata file against the schema
func Validate(cfg *config.Config, metadataFile string) error {
	logrus.Infof("🔍 Validating metadata file: %s", metadataFile)

	// Parse the metadata file
	metadata, err := Parse(metadataFile)
	if err != nil {
		return fmt.Errorf("validation failed: %w", err)
	}

	// Additional validation rules
	if err := validateBusinessRules(metadata); err != nil {
		return fmt.Errorf("business rule validation failed: %w", err)
	}

	logrus.Infof("✅ Metadata validation passed!")
	return nil
}

// validateMetadata performs basic validation on parsed metadata
func validateMetadata(metadata *CDMetadata) error {
	if metadata.Album.Title == "" {
		return fmt.Errorf("album title is required")
	}
	if metadata.Album.Artist == "" {
		return fmt.Errorf("album artist is required")
	}
	if len(metadata.Tracks) == 0 {
		return fmt.Errorf("at least one track is required")
	}

	for i, track := range metadata.Tracks {
		if track.Number <= 0 {
			return fmt.Errorf("track %d: invalid track number %d", i+1, track.Number)
		}
		if track.Title == "" {
			return fmt.Errorf("track %d: track title is required", track.Number)
		}
	}

	return nil
}

// validateBusinessRules performs additional business rule validation
func validateBusinessRules(metadata *CDMetadata) error {
	// Date format validation
	if metadata.Album.Date != "" {
		dateRegex := regexp.MustCompile(`^(\d{4}(-\d{2})?(-\d{2})?)?$`)
		if !dateRegex.MatchString(metadata.Album.Date) {
			return fmt.Errorf("invalid date format: %s (use YYYY, YYYY-MM, or YYYY-MM-DD)", metadata.Album.Date)
		}
	}

	// Barcode validation
	if metadata.Album.Barcode != "" {
		barcodeRegex := regexp.MustCompile(`^\d{12,14}$`)
		if !barcodeRegex.MatchString(metadata.Album.Barcode) {
			return fmt.Errorf("invalid barcode format: %s (must be 12-14 digits)", metadata.Album.Barcode)
		}
	}

	// Country code validation
	if metadata.Album.Country != "" {
		countryRegex := regexp.MustCompile(`^[A-Z]{2}$`)
		if !countryRegex.MatchString(metadata.Album.Country) {
			return fmt.Errorf("invalid country code: %s (must be 2-letter ISO 3166-1 alpha-2)", metadata.Album.Country)
		}
	}

	// Time format validation
	timeRegex := regexp.MustCompile(`^\d{1,2}:\d{2}(:\d{2})?$`)
	if metadata.Album.TotalTime != "" && !timeRegex.MatchString(metadata.Album.TotalTime) {
		return fmt.Errorf("invalid total time format: %s (use MM:SS or HH:MM:SS)", metadata.Album.TotalTime)
	}

	// Track validation
	for _, track := range metadata.Tracks {
		if track.Number < 1 || track.Number > 99 {
			return fmt.Errorf("track %d: track number must be between 1 and 99", track.Number)
		}

		if track.Length != "" && !timeRegex.MatchString(track.Length) {
			return fmt.Errorf("track %d: invalid length format: %s (use MM:SS)", track.Number, track.Length)
		}

		if track.ISRC != "" {
			isrcRegex := regexp.MustCompile(`^[A-Z]{2}[A-Z0-9]{3}\d{7}$`)
			if !isrcRegex.MatchString(track.ISRC) {
				return fmt.Errorf("track %d: invalid ISRC format: %s", track.Number, track.ISRC)
			}
		}
	}

	// Packaging validation
	if metadata.Album.Packaging != "" {
		validPackaging := []string{"Jewel Case", "Digipak", "Cardboard Sleeve", "Gatefold Cover", "Other"}
		valid := false
		for _, p := range validPackaging {
			if metadata.Album.Packaging == p {
				valid = true
				break
			}
		}
		if !valid {
			return fmt.Errorf("invalid packaging: %s (valid options: %s)", metadata.Album.Packaging, strings.Join(validPackaging, ", "))
		}
	}

	return nil
}

// createSampleMetadata creates a sample metadata structure for templates
func createSampleMetadata() *CDMetadata {
	return &CDMetadata{
		Album: Album{
			Title:          "Album Title Here",
			Artist:         "Artist Name Here",
			Date:           "2023",
			Label:          "Record Label",
			CatalogNumber:  "CAT-123",
			Barcode:        "123456789012",
			Genre:          "Genre",
			Country:        "US",
			Packaging:      "Jewel Case",
			Disambiguation: "",
			TotalTime:      "45:30",
		},
		Tracks: []Track{
			{
				Number: 1,
				Title:  "First Track Title",
				Artist: "Track Artist",
				Length: "3:45",
				ISRC:   "",
			},
			{
				Number: 2,
				Title:  "Second Track Title",
				Length: "4:20",
			},
			{
				Number: 3,
				Title:  "Third Track Title",
				Length: "2:15",
			},
		},
		Credits: &Credits{
			Producer:   "Producer Name",
			Engineer:   "Engineer Name",
			MasteredBy: "Mastering Engineer",
			RecordedAt: "Studio Name",
			MixedBy:    "Mix Engineer",
		},
		Notes: "Any additional information about this release.\nRare pressing, special edition notes, etc.",
		Ripping: &Ripping{
			Drive:    "",
			Ripper:   "XLD",
			Date:     "",
			Checksum: "",
		},
	}
}

// createJSONSchema creates a JSON schema for metadata validation
func createJSONSchema() map[string]interface{} {
	return map[string]interface{}{
		"$schema":     "http://json-schema.org/draft-07/schema#",
		"title":       "CD Metadata Schema",
		"description": "Schema for CD ripping metadata files",
		"type":        "object",
		"required":    []string{"album", "tracks"},
		"properties": map[string]interface{}{
			"album": map[string]interface{}{
				"type":     "object",
				"required": []string{"title", "artist"},
				"properties": map[string]interface{}{
					"title":          map[string]interface{}{"type": "string", "minLength": 1},
					"artist":         map[string]interface{}{"type": "string", "minLength": 1},
					"date":           map[string]interface{}{"type": "string", "pattern": "^(\\d{4}(-\\d{2})?(-\\d{2})?)?$"},
					"label":          map[string]interface{}{"type": "string"},
					"catalog_number": map[string]interface{}{"type": "string"},
					"barcode":        map[string]interface{}{"type": "string", "pattern": "^\\d{12,14}$"},
					"genre":          map[string]interface{}{"type": "string"},
					"country":        map[string]interface{}{"type": "string", "pattern": "^[A-Z]{2}$"},
					"disambiguation": map[string]interface{}{"type": "string"},
					"total_time":     map[string]interface{}{"type": "string", "pattern": "^\\d{1,2}:\\d{2}(:\\d{2})?$"},
					"packaging":      map[string]interface{}{"type": "string", "enum": []string{"Jewel Case", "Digipak", "Cardboard Sleeve", "Gatefold Cover", "Other"}},
				},
			},
			"tracks": map[string]interface{}{
				"type":     "array",
				"minItems": 1,
				"items": map[string]interface{}{
					"type":     "object",
					"required": []string{"number", "title"},
					"properties": map[string]interface{}{
						"number": map[string]interface{}{"type": "integer", "minimum": 1, "maximum": 99},
						"title":  map[string]interface{}{"type": "string", "minLength": 1},
						"artist": map[string]interface{}{"type": "string"},
						"length": map[string]interface{}{"type": "string", "pattern": "^\\d{1,2}:\\d{2}$"},
						"isrc":   map[string]interface{}{"type": "string", "pattern": "^[A-Z]{2}[A-Z0-9]{3}\\d{7}$"},
					},
				},
			},
			"credits": map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"producer":    map[string]interface{}{"oneOf": []map[string]interface{}{{"type": "string"}, {"type": "array", "items": map[string]interface{}{"type": "string"}}}},
					"engineer":    map[string]interface{}{"oneOf": []map[string]interface{}{{"type": "string"}, {"type": "array", "items": map[string]interface{}{"type": "string"}}}},
					"mastered_by": map[string]interface{}{"oneOf": []map[string]interface{}{{"type": "string"}, {"type": "array", "items": map[string]interface{}{"type": "string"}}}},
					"recorded_at": map[string]interface{}{"type": "string"},
					"mixed_by":    map[string]interface{}{"oneOf": []map[string]interface{}{{"type": "string"}, {"type": "array", "items": map[string]interface{}{"type": "string"}}}},
				},
			},
			"notes": map[string]interface{}{"type": "string"},
			"ripping": map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"drive":    map[string]interface{}{"type": "string"},
					"ripper":   map[string]interface{}{"type": "string"},
					"date":     map[string]interface{}{"type": "string"},
					"checksum": map[string]interface{}{"type": "string"},
				},
			},
		},
	}
}

// fileExists checks if a file exists
func fileExists(filename string) bool {
	_, err := os.Stat(filename)
	return err == nil
}
