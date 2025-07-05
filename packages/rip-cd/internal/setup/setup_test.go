package setup

import (
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"
)

func TestGetEssentialDeps(t *testing.T) {
	deps := getEssentialDeps()

	// Check that we have the essential brews
	expectedBrews := []string{"flac", "ffmpeg"}
	if len(deps.Brews) != len(expectedBrews) {
		t.Errorf("Expected %d brews, got %d", len(expectedBrews), len(deps.Brews))
	}

	for _, expected := range expectedBrews {
		found := false
		for _, actual := range deps.Brews {
			if actual == expected {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("Expected brew %s not found", expected)
		}
	}

	// Check that we have XLD cask
	if len(deps.Casks) != 1 || deps.Casks[0] != "xld" {
		t.Errorf("Expected XLD cask, got %v", deps.Casks)
	}

	// Check that we have essential Python packages
	expectedPythonPackages := []string{"beets", "musicbrainzngs", "PyYAML", "jsonschema"}
	if len(deps.PythonPackages) < len(expectedPythonPackages) {
		t.Errorf("Expected at least %d Python packages, got %d", len(expectedPythonPackages), len(deps.PythonPackages))
	}

	for _, expected := range expectedPythonPackages {
		found := false
		for _, actual := range deps.PythonPackages {
			if strings.Contains(actual, expected) {
				found = true
				break
			}
		}
		if !found {
			t.Errorf("Expected Python package %s not found", expected)
		}
	}
}

func TestRunOnNonMacOS(t *testing.T) {
	// Skip this test if we're actually on macOS
	if runtime.GOOS == "darwin" {
		t.Skip("Skipping non-macOS test on macOS")
	}

	err := Run(true, false)
	if err == nil {
		t.Error("Expected error when running on non-macOS, got nil")
	}
	if !strings.Contains(err.Error(), "macOS only") {
		t.Errorf("Expected macOS error, got: %v", err)
	}
}

func TestUpdateBrewfile(t *testing.T) {
	// Create a temporary directory for testing
	tmpDir := t.TempDir()
	brewfilePath := filepath.Join(tmpDir, "Brewfile")

	// Test with non-existent Brewfile
	deps := EssentialDependencies{
		Brews: []string{"flac", "ffmpeg"},
		Casks: []string{"xld"},
	}

	err := updateBrewfile(deps, true) // dry run
	if err != nil {
		t.Errorf("updateBrewfile dry run failed: %v", err)
	}

	// Test with existing Brewfile
	existingContent := `# Existing Brewfile
brew "git"
cask "firefox"
`
	if err := os.WriteFile(brewfilePath, []byte(existingContent), 0644); err != nil {
		t.Fatalf("Failed to create test Brewfile: %v", err)
	}

	// Mock the home directory to point to our temp dir
	originalHome := os.Getenv("HOME")
	os.Setenv("HOME", tmpDir)
	defer os.Setenv("HOME", originalHome)

	// Test dry run with existing file
	err = updateBrewfile(deps, true)
	if err != nil {
		t.Errorf("updateBrewfile dry run with existing file failed: %v", err)
	}

	// Test actual update
	err = updateBrewfile(deps, false)
	if err != nil {
		t.Errorf("updateBrewfile failed: %v", err)
	}

	// Verify the file was updated
	updatedContent, err := os.ReadFile(brewfilePath)
	if err != nil {
		t.Fatalf("Failed to read updated Brewfile: %v", err)
	}

	content := string(updatedContent)
	if !strings.Contains(content, `brew "flac"`) {
		t.Error("Updated Brewfile should contain flac")
	}
	if !strings.Contains(content, `brew "ffmpeg"`) {
		t.Error("Updated Brewfile should contain ffmpeg")
	}
	if !strings.Contains(content, `cask "xld"`) {
		t.Error("Updated Brewfile should contain xld")
	}
}

func TestUpdateBrewfileWithExistingPackages(t *testing.T) {
	tmpDir := t.TempDir()
	brewfilePath := filepath.Join(tmpDir, "Brewfile")

	// Create Brewfile with packages already present
	existingContent := `# Existing Brewfile
brew "flac"
brew "ffmpeg"
cask "xld"
`
	if err := os.WriteFile(brewfilePath, []byte(existingContent), 0644); err != nil {
		t.Fatalf("Failed to create test Brewfile: %v", err)
	}

	// Mock the home directory
	originalHome := os.Getenv("HOME")
	os.Setenv("HOME", tmpDir)
	defer os.Setenv("HOME", originalHome)

	deps := EssentialDependencies{
		Brews: []string{"flac", "ffmpeg"},
		Casks: []string{"xld"},
	}

	// Should not add duplicates
	err := updateBrewfile(deps, false)
	if err != nil {
		t.Errorf("updateBrewfile failed: %v", err)
	}

	// Verify no duplicates were added
	updatedContent, err := os.ReadFile(brewfilePath)
	if err != nil {
		t.Fatalf("Failed to read updated Brewfile: %v", err)
	}

	content := string(updatedContent)
	flacCount := strings.Count(content, `brew "flac"`)
	if flacCount != 1 {
		t.Errorf("Expected 1 occurrence of flac, got %d", flacCount)
	}
}

func TestFindPythonExecutable(t *testing.T) {
	pythonCmd := findPythonExecutable()

	// We can't guarantee Python is installed in test environment
	// but we can test the logic
	if pythonCmd != "" {
		t.Logf("Found Python executable: %s", pythonCmd)

		// If we found one, it should be a valid path
		if !strings.Contains(pythonCmd, "python") {
			t.Errorf("Expected Python executable to contain 'python', got: %s", pythonCmd)
		}
	} else {
		t.Log("No Python executable found in test environment")
	}
}

func TestInstallPythonDependenciesDryRun(t *testing.T) {
	packages := []string{"beets>=1.6.0", "musicbrainzngs>=0.7.1"}

	// Dry run should not fail even if Python is not installed
	err := installPythonDependencies(packages, true)
	if err != nil {
		// If Python is not found, that's acceptable in dry run
		if !strings.Contains(err.Error(), "Python 3 not found") {
			t.Errorf("Unexpected error in dry run: %v", err)
		}
	}
}

func TestRunDryRun(t *testing.T) {
	// Skip if not on macOS
	if runtime.GOOS != "darwin" {
		t.Skip("Skipping macOS-specific test")
	}

	// Dry run should not fail
	err := Run(true, false)
	if err != nil {
		t.Errorf("Dry run failed: %v", err)
	}
}

func TestEssentialDependenciesStructure(t *testing.T) {
	deps := EssentialDependencies{
		Brews:          []string{"test-brew"},
		Casks:          []string{"test-cask"},
		PythonPackages: []string{"test-package"},
	}

	if len(deps.Brews) != 1 || deps.Brews[0] != "test-brew" {
		t.Error("Brews field not working correctly")
	}
	if len(deps.Casks) != 1 || deps.Casks[0] != "test-cask" {
		t.Error("Casks field not working correctly")
	}
	if len(deps.PythonPackages) != 1 || deps.PythonPackages[0] != "test-package" {
		t.Error("PythonPackages field not working correctly")
	}
}

func TestVerifyInstallationLogic(t *testing.T) {
	deps := EssentialDependencies{
		Brews:          []string{"nonexistent-brew"},
		Casks:          []string{"nonexistent-cask"},
		PythonPackages: []string{"nonexistent-package"},
	}

	// This should fail because the packages don't exist
	err := verifyInstallation(deps)
	if err == nil {
		t.Error("Expected verification to fail with nonexistent packages")
	}
}

func TestUpdateBrewfileErrorHandling(t *testing.T) {
	// Test with invalid home directory
	originalHome := os.Getenv("HOME")
	os.Setenv("HOME", "/nonexistent/directory")
	defer os.Setenv("HOME", originalHome)

	deps := getEssentialDeps()
	err := updateBrewfile(deps, false)
	if err == nil {
		t.Error("Expected error with invalid home directory")
	}
}
