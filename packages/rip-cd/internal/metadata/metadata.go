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

	// Physical media information
	Matrix        *MatrixInfo `yaml:"matrix,omitempty" json:"matrix,omitempty"`
	PressingPlant string      `yaml:"pressing_plant,omitempty" json:"pressing_plant,omitempty"`
	MediaType     string      `yaml:"media_type,omitempty" json:"media_type,omitempty"`
	Edition       string      `yaml:"edition,omitempty" json:"edition,omitempty"`

	// Enhanced metadata for archival
	ASIN          string `yaml:"asin,omitempty" json:"asin,omitempty"`
	MusicBrainzID string `yaml:"musicbrainz_id,omitempty" json:"musicbrainz_id,omitempty"`
	DiscogsID     string `yaml:"discogs_id,omitempty" json:"discogs_id,omitempty"`
}

// Track represents individual track metadata
type Track struct {
	Number int    `yaml:"number" json:"number"`
	Title  string `yaml:"title" json:"title"`
	Artist string `yaml:"artist,omitempty" json:"artist,omitempty"`
	Length string `yaml:"length,omitempty" json:"length,omitempty"`
	ISRC   string `yaml:"isrc,omitempty" json:"isrc,omitempty"`

	// Ripping quality information
	AccurateRip *AccurateRipResult `yaml:"accurate_rip,omitempty" json:"accurate_rip,omitempty"`
	Peak        float64            `yaml:"peak,omitempty" json:"peak,omitempty"`
	RMS         float64            `yaml:"rms,omitempty" json:"rms,omitempty"`
	CRC32       string             `yaml:"crc32,omitempty" json:"crc32,omitempty"`
	ReadErrors  int                `yaml:"read_errors,omitempty" json:"read_errors,omitempty"`
	SkipErrors  int                `yaml:"skip_errors,omitempty" json:"skip_errors,omitempty"`
	TestCRC     string             `yaml:"test_crc,omitempty" json:"test_crc,omitempty"`
	CopyCRC     string             `yaml:"copy_crc,omitempty" json:"copy_crc,omitempty"`
	Confidence  int                `yaml:"confidence,omitempty" json:"confidence,omitempty"`
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

	// Detailed drive information
	DriveInfo *DriveInfo `yaml:"drive_info,omitempty" json:"drive_info,omitempty"`

	// Ripping settings used
	Settings *RippingSettings `yaml:"settings,omitempty" json:"settings,omitempty"`

	// Overall ripping statistics
	Stats *RippingStats `yaml:"stats,omitempty" json:"stats,omitempty"`

	// EAC-style log
	Log string `yaml:"log,omitempty" json:"log,omitempty"`

	// Spectrogram files
	Spectrograms []string `yaml:"spectrograms,omitempty" json:"spectrograms,omitempty"`
}

// MatrixInfo represents matrix/runout information
type MatrixInfo struct {
	SideA         string   `yaml:"side_a,omitempty" json:"side_a,omitempty"`
	SideB         string   `yaml:"side_b,omitempty" json:"side_b,omitempty"`
	MouldSID      string   `yaml:"mould_sid,omitempty" json:"mould_sid,omitempty"`
	IFPICodes     []string `yaml:"ifpi_codes,omitempty" json:"ifpi_codes,omitempty"`
	MasteringCode string   `yaml:"mastering_code,omitempty" json:"mastering_code,omitempty"`
}

// DriveInfo represents detailed CD drive information
type DriveInfo struct {
	Manufacturer    string `yaml:"manufacturer,omitempty" json:"manufacturer,omitempty"`
	Model           string `yaml:"model,omitempty" json:"model,omitempty"`
	Firmware        string `yaml:"firmware,omitempty" json:"firmware,omitempty"`
	ReadOffset      int    `yaml:"read_offset,omitempty" json:"read_offset,omitempty"`
	C2Support       bool   `yaml:"c2_support,omitempty" json:"c2_support,omitempty"`
	AccurateStream  bool   `yaml:"accurate_stream,omitempty" json:"accurate_stream,omitempty"`
	OverreadLeadIn  int    `yaml:"overread_lead_in,omitempty" json:"overread_lead_in,omitempty"`
	OverreadLeadOut int    `yaml:"overread_lead_out,omitempty" json:"overread_lead_out,omitempty"`
	CacheSize       int    `yaml:"cache_size,omitempty" json:"cache_size,omitempty"`
}

// RippingSettings represents the settings used for ripping
type RippingSettings struct {
	SecureMode        bool `yaml:"secure_mode,omitempty" json:"secure_mode,omitempty"`
	C2ErrorCorrection bool `yaml:"c2_error_correction,omitempty" json:"c2_error_correction,omitempty"`
	TestAndCopy       bool `yaml:"test_and_copy,omitempty" json:"test_and_copy,omitempty"`
	AccurateRip       bool `yaml:"accurate_rip,omitempty" json:"accurate_rip,omitempty"`
	MaxRetries        int  `yaml:"max_retries,omitempty" json:"max_retries,omitempty"`
	CompressionLevel  int  `yaml:"compression_level,omitempty" json:"compression_level,omitempty"`
}

// RippingStats represents overall ripping statistics
type RippingStats struct {
	TotalTime          string  `yaml:"total_time,omitempty" json:"total_time,omitempty"`
	TotalTracks        int     `yaml:"total_tracks,omitempty" json:"total_tracks,omitempty"`
	TracksWithErrors   int     `yaml:"tracks_with_errors,omitempty" json:"tracks_with_errors,omitempty"`
	TotalErrors        int     `yaml:"total_errors,omitempty" json:"total_errors,omitempty"`
	AccurateRipMatches int     `yaml:"accurate_rip_matches,omitempty" json:"accurate_rip_matches,omitempty"`
	PeakLevel          float64 `yaml:"peak_level,omitempty" json:"peak_level,omitempty"`
	RMSLevel           float64 `yaml:"rms_level,omitempty" json:"rms_level,omitempty"`
}

// AccurateRipResult represents AccurateRip verification result
type AccurateRipResult struct {
	Confidence   int    `yaml:"confidence,omitempty" json:"confidence,omitempty"`
	CRC          string `yaml:"crc,omitempty" json:"crc,omitempty"`
	Matched      bool   `yaml:"matched,omitempty" json:"matched,omitempty"`
	DatabaseHits int    `yaml:"database_hits,omitempty" json:"database_hits,omitempty"`
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
func GenerateTemplate(cfg *config.Config, format string, overwrite bool) error {
	if format != "yaml" {
		return fmt.Errorf("only YAML format is supported for templates")
	}

	// Auto-generate schema for IDE support
	if err := GenerateSchema(cfg, "json", overwrite); err != nil {
		logrus.Warnf("Failed to auto-generate schema: %v", err)
		// Continue with template generation even if schema fails
	}

	templateFile := filepath.Join(cfg.Paths.MetadataDir, "template.yaml")

	// Check if file already exists
	if fileExists(templateFile) && !overwrite {
		return fmt.Errorf("template file already exists: %s (use --overwrite to replace)", templateFile)
	}

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
func GenerateSchema(cfg *config.Config, format string, overwrite bool) error {
	if format != "json" {
		return fmt.Errorf("only JSON format is supported for schemas")
	}

	schemaFile := filepath.Join(cfg.Paths.SchemasDir, "cd-metadata-schema.json")

	// Check if file already exists
	if fileExists(schemaFile) && !overwrite {
		return fmt.Errorf("schema file already exists: %s (use --overwrite to replace)", schemaFile)
	}

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
			MediaType:      "CD",
			Edition:        "First Press",
			PressingPlant:  "Pressing Plant Name",
			ASIN:           "B000ABCDEF",
			MusicBrainzID:  "12345678-1234-1234-1234-123456789012",
			DiscogsID:      "123456",
			Matrix: &MatrixInfo{
				SideA:         "MATRIX-A1",
				SideB:         "MATRIX-B1",
				MouldSID:      "IFPI L123",
				IFPICodes:     []string{"IFPI 1234", "IFPI 5678"},
				MasteringCode: "STERLING",
			},
		},
		Tracks: []Track{
			{
				Number: 1,
				Title:  "First Track Title",
				Artist: "Track Artist",
				Length: "3:45",
				ISRC:   "USRC11234567",
				AccurateRip: &AccurateRipResult{
					Confidence:   2,
					CRC:          "ABCD1234",
					Matched:      true,
					DatabaseHits: 15,
				},
				Peak:       0.95,
				RMS:        0.12,
				CRC32:      "12345678",
				ReadErrors: 0,
				SkipErrors: 0,
				TestCRC:    "ABCD1234",
				CopyCRC:    "ABCD1234",
				Confidence: 2,
			},
			{
				Number: 2,
				Title:  "Second Track Title",
				Length: "4:20",
				Peak:   0.89,
				RMS:    0.15,
				CRC32:  "87654321",
			},
			{
				Number: 3,
				Title:  "Third Track Title",
				Length: "2:15",
				Peak:   0.92,
				RMS:    0.18,
				CRC32:  "ABCDEF12",
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
			DriveInfo: &DriveInfo{
				Manufacturer:    "PLEXTOR",
				Model:           "PX-W5224A",
				Firmware:        "1.04",
				ReadOffset:      30,
				C2Support:       true,
				AccurateStream:  true,
				OverreadLeadIn:  588,
				OverreadLeadOut: 1176,
				CacheSize:       1411,
			},
			Settings: &RippingSettings{
				SecureMode:        true,
				C2ErrorCorrection: true,
				TestAndCopy:       true,
				AccurateRip:       true,
				MaxRetries:        20,
				CompressionLevel:  8,
			},
			Stats: &RippingStats{
				TotalTime:          "45:30",
				TotalTracks:        3,
				TracksWithErrors:   0,
				TotalErrors:        0,
				AccurateRipMatches: 3,
				PeakLevel:          0.95,
				RMSLevel:           0.15,
			},
			Log:          "Detailed EAC-style log would appear here...",
			Spectrograms: []string{"spectrograms/track01.png", "spectrograms/track02.png"},
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
					"pressing_plant": map[string]interface{}{"type": "string"},
					"media_type":     map[string]interface{}{"type": "string"},
					"edition":        map[string]interface{}{"type": "string"},
					"asin":           map[string]interface{}{"type": "string"},
					"musicbrainz_id": map[string]interface{}{"type": "string"},
					"discogs_id":     map[string]interface{}{"type": "string"},
					"matrix": map[string]interface{}{
						"type": "object",
						"properties": map[string]interface{}{
							"side_a":         map[string]interface{}{"type": "string"},
							"side_b":         map[string]interface{}{"type": "string"},
							"mould_sid":      map[string]interface{}{"type": "string"},
							"mastering_code": map[string]interface{}{"type": "string"},
							"ifpi_codes":     map[string]interface{}{"type": "array", "items": map[string]interface{}{"type": "string"}},
						},
					},
				},
			},
			"tracks": map[string]interface{}{
				"type":     "array",
				"minItems": 1,
				"items": map[string]interface{}{
					"type":     "object",
					"required": []string{"number", "title"},
					"properties": map[string]interface{}{
						"number":      map[string]interface{}{"type": "integer", "minimum": 1, "maximum": 99},
						"title":       map[string]interface{}{"type": "string", "minLength": 1},
						"artist":      map[string]interface{}{"type": "string"},
						"length":      map[string]interface{}{"type": "string", "pattern": "^\\d{1,2}:\\d{2}$"},
						"isrc":        map[string]interface{}{"type": "string", "pattern": "^[A-Z]{2}[A-Z0-9]{3}\\d{7}$"},
						"peak":        map[string]interface{}{"type": "number", "minimum": 0, "maximum": 1},
						"rms":         map[string]interface{}{"type": "number", "minimum": 0, "maximum": 1},
						"crc32":       map[string]interface{}{"type": "string"},
						"read_errors": map[string]interface{}{"type": "integer", "minimum": 0},
						"skip_errors": map[string]interface{}{"type": "integer", "minimum": 0},
						"test_crc":    map[string]interface{}{"type": "string"},
						"copy_crc":    map[string]interface{}{"type": "string"},
						"confidence":  map[string]interface{}{"type": "integer", "minimum": 0},
						"accurate_rip": map[string]interface{}{
							"type": "object",
							"properties": map[string]interface{}{
								"confidence":    map[string]interface{}{"type": "integer", "minimum": 0},
								"crc":           map[string]interface{}{"type": "string"},
								"matched":       map[string]interface{}{"type": "boolean"},
								"database_hits": map[string]interface{}{"type": "integer", "minimum": 0},
							},
						},
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
					"drive":        map[string]interface{}{"type": "string"},
					"ripper":       map[string]interface{}{"type": "string"},
					"date":         map[string]interface{}{"type": "string"},
					"checksum":     map[string]interface{}{"type": "string"},
					"log":          map[string]interface{}{"type": "string"},
					"spectrograms": map[string]interface{}{"type": "array", "items": map[string]interface{}{"type": "string"}},
					"drive_info": map[string]interface{}{
						"type": "object",
						"properties": map[string]interface{}{
							"manufacturer":      map[string]interface{}{"type": "string"},
							"model":             map[string]interface{}{"type": "string"},
							"firmware":          map[string]interface{}{"type": "string"},
							"read_offset":       map[string]interface{}{"type": "integer"},
							"c2_support":        map[string]interface{}{"type": "boolean"},
							"accurate_stream":   map[string]interface{}{"type": "boolean"},
							"overread_lead_in":  map[string]interface{}{"type": "integer"},
							"overread_lead_out": map[string]interface{}{"type": "integer"},
							"cache_size":        map[string]interface{}{"type": "integer"},
						},
					},
					"settings": map[string]interface{}{
						"type": "object",
						"properties": map[string]interface{}{
							"secure_mode":         map[string]interface{}{"type": "boolean"},
							"c2_error_correction": map[string]interface{}{"type": "boolean"},
							"test_and_copy":       map[string]interface{}{"type": "boolean"},
							"accurate_rip":        map[string]interface{}{"type": "boolean"},
							"max_retries":         map[string]interface{}{"type": "integer"},
							"compression_level":   map[string]interface{}{"type": "integer"},
						},
					},
					"stats": map[string]interface{}{
						"type": "object",
						"properties": map[string]interface{}{
							"total_time":           map[string]interface{}{"type": "string"},
							"total_tracks":         map[string]interface{}{"type": "integer"},
							"tracks_with_errors":   map[string]interface{}{"type": "integer"},
							"total_errors":         map[string]interface{}{"type": "integer"},
							"accurate_rip_matches": map[string]interface{}{"type": "integer"},
							"peak_level":           map[string]interface{}{"type": "number"},
							"rms_level":            map[string]interface{}{"type": "number"},
						},
					},
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
