package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"time"

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

func getConfigPath() string {
	homeDir, _ := os.UserHomeDir()
	return filepath.Join(homeDir, ".dotfiles", "packages", "browser-schedule", "config.yaml")
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
	configPath := getConfigPath()
	if data, err := os.ReadFile(configPath); err == nil {
		if err := yaml.Unmarshal(data, &config); err != nil {
			logMessage(fmt.Sprintf("Error parsing config file: %v", err))
		} else {
			logMessage(fmt.Sprintf("Loaded config from %s", configPath))
		}
	} else {
		logMessage(fmt.Sprintf("Config file not found at %s, using defaults", configPath))
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
	if config.WorkDays == "1-5" {
		// Monday-Friday
		isWorkDay = weekday >= 1 && weekday <= 5
	} else if config.WorkDays == "1-7" {
		// All days
		isWorkDay = true
	} else {
		// TODO: Support custom day lists like "1,2,3,7"
		isWorkDay = weekday >= 1 && weekday <= 5
	}
	
	logMessage(fmt.Sprintf("Day check: weekday=%d, config.WorkDays=%s, isWorkDay=%t", weekday, config.WorkDays, isWorkDay))
	
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
		logMessage("Work time detected")
	} else {
		targetBrowser = config.PersonalBrowser
		logMessage("Personal time detected")
	}
	
	logMessage(fmt.Sprintf("Opening %s in %s (%s)", url, targetBrowser, time.Now().Format("15:04")))
	
	cmd := exec.Command("open", "-a", targetBrowser, url)
	if err := cmd.Run(); err != nil {
		logMessage(fmt.Sprintf("Error opening %s: %v", url, err))
	} else {
		logMessage(fmt.Sprintf("Successfully opened %s in %s", url, targetBrowser))
	}
}

func logMessage(message string) {
	homeDir, _ := os.UserHomeDir()
	logFile := homeDir + "/browser-schedule.log"
	
	f, err := os.OpenFile(logFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		return
	}
	defer f.Close()
	
	timestamp := time.Now().Format("2006-01-02 15:04:05")
	f.WriteString(fmt.Sprintf("[%s] %s\n", timestamp, message))
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
			fmt.Printf("  Config file: %s\n", getConfigPath())
			if isWorkTime(config) {
				fmt.Printf("  Current: Work time - using %s\n", config.WorkBrowser)
			} else {
				fmt.Printf("  Current: Personal time - using %s\n", config.PersonalBrowser)
			}
			return
		}
		
		// Check if it's a URL
		if matched, _ := regexp.MatchString(`^https?://`, arg); matched {
			logMessage("Go browser schedule app started")
			logMessage(fmt.Sprintf("Args: %v", os.Args))
			logMessage(fmt.Sprintf("Config: WorkBrowser=%s, PersonalBrowser=%s, WorkHours=%d-%d", 
				config.WorkBrowser, config.PersonalBrowser, config.WorkStartHour, config.WorkEndHour))
			logMessage(fmt.Sprintf("IsWorkTime: %t", isWorkTime(config)))
			logMessage(fmt.Sprintf("Processing URL: %s", arg))
			openURL(arg, config)
			return
		}
	}
	
	// If no URL provided, just log and exit
	logMessage("Go browser schedule app started with no URL")
}