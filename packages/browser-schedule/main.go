package main

import (
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/progrium/darwinkit/macos/appkit"
	"gopkg.in/yaml.v3"
)

// Configuration
type Config struct {
	WorkBrowser     string `yaml:"work_browser"`
	PersonalBrowser string `yaml:"personal_browser"`
	WorkStartHour   int    `yaml:"work_start_hour"`
	WorkEndHour     int    `yaml:"work_end_hour"`
	WorkDays        string `yaml:"work_days"`
}

func getConfig() Config {
	// Default config
	config := Config{
		WorkBrowser:     "Google Chrome",
		PersonalBrowser: "Zen",
		WorkStartHour:   9,
		WorkEndHour:     18,
		WorkDays:        "1-5",
	}

	// Try to read from config file
	homeDir, _ := os.UserHomeDir()
	configPath := filepath.Join(homeDir, ".dotfiles", "packages", "browser-schedule", "config.yaml")
	if data, err := os.ReadFile(configPath); err == nil {
		if err := yaml.Unmarshal(data, &config); err != nil {
			log.Printf("Error parsing config file: %v", err)
		} else {
			log.Printf("Loaded config from %s", configPath)
		}
	} else {
		log.Printf("Config file not found at %s, using defaults", configPath)
	}

	// Environment variables override config file
	if workBrowser := os.Getenv("WORK_BROWSER"); workBrowser != "" {
		config.WorkBrowser = workBrowser
	}
	if personalBrowser := os.Getenv("PERSONAL_BROWSER"); personalBrowser != "" {
		config.PersonalBrowser = personalBrowser
	}
	if workStartHour := os.Getenv("WORK_START_HOUR"); workStartHour != "" {
		if hour, err := strconv.Atoi(workStartHour); err == nil {
			config.WorkStartHour = hour
		}
	}
	if workEndHour := os.Getenv("WORK_END_HOUR"); workEndHour != "" {
		if hour, err := strconv.Atoi(workEndHour); err == nil {
			config.WorkEndHour = hour
		}
	}
	if workDays := os.Getenv("WORK_DAYS"); workDays != "" {
		config.WorkDays = workDays
	}

	return config
}

func isWorkTime(config Config) bool {
	now := time.Now()
	hour := now.Hour()
	weekday := int(now.Weekday())

	// Convert Sunday=0 to Sunday=7 to match cron format
	if weekday == 0 {
		weekday = 7
	}

	// Check if it's a work day
	isWorkDay := false
	switch config.WorkDays {
	case "1-5":
		// Monday-Friday
		isWorkDay = weekday >= 1 && weekday <= 5
	case "1-7":
		// All days
		isWorkDay = true
	default:
		// TODO: Support custom day lists like "1,2,3,7"
		isWorkDay = weekday >= 1 && weekday <= 5
	}

	log.Printf("Day check: weekday=%d, config.WorkDays=%s, isWorkDay=%t", weekday, config.WorkDays, isWorkDay)

	if !isWorkDay {
		return false
	}

	// Check if it's work hours
	return hour >= config.WorkStartHour && hour < config.WorkEndHour
}

func openURL(url string, config Config) {
	var targetBrowser string
	if isWorkTime(config) {
		targetBrowser = config.WorkBrowser
		log.Println("Work time detected")
	} else {
		targetBrowser = config.PersonalBrowser
		log.Println("Personal time detected")
	}

	log.Printf("Opening %s in %s (%s)", url, targetBrowser, time.Now().Format("15:04"))

	cmd := exec.Command("open", "-a", targetBrowser, url)
	if err := cmd.Run(); err != nil {
		log.Printf("Error opening %s: %v", url, err)
	} else {
		log.Printf("Successfully opened %s in %s", url, targetBrowser)
	}
}

func createAppBundle() error {
	appDir := "/Applications/BrowserSchedule.app"
	contentsDir := filepath.Join(appDir, "Contents")
	macosDir := filepath.Join(contentsDir, "MacOS")

	// Create directories
	if err := os.MkdirAll(macosDir, 0755); err != nil {
		return fmt.Errorf("failed to create app directories: %v", err)
	}

	// Create Info.plist
	infoPlist := `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>browser-schedule</string>
	<key>CFBundleIdentifier</key>
	<string>com.example.browserschedule</string>
	<key>CFBundleName</key>
	<string>BrowserSchedule</string>
	<key>CFBundleVersion</key>
	<string>1.0</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>LSUIElement</key>
	<true/>
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleURLName</key>
			<string>HTTP URL</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>http</string>
				<string>https</string>
			</array>
		</dict>
	</array>
</dict>
</plist>`

	if err := os.WriteFile(filepath.Join(contentsDir, "Info.plist"), []byte(infoPlist), 0644); err != nil {
		return fmt.Errorf("failed to create Info.plist: %v", err)
	}

	// Copy the current binary to the app bundle
	currentBinary, err := os.Executable()
	if err != nil {
		return fmt.Errorf("failed to get current executable path: %v", err)
	}

	execPath := filepath.Join(macosDir, "browser-schedule")
	input, err := os.ReadFile(currentBinary)
	if err != nil {
		return fmt.Errorf("failed to read binary: %v", err)
	}
	if err := os.WriteFile(execPath, input, 0644); err != nil {
		return fmt.Errorf("failed to copy binary: %v", err)
	}

	if err := os.Chmod(execPath, 0755); err != nil {
		return fmt.Errorf("failed to make binary executable: %v", err)
	}

	return nil
}

func main() {
	config := getConfig()

	// Handle special commands
	if len(os.Args) > 1 {
		arg := os.Args[1]

		switch arg {
		case "--config":
			fmt.Printf("Current configuration:\n")
			fmt.Printf("  Work browser: %s\n", config.WorkBrowser)
			fmt.Printf("  Personal browser: %s\n", config.PersonalBrowser)
			fmt.Printf("  Work hours: %d:00-%d:00\n", config.WorkStartHour, config.WorkEndHour)
			fmt.Printf("  Work days: %s\n", config.WorkDays)
			homeDir, _ := os.UserHomeDir()
			fmt.Printf("  Config file: %s\n", filepath.Join(homeDir, ".dotfiles", "packages", "browser-schedule", "config.yaml"))
			if isWorkTime(config) {
				fmt.Printf("  Current: Work time - using %s\n", config.WorkBrowser)
			} else {
				fmt.Printf("  Current: Personal time - using %s\n", config.PersonalBrowser)
			}
			return

		case "--install":
			fmt.Println("Creating app bundle...")
			if err := createAppBundle(); err != nil {
				fmt.Printf("Error creating app bundle: %v\n", err)
				os.Exit(1)
			}
			fmt.Println("App bundle created successfully at /Applications/BrowserSchedule.app")
			return

		case "--update":
			fmt.Println("Updating app bundle...")
			if err := createAppBundle(); err != nil {
				fmt.Printf("Error updating app bundle: %v\n", err)
				os.Exit(1)
			}
			fmt.Println("App bundle updated successfully")
			return

		case "--uninstall":
			fmt.Println("Removing app bundle...")
			if err := os.RemoveAll("/Applications/BrowserSchedule.app"); err != nil {
				fmt.Printf("Error removing app bundle: %v\n", err)
				os.Exit(1)
			}
			fmt.Println("App bundle removed successfully")
			return

		case "--status":
			status := "Not installed"
			if _, err := os.Stat("/Applications/BrowserSchedule.app"); err == nil {
				// Check if it's the default browser
				cmd := exec.Command("defaultbrowser")
				output, err := cmd.Output()
				if err != nil {
					status = "Installed (unable to check default browser status)"
				} else if strings.Contains(string(output), "BrowserSchedule") {
					status = "Installed and set as default browser"
				} else {
					status = "Installed but not set as default browser"
				}
			}
			fmt.Printf("Status: %s\n", status)
			return
		}
	}

	// Default behavior: run as app
	log.Println("Starting BrowserSchedule as native macOS app")
	app := appkit.Application_SharedApplication()
	app.SetActivationPolicy(appkit.ApplicationActivationPolicyProhibited) // Background app
	app.Run()
}
