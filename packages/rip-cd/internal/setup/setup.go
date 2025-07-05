package setup

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"

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
			"flac",   // FLAC codec and metaflac tool
			"ffmpeg", // Audio processing and conversion
		},
		Casks: []string{
			"xld", // X Lossless Decoder for CD ripping
		},
		PythonPackages: []string{
			"beets>=1.6.0",          // Music library management
			"musicbrainzngs>=0.7.1", // MusicBrainz API client
			"PyYAML>=6.0",           // YAML processing
			"jsonschema>=4.0.0",     // JSON schema validation
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
			toAdd = append(toAdd, fmt.Sprintf("cask \"%s\", greedy: true", cask))
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
