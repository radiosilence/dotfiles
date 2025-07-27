#!/usr/bin/env swift

import Foundation
import AppKit

// Configuration struct matching the Go version
struct Config {
    let workBrowser: String
    let personalBrowser: String
    let workStartHour: Int
    let workEndHour: Int
    let workDays: String
    
    init(workBrowser: String = "Google Chrome", personalBrowser: String = "Zen", workStartHour: Int = 9, workEndHour: Int = 18, workDays: String = "1-5") {
        self.workBrowser = workBrowser
        self.personalBrowser = personalBrowser
        self.workStartHour = workStartHour
        self.workEndHour = workEndHour
        self.workDays = workDays
    }
    
    static func loadFromFile() -> Config {
        // Start with defaults
        var workBrowser = "Google Chrome"
        var personalBrowser = "Zen"
        var workStartHour = 9
        var workEndHour = 18
        var workDays = "1-5"
        
        // Try to read from config file
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let configPath = homeDir.appendingPathComponent(".dotfiles/packages/browser-schedule/config.yaml")
        
        if let configData = try? Data(contentsOf: configPath),
           let configString = String(data: configData, encoding: .utf8) {
            // Simple YAML parsing for our specific format
            let lines = configString.components(separatedBy: .newlines)
            for line in lines {
                let parts = line.components(separatedBy: ": ")
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let rawValue = parts[1].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
                    // Remove comments (everything after #)
                    let value = rawValue.components(separatedBy: "#")[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    switch key {
                    case "work_browser":
                        workBrowser = value
                    case "personal_browser":
                        personalBrowser = value
                    case "work_start_hour":
                        if let hour = Int(value) {
                            workStartHour = hour
                        }
                    case "work_end_hour":
                        if let hour = Int(value) {
                            workEndHour = hour
                        }
                    case "work_days":
                        workDays = value
                    default:
                        break
                    }
                }
            }
            logMessage("Loaded config from \(configPath.path)")
        } else {
            logMessage("Config file not found at \(configPath.path), using defaults")
        }
        
        return Config(workBrowser: workBrowser, personalBrowser: personalBrowser, workStartHour: workStartHour, workEndHour: workEndHour, workDays: workDays)
    }
}

func logMessage(_ message: String) {
    let timestamp = DateFormatter()
    timestamp.dateFormat = "yyyy/MM/dd HH:mm:ss"
    let logEntry = "[\(timestamp.string(from: Date()))] \(message)"
    
    // Write to log file
    let logURL = URL(fileURLWithPath: "/tmp/browser-schedule.log")
    if let data = (logEntry + "\n").data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logURL.path) {
            if let fileHandle = try? FileHandle(forWritingTo: logURL) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        } else {
            try? data.write(to: logURL)
        }
    }
    
    // Also print to stdout
    print(logEntry)
}

func isWorkTime(config: Config) -> Bool {
    let now = Date()
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: now)
    let weekday = calendar.component(.weekday, from: now) // 1=Sunday, 2=Monday, etc.
    
    // Convert to match cron format (1=Monday, 7=Sunday)
    let cronWeekday = weekday == 1 ? 7 : weekday - 1
    
    // Check if it's a work day
    let isWorkDay: Bool
    switch config.workDays {
    case "1-5":
        isWorkDay = cronWeekday >= 1 && cronWeekday <= 5
    case "1-7":
        isWorkDay = true
    default:
        isWorkDay = cronWeekday >= 1 && cronWeekday <= 5
    }
    
    logMessage("Day check: weekday=\(cronWeekday), workDays=\(config.workDays), isWorkDay=\(isWorkDay)")
    
    if !isWorkDay {
        return false
    }
    
    return hour >= config.workStartHour && hour < config.workEndHour
}

func openURL(_ urlString: String, config: Config) {
    let targetBrowser = isWorkTime(config: config) ? config.workBrowser : config.personalBrowser
    let timeString = DateFormatter()
    timeString.dateFormat = "HH:mm"
    
    logMessage("Opening \(urlString) in \(targetBrowser) (\(timeString.string(from: Date())))")
    
    let task = Process()
    task.launchPath = "/usr/bin/open"
    task.arguments = ["-a", targetBrowser, urlString]
    
    do {
        try task.run()
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            logMessage("Successfully opened \(urlString) in \(targetBrowser)")
        } else {
            logMessage("Error opening \(urlString): exit code \(task.terminationStatus)")
        }
    } catch {
        logMessage("Error opening \(urlString): \(error)")
    }
}

func createAppBundle() throws {
    let appDir = "/Applications/BrowserSchedule.app"
    let contentsDir = "\(appDir)/Contents"
    let macosDir = "\(contentsDir)/MacOS"
    
    // Create directories
    try FileManager.default.createDirectory(atPath: macosDir, withIntermediateDirectories: true, attributes: nil)
    
    // Create Info.plist
    let infoPlist = """
<?xml version="1.0" encoding="UTF-8"?>
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
			<string>Web site URL</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>http</string>
				<string>https</string>
			</array>
			<key>LSHandlerRank</key>
			<string>Owner</string>
		</dict>
	</array>
</dict>
</plist>
"""
    
    try infoPlist.write(toFile: "\(contentsDir)/Info.plist", atomically: true, encoding: .utf8)
    
    // Copy the current Swift binary to the app bundle
    let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
    let swiftBinary = "\(homeDir)/.dotfiles/packages/browser-schedule/browser-schedule-swift"
    let execPath = "\(macosDir)/browser-schedule"
    
    // Remove existing file if it exists
    if FileManager.default.fileExists(atPath: execPath) {
        try FileManager.default.removeItem(atPath: execPath)
    }
    
    try FileManager.default.copyItem(atPath: swiftBinary, toPath: execPath)
    
    // Make it executable
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: execPath)
}

// Custom Application Delegate
class URLAppDelegate: NSObject, NSApplicationDelegate {
    let config = Config.loadFromFile()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logMessage("BrowserSchedule app finished launching and ready for URL events")
        
        // Set up timeout to exit if no URLs received within 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            logMessage("Timeout reached (5s), no URLs received, exiting")
            NSApplication.shared.terminate(nil)
        }
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        logMessage("Received \(urls.count) URLs from macOS via Swift delegate")
        
        for url in urls {
            let urlString = url.absoluteString
            logMessage("Processing URL from Swift delegate: \(urlString)")
            openURL(urlString, config: config)
        }
        
        logMessage("URLs processed via Swift delegate, exiting")
        NSApplication.shared.terminate(nil)
    }
}

// Main execution
if CommandLine.arguments.count > 1 {
    let arg = CommandLine.arguments[1]
    
    // Handle command line arguments (--config, --install, etc.)
    switch arg {
    case "--config":
        let config = Config.loadFromFile()
        print("Current configuration:")
        print("  Work browser: \(config.workBrowser)")
        print("  Personal browser: \(config.personalBrowser)")
        print("  Work hours: \(config.workStartHour):00-\(config.workEndHour):00")
        print("  Work days: \(config.workDays)")
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        print("  Config file: \(homeDir.appendingPathComponent(".dotfiles/packages/browser-schedule/config.yaml").path)")
        if isWorkTime(config: config) {
            print("  Current: Work time - using \(config.workBrowser)")
        } else {
            print("  Current: Personal time - using \(config.personalBrowser)")
        }
        exit(0)
        
    case "--install", "--update":
        print("Creating app bundle...")
        do {
            try createAppBundle()
            print("App bundle created successfully at /Applications/BrowserSchedule.app")
        } catch {
            print("Error creating app bundle: \(error)")
            exit(1)
        }
        exit(0)
        
    default:
        // Check if it's a URL
        if arg.hasPrefix("http://") || arg.hasPrefix("https://") {
            let config = Config.loadFromFile()
            logMessage("Received URL from macOS via command line: \(arg)")
            openURL(arg, config: config)
            exit(0)
        }
    }
}

// Default behavior: run as app with URL event handling
logMessage("Starting BrowserSchedule as native Swift app")

let app = NSApplication.shared
let delegate = URLAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.prohibited) // Background app
app.run()