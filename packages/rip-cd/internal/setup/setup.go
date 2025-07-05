package setup

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/radiosilence/dotfiles/packages/rip-cd/internal/config"
	"github.com/sirupsen/logrus"
)

// EssentialDependencies defines the minimal required packages for CD ripping
type EssentialDependencies struct {
	Brews          []string
	Casks          []string
	PythonPackages []string
}

// getEssentialDeps returns the minimal dependencies needed for CD ripping
func getEssentialDeps() EssentialDependencies {
	return EssentialDependencies{
		Brews: []string{
			"flac",       // FLAC codec and metaflac tool
			"ffmpeg",     // Audio processing and conversion
			"sox",        // Sound processing for spectrograms
			"libsndfile", // Audio file format support
		},
		Casks: []string{
			"xld", // X Lossless Decoder for CD ripping
		},
		PythonPackages: []string{
			"beets>=1.6.0",          // Music library management
			"musicbrainzngs>=0.7.1", // MusicBrainz API client
			"PyYAML>=6.0",           // YAML processing
			"jsonschema>=4.0.0",     // JSON schema validation
			"matplotlib>=3.5.0",     // For spectrogram generation
			"numpy>=1.21.0",         // Audio analysis support
			"scipy>=1.7.0",          // Signal processing
		},
	}
}

// Run executes the setup process
func Run(dryRun bool, verbose bool) error {
	if dryRun {
		logrus.Info("🎯 Dry run mode - showing what would be installed")
	}

	// Check if we're on macOS
	if runtime.GOOS != "darwin" {
		return fmt.Errorf("this setup is designed for macOS only")
	}

	logrus.Info("🍎 Detected macOS")

	// Check if Homebrew is installed
	if !isHomebrewInstalled() {
		if dryRun {
			logrus.Info("📦 Would install Homebrew")
		} else {
			if err := installHomebrew(); err != nil {
				return fmt.Errorf("failed to install Homebrew: %w", err)
			}
		}
	} else {
		logrus.Info("✅ Homebrew is already installed")
	}

	deps := getEssentialDeps()

	// Update Brewfile
	if err := updateBrewfile(deps, dryRun); err != nil {
		return fmt.Errorf("failed to update Brewfile: %w", err)
	}

	// Install Homebrew dependencies
	if !dryRun {
		if err := installBrewDependencies(); err != nil {
			return fmt.Errorf("failed to install Homebrew dependencies: %w", err)
		}
	} else {
		logrus.Info("📦 Would install Homebrew dependencies")
	}

	// Install Python dependencies
	if err := installPythonDependencies(deps.PythonPackages, dryRun); err != nil {
		return fmt.Errorf("failed to install Python dependencies: %w", err)
	}

	// Setup XLD profiles
	if err := setupXLDProfiles(dryRun); err != nil {
		return fmt.Errorf("failed to setup XLD profiles: %w", err)
	}

	// Verify installation
	if !dryRun {
		if err := verifyInstallation(deps); err != nil {
			logrus.Warnf("Installation verification failed: %v", err)
		}
	}

	logrus.Info("✅ Setup completed successfully!")
	return nil
}

// isHomebrewInstalled checks if Homebrew is available
func isHomebrewInstalled() bool {
	_, err := exec.LookPath("brew")
	return err == nil
}

// installHomebrew installs Homebrew
func installHomebrew() error {
	logrus.Info("📦 Installing Homebrew...")
	cmd := exec.Command("/bin/bash", "-c", "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	return cmd.Run()
}

// updateBrewfile updates the Brewfile with essential dependencies
func updateBrewfile(deps EssentialDependencies, dryRun bool) error {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get home directory: %w", err)
	}

	brewfilePath := filepath.Join(homeDir, "Brewfile")

	// Read existing Brewfile if it exists
	existing := make(map[string]bool)
	if content, err := os.ReadFile(brewfilePath); err == nil {
		lines := strings.Split(string(content), "\n")
		for _, line := range lines {
			line = strings.TrimSpace(line)
			if strings.HasPrefix(line, "brew \"") || strings.HasPrefix(line, "cask \"") {
				// Extract package name
				parts := strings.Split(line, "\"")
				if len(parts) >= 2 {
					existing[parts[1]] = true
				}
			}
		}
	}

	// Check what needs to be added
	var toAdd []string

	for _, brew := range deps.Brews {
		if !existing[brew] {
			toAdd = append(toAdd, fmt.Sprintf("brew \"%s\"", brew))
		}
	}

	for _, cask := range deps.Casks {
		if !existing[cask] {
			if cask == "xld" {
				toAdd = append(toAdd, fmt.Sprintf("cask \"%s\", args: { no_quarantine: true }", cask))
			} else {
				toAdd = append(toAdd, fmt.Sprintf("cask \"%s\", greedy: true", cask))
			}
		}
	}

	if len(toAdd) == 0 {
		logrus.Info("✅ All required Homebrew packages already in Brewfile")
		return nil
	}

	if dryRun {
		logrus.Info("📝 Would add to Brewfile:")
		for _, item := range toAdd {
			logrus.Infof("  + %s", item)
		}
		return nil
	}

	// Create or append to Brewfile
	file, err := os.OpenFile(brewfilePath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return fmt.Errorf("failed to open Brewfile: %w", err)
	}
	defer file.Close()

	writer := bufio.NewWriter(file)

	// Add header if file is new
	if stat, err := file.Stat(); err == nil && stat.Size() == 0 {
		fmt.Fprintln(writer, "# Brewfile - Package dependencies managed by Homebrew Bundle")
		fmt.Fprintln(writer, "# Essential CD ripping dependencies added by rip-cd setup")
		fmt.Fprintln(writer)
	} else {
		fmt.Fprintln(writer)
		fmt.Fprintln(writer, "# CD ripping dependencies (added by rip-cd setup)")
	}

	for _, item := range toAdd {
		fmt.Fprintln(writer, item)
		logrus.Infof("📝 Added to Brewfile: %s", item)
	}

	return writer.Flush()
}

// installBrewDependencies installs packages from Brewfile
func installBrewDependencies() error {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get home directory: %w", err)
	}

	brewfilePath := filepath.Join(homeDir, "Brewfile")

	logrus.Info("📦 Installing Homebrew dependencies...")
	cmd := exec.Command("brew", "bundle", "install", "--file="+brewfilePath)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// installPythonDependencies installs Python packages
func installPythonDependencies(packages []string, dryRun bool) error {
	// Find Python executable
	pythonCmd := findPythonExecutable()
	if pythonCmd == "" {
		return fmt.Errorf("Python 3 not found. Please install Python 3 first")
	}

	logrus.Infof("🐍 Using Python: %s", pythonCmd)

	if dryRun {
		logrus.Info("🐍 Would install Python packages:")
		for _, pkg := range packages {
			logrus.Infof("  + %s", pkg)
		}
		return nil
	}

	// Ensure pip is available
	if err := ensurePip(pythonCmd); err != nil {
		return fmt.Errorf("failed to ensure pip: %w", err)
	}

	// Install packages
	for _, pkg := range packages {
		logrus.Infof("🐍 Installing Python package: %s", pkg)
		cmd := exec.Command(pythonCmd, "-m", "pip", "install", pkg)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		if err := cmd.Run(); err != nil {
			logrus.Warnf("Failed to install %s: %v", pkg, err)
		}
	}

	return nil
}

// findPythonExecutable finds the best Python 3 executable
func findPythonExecutable() string {
	candidates := []string{"python3", "python"}

	for _, cmd := range candidates {
		if path, err := exec.LookPath(cmd); err == nil {
			// Check if it's Python 3
			if output, err := exec.Command(path, "--version").Output(); err == nil {
				version := strings.TrimSpace(string(output))
				if strings.HasPrefix(version, "Python 3") {
					return path
				}
			}
		}
	}

	return ""
}

// ensurePip ensures pip is available
func ensurePip(pythonCmd string) error {
	// Check if pip is already available
	if err := exec.Command(pythonCmd, "-m", "pip", "--version").Run(); err == nil {
		return nil
	}

	logrus.Info("🐍 Installing pip...")
	cmd := exec.Command(pythonCmd, "-m", "ensurepip", "--upgrade")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// verifyInstallation checks if all dependencies are properly installed
func verifyInstallation(deps EssentialDependencies) error {
	logrus.Info("🔍 Verifying installation...")

	var missing []string
	var installed []string

	// Check Homebrew packages
	for _, brew := range deps.Brews {
		if err := exec.Command("brew", "list", brew).Run(); err != nil {
			missing = append(missing, fmt.Sprintf("brew: %s", brew))
		} else {
			installed = append(installed, fmt.Sprintf("brew: %s", brew))
		}
	}

	// Check casks
	for _, cask := range deps.Casks {
		if err := exec.Command("brew", "list", "--cask", cask).Run(); err != nil {
			missing = append(missing, fmt.Sprintf("cask: %s", cask))
		} else {
			installed = append(installed, fmt.Sprintf("cask: %s", cask))
		}
	}

	// Check Python packages
	pythonCmd := findPythonExecutable()
	if pythonCmd != "" {
		for _, pkg := range deps.PythonPackages {
			// Extract package name (remove version constraints)
			pkgName := strings.Split(pkg, ">=")[0]
			pkgName = strings.Split(pkgName, "==")[0]

			if err := exec.Command(pythonCmd, "-c", fmt.Sprintf("import %s", pkgName)).Run(); err != nil {
				missing = append(missing, fmt.Sprintf("python: %s", pkgName))
			} else {
				installed = append(installed, fmt.Sprintf("python: %s", pkgName))
			}
		}
	}

	// Report results
	if len(installed) > 0 {
		logrus.Info("✅ Successfully installed:")
		for _, item := range installed {
			logrus.Infof("  ✓ %s", item)
		}
	}

	if len(missing) > 0 {
		logrus.Warn("⚠️  Missing or failed installations:")
		for _, item := range missing {
			logrus.Warnf("  ✗ %s", item)
		}
		return fmt.Errorf("some dependencies are missing")
	}

	return nil
}

// setupXLDProfiles creates essential XLD profiles for CD ripping
func setupXLDProfiles(dryRun bool) error {
	// Load default config to get quality settings
	cfg := &config.Config{}
	cfg.SetDefaults()
	if dryRun {
		logrus.Info("🔧 Would create XLD profiles:")
		logrus.Info("  + flac_rip (high-quality FLAC profile)")
		logrus.Info("  + secure_rip (maximum security profile)")
		return nil
	}

	homeDir, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get home directory: %w", err)
	}

	plistPath := filepath.Join(homeDir, "Library", "Preferences", "jp.tmkk.XLD.plist")

	// Check if XLD has been run at least once
	if _, err := os.Stat(plistPath); os.IsNotExist(err) {
		logrus.Warn("⚠️  XLD preferences not found.")
		logrus.Warn("📝 Please run XLD GUI once to initialize settings, then run 'rip-cd setup' again.")
		return nil
	}

	// Check if XLD is currently running
	if isXLDRunning() {
		logrus.Warn("⚠️  XLD is currently running. Please quit XLD and run 'rip-cd setup' again.")
		logrus.Warn("📝 Or create profiles manually using the instructions below.")
		printManualProfileInstructions()
		return nil
	}

	// Create essential profiles using config defaults
	profiles := []struct {
		name        string
		description string
		settings    map[string]interface{}
	}{
		{
			name:        "flac_rip",
			description: "High-quality FLAC ripping profile for archival purposes",
			settings: map[string]interface{}{
				"TestAndCopy":                cfg.Ripper.Quality.TestAndCopy,
				"UseC2Pointer":               cfg.Ripper.Quality.C2ErrorCorrection,
				"QueryAccurateRip":           cfg.Ripper.Quality.AccurateRip.Enabled,
				"RetryCount":                 cfg.Ripper.Quality.MaxRetryAttempts,
				"RipperMode":                 4, // Secure mode (XLD constant)
				"ReadOffsetUseRipperValue":   true,
				"VerifySector":               cfg.Ripper.Quality.Verify,
				"SaveLogMode":                1, // Always save log (XLD constant)
				"Priority":                   0, // Normal priority (XLD constant)
				"XLDFlacOutput_Compression":  cfg.Ripper.Quality.Compression,
				"XLDFlacOutput_EmbedChapter": true,
			},
		},
		{
			name:        "secure_rip",
			description: "Maximum security ripping profile with all verification enabled",
			settings: map[string]interface{}{
				"TestAndCopy":                cfg.Ripper.Quality.TestAndCopy,
				"UseC2Pointer":               cfg.Ripper.Quality.C2ErrorCorrection,
				"QueryAccurateRip":           cfg.Ripper.Quality.AccurateRip.Enabled,
				"RetryCount":                 50, // Override for maximum security
				"RipperMode":                 4,  // Secure mode (XLD constant)
				"ReadOffsetUseRipperValue":   true,
				"VerifySector":               cfg.Ripper.Quality.Verify,
				"SaveLogMode":                1, // Always save log (XLD constant)
				"Priority":                   0, // Normal priority (XLD constant)
				"XLDFlacOutput_Compression":  cfg.Ripper.Quality.Compression,
				"XLDFlacOutput_EmbedChapter": true,
			},
		},
	}

	for _, profile := range profiles {
		if exists, err := checkXLDProfile(profile.name, plistPath); err != nil {
			logrus.Warnf("Failed to check XLD profile %s: %v", profile.name, err)
			continue
		} else if exists {
			logrus.Infof("✅ XLD profile already exists: %s", profile.name)
			continue
		}

		if err := createXLDProfileInPlist(profile.name, profile.description, profile.settings, plistPath); err != nil {
			logrus.Warnf("Failed to create XLD profile %s: %v", profile.name, err)
			continue
		}

		logrus.Infof("✅ Created XLD profile: %s", profile.name)
	}

	// Verify profiles were created successfully
	profilesExist := true
	for _, profile := range profiles {
		if exists, err := checkXLDProfile(profile.name, plistPath); err != nil || !exists {
			profilesExist = false
			break
		}
	}

	if !profilesExist {
		logrus.Warn("⚠️  Automatic profile creation may have failed.")
		logrus.Warn("📝 If profiles don't appear in XLD, create them manually:")
		printManualProfileInstructions()
	} else {
		logrus.Info("✅ XLD profiles created successfully!")
		logrus.Info("📝 Restart XLD to see the new profiles in the Profiles menu.")
	}

	return nil
}

// checkXLDProfile checks if a profile exists in XLD preferences
func checkXLDProfile(profileName, plistPath string) (bool, error) {
	cmd := exec.Command("plutil", "-extract", "Profiles", "xml1", "-o", "-", plistPath)
	output, err := cmd.Output()
	if err != nil {
		return false, err
	}

	return strings.Contains(string(output), profileName), nil
}

// createXLDProfileInPlist creates a new XLD profile in the preferences plist
func createXLDProfileInPlist(name, description string, settings map[string]interface{}, plistPath string) error {
	// Build the profile dictionary XML (just the dict, not a complete plist)
	profileDict := fmt.Sprintf(`<dict>
	<key>name</key>
	<string>%s</string>
	<key>description</key>
	<string>%s</string>`, name, description)

	// Add settings to the dictionary
	for key, value := range settings {
		profileDict += fmt.Sprintf(`
	<key>%s</key>`, key)

		switch v := value.(type) {
		case bool:
			if v {
				profileDict += `
	<true/>`
			} else {
				profileDict += `
	<false/>`
			}
		case int:
			profileDict += fmt.Sprintf(`
	<integer>%d</integer>`, v)
		case string:
			profileDict += fmt.Sprintf(`
	<string>%s</string>`, v)
		}
	}

	profileDict += `
</dict>`

	// Check if Profiles array exists
	cmd := exec.Command("plutil", "-extract", "Profiles", "xml1", "-o", "-", plistPath)
	if output, err := cmd.Output(); err == nil && strings.Contains(string(output), "<array>") {
		// Profiles array exists, insert new profile at the beginning
		insertCmd := exec.Command("plutil", "-insert", "Profiles.0", "-xml", profileDict, plistPath)
		return insertCmd.Run()
	} else {
		// Create Profiles array with our profile
		arrayXML := fmt.Sprintf(`<array>%s</array>`, profileDict)
		createCmd := exec.Command("plutil", "-replace", "Profiles", "-xml", arrayXML, plistPath)
		return createCmd.Run()
	}
}

// isXLDRunning checks if XLD is currently running
func isXLDRunning() bool {
	cmd := exec.Command("pgrep", "-f", "XLD")
	return cmd.Run() == nil
}

// printManualProfileInstructions prints instructions for manual profile creation
func printManualProfileInstructions() {
	logrus.Info("")
	logrus.Info("📋 Manual XLD Profile Creation Instructions:")
	logrus.Info("1. Open XLD application")
	logrus.Info("2. Go to Preferences (⌘,)")
	logrus.Info("3. Click the 'Profiles' tab")
	logrus.Info("4. Click '+' to create a new profile")
	logrus.Info("5. Name it 'flac_rip' and configure:")
	logrus.Info("   • Ripper Mode: Secure")
	logrus.Info("   • Test & Copy: Enabled")
	logrus.Info("   • Use C2 Pointer: Enabled (if drive supports)")
	logrus.Info("   • Query AccurateRip: Enabled")
	logrus.Info("   • Retry Count: 20")
	logrus.Info("   • Save Log: Always")
	logrus.Info("   • Output Format: FLAC")
	logrus.Info("   • Compression: 8 (Maximum)")
	logrus.Info("6. Create another profile 'secure_rip' with:")
	logrus.Info("   • Same settings as above")
	logrus.Info("   • Retry Count: 50 (for maximum security)")
	logrus.Info("7. Click 'OK' to save")
	logrus.Info("")
}
