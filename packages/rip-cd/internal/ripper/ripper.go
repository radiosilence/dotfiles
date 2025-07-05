package ripper

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"github.com/radiosilence/dotfiles/packages/rip-cd/internal/config"
	"github.com/radiosilence/dotfiles/packages/rip-cd/internal/metadata"
	"github.com/sirupsen/logrus"
	"gopkg.in/yaml.v3"
)

// RipResult represents the result of a ripping operation
type RipResult struct {
	OutputDir  string
	Files      []string
	Duration   time.Duration
	Checksum   string
	DriveUsed  string
	Success    bool
	ErrorCount int
}

// Rip performs the actual CD ripping operation
func Rip(cfg *config.Config, meta *metadata.CDMetadata) error {
	logrus.Info("🎵 Starting CD ripping process...")

	// Validate prerequisites
	if err := validatePrerequisites(cfg); err != nil {
		return fmt.Errorf("prerequisite check failed: %w", err)
	}

	// Setup output directory
	outputDir, err := setupOutputDirectory(cfg, meta)
	if err != nil {
		return fmt.Errorf("failed to setup output directory: %w", err)
	}

	// Detect CD drive
	drive, err := detectDrive(cfg)
	if err != nil {
		return fmt.Errorf("failed to detect CD drive: %w", err)
	}

	logrus.Infof("📀 Using CD drive: %s", drive)
	logrus.Infof("📁 Output directory: %s", outputDir)

	// Build XLD command
	cmd, err := buildXLDCommand(cfg, meta, drive, outputDir)
	if err != nil {
		return fmt.Errorf("failed to build XLD command: %w", err)
	}

	// Execute ripping
	result, err := executeRip(cmd, outputDir)
	if err != nil {
		return fmt.Errorf("ripping failed: %w", err)
	}

	// Update metadata with ripping information
	meta.Ripping = &metadata.Ripping{
		Drive:    result.DriveUsed,
		Ripper:   "XLD",
		Date:     time.Now().Format("2006-01-02 15:04:05"),
		Checksum: result.Checksum,
	}

	// Save updated metadata
	if err := saveMetadata(cfg, meta, outputDir); err != nil {
		logrus.Warnf("Failed to save updated metadata: %v", err)
	}

	// Post-processing
	if cfg.Integrations.Beets.Enabled && cfg.Integrations.Beets.AutoImport {
		if err := runBeetsImport(cfg, outputDir); err != nil {
			logrus.Warnf("Beets import failed: %v", err)
		}
	}

	logrus.Infof("✅ Ripping completed successfully!")
	logrus.Infof("📊 Files created: %d", len(result.Files))
	logrus.Infof("⏱️  Duration: %v", result.Duration)

	return nil
}

// DryRun simulates the ripping process without actually doing it
func DryRun(cfg *config.Config, meta *metadata.CDMetadata) error {
	logrus.Info("🎯 Dry run mode - showing what would be done")

	// Validate prerequisites
	if err := validatePrerequisites(cfg); err != nil {
		logrus.Warnf("⚠️  Prerequisite check would fail: %v", err)
	}

	// Show output directory
	outputDir, err := setupOutputDirectory(cfg, meta)
	if err != nil {
		logrus.Warnf("⚠️  Output directory setup would fail: %v", err)
	} else {
		logrus.Infof("📁 Would create output directory: %s", outputDir)
	}

	// Show drive detection
	drive, err := detectDrive(cfg)
	if err != nil {
		logrus.Warnf("⚠️  Drive detection would fail: %v", err)
	} else {
		logrus.Infof("📀 Would use CD drive: %s", drive)
	}

	// Show XLD command
	cmd, err := buildXLDCommand(cfg, meta, drive, outputDir)
	if err != nil {
		logrus.Warnf("⚠️  XLD command build would fail: %v", err)
	} else {
		logrus.Infof("🔧 Would execute XLD command:")
		logrus.Infof("   %s", strings.Join(cmd.Args, " "))
	}

	// Show files that would be created
	files := generateExpectedFiles(meta, outputDir)
	logrus.Infof("📄 Would create %d files:", len(files))
	for _, file := range files {
		logrus.Infof("   %s", file)
	}

	// Show post-processing
	if cfg.Integrations.Beets.Enabled && cfg.Integrations.Beets.AutoImport {
		logrus.Infof("🎶 Would run beets import on: %s", outputDir)
	}

	logrus.Info("✅ Dry run completed - no actual changes made")
	return nil
}

// validatePrerequisites checks that all required tools are available
func validatePrerequisites(cfg *config.Config) error {
	// Check XLD
	xldPath := cfg.Ripper.XLD.ExecutablePath
	if xldPath == "" {
		xldPath = "xld"
	}

	if _, err := exec.LookPath(xldPath); err != nil {
		return fmt.Errorf("XLD not found: %w", err)
	}

	// Check beets if enabled
	if cfg.Integrations.Beets.Enabled {
		beetsPath := cfg.Integrations.Beets.ExecutablePath
		if beetsPath == "" {
			beetsPath = "beet"
		}

		if _, err := exec.LookPath(beetsPath); err != nil {
			logrus.Warnf("Beets not found, disabling beets integration: %v", err)
			cfg.Integrations.Beets.Enabled = false
		}
	}

	return nil
}

// setupOutputDirectory creates the output directory structure
func setupOutputDirectory(cfg *config.Config, meta *metadata.CDMetadata) (string, error) {
	// Generate directory name from template
	dirName := generateDirName(cfg.Output.DirTemplate, meta)
	outputDir := filepath.Join(cfg.Paths.OutputDir, dirName)

	// Create directory
	if err := os.MkdirAll(outputDir, 0755); err != nil {
		return "", fmt.Errorf("failed to create output directory: %w", err)
	}

	return outputDir, nil
}

// detectDrive detects available CD drives
func detectDrive(cfg *config.Config) (string, error) {
	// On macOS, XLD can auto-detect drives, so we return empty string
	// which tells XLD to use the default drive
	return "", nil
}

// buildXLDCommand constructs the XLD command line
func buildXLDCommand(cfg *config.Config, meta *metadata.CDMetadata, drive, outputDir string) (*exec.Cmd, error) {
	xldPath := cfg.Ripper.XLD.ExecutablePath
	if xldPath == "" {
		xldPath = "xld"
	}

	args := []string{
		"-c", cfg.Ripper.XLD.Profile,
		"-o", outputDir,
	}

	// Add format-specific arguments
	switch cfg.Ripper.Quality.Format {
	case "flac":
		args = append(args, "-f", "flac")
		if cfg.Ripper.Quality.Compression > 0 {
			args = append(args, fmt.Sprintf("--flac-compression=%d", cfg.Ripper.Quality.Compression))
		}
	case "mp3":
		args = append(args, "-f", "mp3")
	default:
		args = append(args, "-f", "flac")
	}

	// Add verification if enabled
	if cfg.Ripper.Quality.Verify {
		args = append(args, "--verify")
	}

	// Add error correction
	if cfg.Ripper.Quality.ErrorCorrection > 0 {
		args = append(args, fmt.Sprintf("--error-correction=%d", cfg.Ripper.Quality.ErrorCorrection))
	}

	// Add extra args
	args = append(args, cfg.Ripper.XLD.ExtraArgs...)

	// Add drive specification if not empty
	if drive != "" {
		args = append(args, "-d", drive)
	}

	return exec.Command(xldPath, args...), nil
}

// executeRip runs the actual ripping command
func executeRip(cmd *exec.Cmd, outputDir string) (*RipResult, error) {
	startTime := time.Now()

	logrus.Infof("🎵 Executing: %s", strings.Join(cmd.Args, " "))

	// Set up command output
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	// Execute command
	err := cmd.Run()
	duration := time.Since(startTime)

	result := &RipResult{
		OutputDir: outputDir,
		Duration:  duration,
		DriveUsed: "", // XLD doesn't report which drive was used
		Success:   err == nil,
	}

	if err != nil {
		return result, fmt.Errorf("XLD execution failed: %w", err)
	}

	// Find created files
	files, err := findCreatedFiles(outputDir)
	if err != nil {
		logrus.Warnf("Failed to enumerate created files: %v", err)
	} else {
		result.Files = files
	}

	return result, nil
}

// findCreatedFiles finds all audio files in the output directory
func findCreatedFiles(outputDir string) ([]string, error) {
	var files []string

	err := filepath.Walk(outputDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if !info.IsDir() {
			ext := strings.ToLower(filepath.Ext(path))
			if ext == ".flac" || ext == ".mp3" || ext == ".wav" || ext == ".m4a" {
				files = append(files, path)
			}
		}

		return nil
	})

	return files, err
}

// generateExpectedFiles generates a list of files that would be created
func generateExpectedFiles(meta *metadata.CDMetadata, outputDir string) []string {
	var files []string

	for _, track := range meta.Tracks {
		filename := generateFilename(track, meta)
		files = append(files, filepath.Join(outputDir, filename))
	}

	return files
}

// generateDirName generates directory name from template
func generateDirName(template string, meta *metadata.CDMetadata) string {
	name := template
	name = strings.ReplaceAll(name, "{{.Artist}}", meta.Album.Artist)
	name = strings.ReplaceAll(name, "{{.Album}}", meta.Album.Title)
	name = strings.ReplaceAll(name, "{{.Year}}", extractYear(meta.Album.Date))
	name = strings.ReplaceAll(name, "{{.Date}}", meta.Album.Date)
	name = strings.ReplaceAll(name, "{{.Label}}", meta.Album.Label)

	return sanitizeFilename(name)
}

// generateFilename generates filename from template
func generateFilename(track metadata.Track, meta *metadata.CDMetadata) string {
	// Simple filename generation - can be made more sophisticated
	return fmt.Sprintf("%02d - %s.flac", track.Number, sanitizeFilename(track.Title))
}

// sanitizeFilename removes invalid characters from filenames
func sanitizeFilename(name string) string {
	// Remove or replace invalid characters
	invalid := regexp.MustCompile(`[<>:"/\\|?*]`)
	name = invalid.ReplaceAllString(name, "_")

	// Remove leading/trailing spaces
	name = strings.TrimSpace(name)

	// Replace multiple spaces with single space
	multiSpace := regexp.MustCompile(`\s+`)
	name = multiSpace.ReplaceAllString(name, " ")

	return name
}

// extractYear extracts year from date string
func extractYear(date string) string {
	if len(date) >= 4 {
		return date[:4]
	}
	return date
}

// saveMetadata saves the updated metadata to the output directory
func saveMetadata(cfg *config.Config, meta *metadata.CDMetadata, outputDir string) error {
	metadataFile := filepath.Join(outputDir, "metadata.yaml")

	file, err := os.Create(metadataFile)
	if err != nil {
		return err
	}
	defer file.Close()

	encoder := yaml.NewEncoder(file)
	encoder.SetIndent(2)
	return encoder.Encode(meta)
}

// runBeetsImport runs beets import on the output directory
func runBeetsImport(cfg *config.Config, outputDir string) error {
	beetsPath := cfg.Integrations.Beets.ExecutablePath
	if beetsPath == "" {
		beetsPath = "beet"
	}

	args := []string{"import", outputDir}

	if cfg.Integrations.Beets.ConfigPath != "" {
		args = append([]string{"-c", cfg.Integrations.Beets.ConfigPath}, args...)
	}

	cmd := exec.Command(beetsPath, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	logrus.Infof("🎶 Running beets import: %s", strings.Join(cmd.Args, " "))
	return cmd.Run()
}
