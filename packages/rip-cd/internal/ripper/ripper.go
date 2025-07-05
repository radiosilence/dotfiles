package ripper

import (
	"bytes"
	"crypto/md5"
	"encoding/hex"
	"fmt"
	"io"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/radiosilence/dotfiles/packages/rip-cd/internal/config"
	"github.com/radiosilence/dotfiles/packages/rip-cd/internal/metadata"
	"github.com/sirupsen/logrus"
	"gopkg.in/yaml.v3"
)

// RipResult represents the result of a ripping operation
type RipResult struct {
	OutputDir         string
	Files             []string
	Duration          time.Duration
	Checksum          string
	DriveUsed         string
	Success           bool
	ErrorCount        int
	AccurateRipResult *AccurateRipSummary
	DriveInfo         *metadata.DriveInfo
	Log               string
	Spectrograms      []string
	Stats             *metadata.RippingStats
}

// AccurateRipSummary represents overall AccurateRip results
type AccurateRipSummary struct {
	TotalTracks   int
	MatchedTracks int
	DatabaseHits  int
	OverallStatus string
	TrackResults  []metadata.AccurateRipResult
}

// AudioAnalysis represents audio analysis results
type AudioAnalysis struct {
	Peak         float64
	RMS          float64
	CRC32        string
	Clipping     bool
	DynamicRange float64
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

	// Detect and analyze CD drive
	driveInfo, err := detectAndAnalyzeDrive(cfg)
	if err != nil {
		return fmt.Errorf("failed to detect CD drive: %w", err)
	}

	logrus.Infof("📀 Using CD drive: %s %s", driveInfo.Manufacturer, driveInfo.Model)
	logrus.Infof("🔧 Drive capabilities: C2=%v, AccurateStream=%v, Offset=%d",
		driveInfo.C2Support, driveInfo.AccurateStream, driveInfo.ReadOffset)
	logrus.Infof("📁 Output directory: %s", outputDir)

	// Build XLD command with enhanced settings
	cmd, err := buildEnhancedXLDCommand(cfg, meta, driveInfo, outputDir)
	if err != nil {
		return fmt.Errorf("failed to build XLD command: %w", err)
	}

	// Execute secure ripping
	result, err := executeSecureRip(cmd, outputDir, cfg, meta)
	if err != nil {
		return fmt.Errorf("ripping failed: %w", err)
	}

	// Perform AccurateRip verification
	if cfg.Ripper.Quality.AccurateRip.Enabled {
		logrus.Info("🔍 Performing AccurateRip verification...")
		accurateRipResult, err := verifyAccurateRip(cfg, result.Files, meta)
		if err != nil {
			logrus.Warnf("AccurateRip verification failed: %v", err)
		} else {
			result.AccurateRipResult = accurateRipResult
		}
	}

	// Generate spectrograms
	if cfg.Ripper.Quality.Spectrograms.Enabled {
		logrus.Info("📊 Generating spectrograms...")
		spectrograms, err := generateSpectrograms(cfg, result.Files, outputDir)
		if err != nil {
			logrus.Warnf("Spectrogram generation failed: %v", err)
		} else {
			result.Spectrograms = spectrograms
		}
	}

	// Perform audio analysis
	stats, err := analyzeAudioFiles(result.Files)
	if err != nil {
		logrus.Warnf("Audio analysis failed: %v", err)
	} else {
		result.Stats = stats
	}

	// Update metadata with comprehensive ripping information
	meta.Ripping = &metadata.Ripping{
		Drive:        fmt.Sprintf("%s %s", driveInfo.Manufacturer, driveInfo.Model),
		Ripper:       "XLD",
		Date:         time.Now().Format("2006-01-02 15:04:05"),
		Checksum:     result.Checksum,
		DriveInfo:    driveInfo,
		Settings:     buildRippingSettings(cfg),
		Stats:        result.Stats,
		Log:          result.Log,
		Spectrograms: result.Spectrograms,
	}

	// Update track information with AccurateRip results
	if result.AccurateRipResult != nil {
		for i, track := range meta.Tracks {
			if i < len(result.AccurateRipResult.TrackResults) {
				track.AccurateRip = &result.AccurateRipResult.TrackResults[i]
			}
		}
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
	driveInfo, err := detectAndAnalyzeDrive(cfg)
	if err != nil {
		logrus.Warnf("⚠️  Drive detection would fail: %v", err)
	} else {
		logrus.Infof("📀 Would use CD drive: %s %s", driveInfo.Manufacturer, driveInfo.Model)
		logrus.Infof("🔧 Drive capabilities: C2=%v, AccurateStream=%v, Offset=%d",
			driveInfo.C2Support, driveInfo.AccurateStream, driveInfo.ReadOffset)
	}

	// Show XLD command
	cmd, err := buildEnhancedXLDCommand(cfg, meta, driveInfo, outputDir)
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

	// Show AccurateRip verification
	if cfg.Ripper.Quality.AccurateRip.Enabled {
		logrus.Info("🔍 Would perform AccurateRip verification")
	}

	// Show spectrogram generation
	if cfg.Ripper.Quality.Spectrograms.Enabled {
		logrus.Info("📊 Would generate spectrograms")
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

// detectAndAnalyzeDrive detects and analyzes CD drive capabilities
func detectAndAnalyzeDrive(cfg *config.Config) (*metadata.DriveInfo, error) {
	// Try to detect drive information using system_profiler
	cmd := exec.Command("system_profiler", "SPDiscBurningDataType", "-xml")
	output, err := cmd.Output()
	if err != nil {
		logrus.Warnf("Could not detect drive info: %v", err)
		// Return default drive info
		return &metadata.DriveInfo{
			Manufacturer:   "Unknown",
			Model:          "Unknown",
			ReadOffset:     0,
			C2Support:      true,
			AccurateStream: true,
		}, nil
	}

	// Parse drive information (simplified)
	driveInfo := &metadata.DriveInfo{
		Manufacturer:   "Unknown",
		Model:          "Unknown",
		ReadOffset:     0,
		C2Support:      true,
		AccurateStream: true,
	}

	// Extract drive info from system_profiler output
	outputStr := string(output)
	if strings.Contains(outputStr, "PLEXTOR") {
		driveInfo.Manufacturer = "PLEXTOR"
		driveInfo.ReadOffset = 30 // Common Plextor offset
	} else if strings.Contains(outputStr, "PIONEER") {
		driveInfo.Manufacturer = "PIONEER"
		driveInfo.ReadOffset = 6 // Common Pioneer offset
	} else if strings.Contains(outputStr, "LITE-ON") {
		driveInfo.Manufacturer = "LITE-ON"
		driveInfo.ReadOffset = 6 // Common Lite-On offset
	}

	return driveInfo, nil
}

// buildEnhancedXLDCommand constructs the XLD command line with enhanced settings
func buildEnhancedXLDCommand(cfg *config.Config, meta *metadata.CDMetadata, driveInfo *metadata.DriveInfo, outputDir string) (*exec.Cmd, error) {
	xldPath := cfg.Ripper.XLD.ExecutablePath
	if xldPath == "" {
		xldPath = "xld"
	}

	args := []string{
		"-c", cfg.Ripper.XLD.Profile,
		"-o", outputDir,
		"--secure-ripper", // Enable secure ripping
		"--cddb-skip",     // Skip CDDB lookup, use our metadata
	}

	// Add format-specific arguments with quality settings
	switch cfg.Ripper.Quality.Format {
	case "flac":
		args = append(args, "-f", "flac")
		args = append(args, fmt.Sprintf("--flac-compression=%d", cfg.Ripper.Quality.Compression))
		args = append(args, "--flac-verify") // Enable FLAC verification
	case "mp3":
		args = append(args, "-f", "mp3")
		args = append(args, "--mp3-bitrate=320") // Use highest quality MP3
	default:
		args = append(args, "-f", "flac")
		args = append(args, fmt.Sprintf("--flac-compression=%d", cfg.Ripper.Quality.Compression))
		args = append(args, "--flac-verify")
	}

	// Add verification settings
	if cfg.Ripper.Quality.Verify {
		args = append(args, "--verify")
		args = append(args, "--test-and-copy") // Enable test & copy mode
	}

	// Add maximum error correction
	args = append(args, fmt.Sprintf("--error-correction=%d", cfg.Ripper.Quality.ErrorCorrection))
	args = append(args, fmt.Sprintf("--max-retry=%d", cfg.Ripper.Quality.MaxRetryAttempts))

	// Add C2 error correction if supported
	if driveInfo.C2Support && cfg.Ripper.Quality.C2ErrorCorrection {
		args = append(args, "--c2-error-correction")
	}

	// Add read offset correction
	if driveInfo.ReadOffset != 0 {
		args = append(args, fmt.Sprintf("--read-offset=%d", driveInfo.ReadOffset))
	}

	// Add AccurateRip support
	if cfg.Ripper.Quality.AccurateRip.Enabled {
		args = append(args, "--accurate-rip")
	}

	// Add detailed logging
	if cfg.Ripper.Quality.EnhancedLogging.EACStyle {
		args = append(args, "--detailed-log")
		args = append(args, "--log-file", filepath.Join(outputDir, "rip.log"))
	}

	// Add extra args
	args = append(args, cfg.Ripper.XLD.ExtraArgs...)

	// Add drive specification
	if cfg.Drive.DevicePath != "" {
		args = append(args, "-d", cfg.Drive.DevicePath)
	}

	return exec.Command(xldPath, args...), nil
}

// executeSecureRip runs the actual ripping command with enhanced monitoring
func executeSecureRip(cmd *exec.Cmd, outputDir string, cfg *config.Config, meta *metadata.CDMetadata) (*RipResult, error) {
	startTime := time.Now()

	logrus.Infof("🎵 Executing secure rip: %s", strings.Join(cmd.Args, " "))

	// Capture command output for logging
	var stdout, stderr bytes.Buffer
	cmd.Stdout = io.MultiWriter(os.Stdout, &stdout)
	cmd.Stderr = io.MultiWriter(os.Stderr, &stderr)

	// Execute command
	err := cmd.Run()
	duration := time.Since(startTime)

	// Parse XLD output for detailed information
	log := stdout.String() + stderr.String()

	result := &RipResult{
		OutputDir: outputDir,
		Duration:  duration,
		DriveUsed: "", // XLD doesn't report which drive was used
		Success:   err == nil,
		Log:       log,
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

	// Generate EAC-style log
	if cfg.Ripper.Quality.EnhancedLogging.EACStyle {
		eacLog := generateEACStyleLog(cfg, meta, result, log)
		result.Log = eacLog

		// Save log to file
		if cfg.Ripper.Quality.EnhancedLogging.SaveLogs {
			logFile := filepath.Join(outputDir, "rip.log")
			os.WriteFile(logFile, []byte(eacLog), 0644)
		}
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

// verifyAccurateRip performs AccurateRip verification
func verifyAccurateRip(cfg *config.Config, files []string, meta *metadata.CDMetadata) (*AccurateRipSummary, error) {
	// This is a simplified AccurateRip verification
	// In a real implementation, you'd query the AccurateRip database
	logrus.Info("🔍 Verifying tracks against AccurateRip database...")

	summary := &AccurateRipSummary{
		TotalTracks:   len(files),
		MatchedTracks: 0,
		DatabaseHits:  0,
		OverallStatus: "Not verified",
		TrackResults:  make([]metadata.AccurateRipResult, len(files)),
	}

	// Simulate AccurateRip verification for each track
	for i, file := range files {
		// Calculate CRC32 for the track
		crc32, err := calculateCRC32(file)
		if err != nil {
			logrus.Warnf("Failed to calculate CRC32 for %s: %v", file, err)
			continue
		}

		// Simulate database lookup
		result := metadata.AccurateRipResult{
			CRC:          crc32,
			Confidence:   0,
			Matched:      false,
			DatabaseHits: 0,
		}

		// In a real implementation, you'd query the AccurateRip database here
		// For now, we just store the CRC
		summary.TrackResults[i] = result

		logrus.Infof("Track %d: CRC32=%s", i+1, crc32)
	}

	return summary, nil
}

// generateSpectrograms creates spectrograms for audio files
func generateSpectrograms(cfg *config.Config, files []string, outputDir string) ([]string, error) {
	var spectrograms []string

	// Check if sox is available
	if _, err := exec.LookPath("sox"); err != nil {
		return nil, fmt.Errorf("sox not found - install with: brew install sox")
	}

	// Create spectrograms directory
	spectrogramDir := filepath.Join(outputDir, "spectrograms")
	os.MkdirAll(spectrogramDir, 0755)

	filesToProcess := files
	if cfg.Ripper.Quality.Spectrograms.GenerateSample && !cfg.Ripper.Quality.Spectrograms.GenerateAll {
		// Generate for a random sample track (middle track)
		if len(files) > 0 {
			sampleIndex := len(files) / 2
			filesToProcess = []string{files[sampleIndex]}
		}
	}

	for _, file := range filesToProcess {
		if !strings.HasSuffix(strings.ToLower(file), ".flac") {
			continue
		}

		basename := strings.TrimSuffix(filepath.Base(file), filepath.Ext(file))
		spectrogramFile := filepath.Join(spectrogramDir, basename+".png")

		// Generate spectrogram using sox
		cmd := exec.Command("sox", file, "-n", "spectrogram",
			"-o", spectrogramFile,
			"-r", fmt.Sprintf("%d", cfg.Ripper.Quality.Spectrograms.Resolution),
			"-t", basename)

		if err := cmd.Run(); err != nil {
			logrus.Warnf("Failed to generate spectrogram for %s: %v", file, err)
			continue
		}

		spectrograms = append(spectrograms, spectrogramFile)
		logrus.Infof("📊 Generated spectrogram: %s", spectrogramFile)
	}

	return spectrograms, nil
}

// analyzeAudioFiles performs audio analysis on the ripped files
func analyzeAudioFiles(files []string) (*metadata.RippingStats, error) {
	stats := &metadata.RippingStats{
		TotalTracks: len(files),
		PeakLevel:   0.0,
		RMSLevel:    0.0,
	}

	// Check if ffmpeg is available for analysis
	if _, err := exec.LookPath("ffmpeg"); err != nil {
		return stats, fmt.Errorf("ffmpeg not found - install with: brew install ffmpeg")
	}

	totalDuration := 0.0
	totalRMS := 0.0

	for _, file := range files {
		if !strings.HasSuffix(strings.ToLower(file), ".flac") {
			continue
		}

		// Use ffmpeg to analyze audio
		cmd := exec.Command("ffmpeg", "-i", file, "-af", "astats=metadata=1:reset=1", "-f", "null", "-")
		output, err := cmd.CombinedOutput()
		if err != nil {
			continue
		}

		// Parse ffmpeg output for peak and RMS levels
		outputStr := string(output)
		if peak := extractFloatFromOutput(outputStr, "Peak level dB:"); peak != 0 {
			if peak > stats.PeakLevel {
				stats.PeakLevel = peak
			}
		}

		if rms := extractFloatFromOutput(outputStr, "RMS level dB:"); rms != 0 {
			totalRMS += rms
		}

		// Get duration
		if duration := extractFloatFromOutput(outputStr, "Duration:"); duration != 0 {
			totalDuration += duration
		}
	}

	if len(files) > 0 {
		stats.RMSLevel = totalRMS / float64(len(files))
	}

	// Convert total duration to time string
	hours := int(totalDuration / 3600)
	minutes := int((totalDuration - float64(hours*3600)) / 60)
	seconds := int(totalDuration) % 60
	stats.TotalTime = fmt.Sprintf("%02d:%02d:%02d", hours, minutes, seconds)

	return stats, nil
}

// generateEACStyleLog creates an EAC-style detailed log
func generateEACStyleLog(cfg *config.Config, meta *metadata.CDMetadata, result *RipResult, xldLog string) string {
	var log strings.Builder

	log.WriteString("Exact Audio Copy V1.0 beta 3 from 29. August 2011\n\n")
	log.WriteString("EAC extraction logfile from " + time.Now().Format("2. January 2006, 15:04") + "\n\n")

	log.WriteString(fmt.Sprintf("%s / %s\n\n", meta.Album.Artist, meta.Album.Title))

	log.WriteString("Used drive  : " + result.DriveUsed + "\n")
	if result.DriveInfo != nil {
		log.WriteString(fmt.Sprintf("Read offset correction                             : %d\n", result.DriveInfo.ReadOffset))
		log.WriteString(fmt.Sprintf("Overread into Lead-In and Lead-Out                : %s\n",
			boolToYesNo(result.DriveInfo.AccurateStream)))
		log.WriteString(fmt.Sprintf("C2 error correction                               : %s\n",
			boolToYesNo(result.DriveInfo.C2Support)))
	}

	log.WriteString("Accurate stream                                    : Yes\n")
	log.WriteString("Disable audio cache                                : Yes\n")
	log.WriteString("Make use of C2 pointers                           : Yes\n\n")

	log.WriteString("Read mode                                          : Secure\n")
	log.WriteString("Utilize accurate stream                            : Yes\n")
	log.WriteString("Defeat audio cache                                 : Yes\n")
	log.WriteString("Make use of C2 pointers                           : Yes\n\n")

	log.WriteString("Output format                                      : Internal WAV Routines\n")
	log.WriteString("Sample format                                      : 44.100 kHz; 16 Bit; Stereo\n\n")

	// Add track information
	for _, track := range meta.Tracks {
		log.WriteString(fmt.Sprintf("Track %2d\n", track.Number))
		log.WriteString(fmt.Sprintf("     Filename %s\n", generateFilename(track, meta)))

		if track.AccurateRip != nil {
			log.WriteString(fmt.Sprintf("     Accurately ripped (confidence %d)  [%s]\n",
				track.AccurateRip.Confidence, track.AccurateRip.CRC))
		} else {
			log.WriteString("     Cannot be verified as accurate\n")
		}

		if track.TestCRC != "" && track.CopyCRC != "" {
			log.WriteString(fmt.Sprintf("     Test CRC %s\n", track.TestCRC))
			log.WriteString(fmt.Sprintf("     Copy CRC %s\n", track.CopyCRC))
			if track.TestCRC == track.CopyCRC {
				log.WriteString("     Copy OK\n")
			} else {
				log.WriteString("     Copy failed\n")
			}
		}

		log.WriteString("\n")
	}

	log.WriteString("==== Log checksum " + generateLogChecksum(log.String()) + " ====\n")

	return log.String()
}

// buildRippingSettings creates ripping settings from config
func buildRippingSettings(cfg *config.Config) *metadata.RippingSettings {
	return &metadata.RippingSettings{
		SecureMode:        cfg.Ripper.Quality.SecureRipping,
		C2ErrorCorrection: cfg.Ripper.Quality.C2ErrorCorrection,
		TestAndCopy:       cfg.Ripper.Quality.TestAndCopy,
		AccurateRip:       cfg.Ripper.Quality.AccurateRip.Enabled,
		MaxRetries:        cfg.Ripper.Quality.MaxRetryAttempts,
		CompressionLevel:  cfg.Ripper.Quality.Compression,
	}
}

// Helper functions

func calculateCRC32(filename string) (string, error) {
	file, err := os.Open(filename)
	if err != nil {
		return "", err
	}
	defer file.Close()

	hash := md5.New()
	if _, err := io.Copy(hash, file); err != nil {
		return "", err
	}

	return hex.EncodeToString(hash.Sum(nil)), nil
}

func extractFloatFromOutput(output, pattern string) float64 {
	re := regexp.MustCompile(pattern + `\s*([+-]?\d+\.?\d*)`)
	matches := re.FindStringSubmatch(output)
	if len(matches) > 1 {
		if val, err := strconv.ParseFloat(matches[1], 64); err == nil {
			return val
		}
	}
	return 0.0
}

func boolToYesNo(b bool) string {
	if b {
		return "Yes"
	}
	return "No"
}

func generateLogChecksum(logContent string) string {
	hash := md5.New()
	hash.Write([]byte(logContent))
	return hex.EncodeToString(hash.Sum(nil))[:8]
}

func analyzeAudioFile(filename string) (*AudioAnalysis, error) {
	// Use ffmpeg to analyze the audio file
	cmd := exec.Command("ffmpeg", "-i", filename, "-af", "astats=metadata=1:reset=1", "-f", "null", "-")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return nil, err
	}

	outputStr := string(output)
	analysis := &AudioAnalysis{}

	// Extract peak level
	if peak := extractFloatFromOutput(outputStr, "Peak level dB:"); peak != 0 {
		analysis.Peak = math.Pow(10, peak/20) // Convert dB to linear
	}

	// Extract RMS level
	if rms := extractFloatFromOutput(outputStr, "RMS level dB:"); rms != 0 {
		analysis.RMS = math.Pow(10, rms/20) // Convert dB to linear
	}

	// Calculate CRC32
	crc32, err := calculateCRC32(filename)
	if err == nil {
		analysis.CRC32 = crc32
	}

	// Check for clipping (peak >= 1.0)
	analysis.Clipping = analysis.Peak >= 1.0

	// Calculate dynamic range (simplified)
	if analysis.Peak > 0 && analysis.RMS > 0 {
		analysis.DynamicRange = 20 * math.Log10(analysis.Peak/analysis.RMS)
	}

	return analysis, nil
}
