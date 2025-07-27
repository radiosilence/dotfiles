#!/usr/bin/env swift

import Foundation
import AppKit
import CoreServices

// Configuration struct with native JSON parsing
struct Config: Codable {
    let workBrowser: String
    let personalBrowser: String
    let workStartHour: Int
    let workEndHour: Int
    let workDays: String
    let logPath: String?
    
    enum CodingKeys: String, CodingKey {
        case workBrowser = "work_browser"
        case personalBrowser = "personal_browser"
        case workStartHour = "work_start_hour"
        case workEndHour = "work_end_hour"
        case workDays = "work_days"
        case logPath = "log_path"
    }
    
    init(workBrowser: String = "Google Chrome", personalBrowser: String = "Zen", workStartHour: Int = 9, workEndHour: Int = 18, workDays: String = "1-5", logPath: String? = "/tmp/browser-schedule.log") {
        self.workBrowser = workBrowser
        self.personalBrowser = personalBrowser
        self.workStartHour = workStartHour
        self.workEndHour = workEndHour
        self.workDays = workDays
        self.logPath = logPath
    }
    
    static func loadFromFile() -> Config {
        let defaults = Config()
        
        // Try to read from config file
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let configPath = homeDir.appendingPathComponent(".dotfiles/packages/browser-schedule/config.json")
        
        guard let configData = try? Data(contentsOf: configPath) else {
            logMessage("Config file not found at \(configPath.path), using defaults", config: defaults)
            return defaults
        }
        
        do {
            var config = try JSONDecoder().decode(Config.self, from: configData)
            // Handle empty log_path as nil
            if let logPath = config.logPath, logPath.isEmpty {
                config = Config(workBrowser: config.workBrowser, personalBrowser: config.personalBrowser, 
                              workStartHour: config.workStartHour, workEndHour: config.workEndHour, 
                              workDays: config.workDays, logPath: nil)
            }
            logMessage("Loaded config from \(configPath.path)", config: config)
            return config
        } catch {
            logMessage("Error parsing config file at \(configPath.path): \(error), using defaults", config: defaults)
            return defaults
        }
    }
}

func logMessage(_ message: String, config: Config? = nil) {
    let timestamp = DateFormatter()
    timestamp.dateFormat = "yyyy/MM/dd HH:mm:ss"
    let logEntry = "[\(timestamp.string(from: Date()))] \(message)"
    
    // Only write to log file if log_path is configured
    if let logPath = config?.logPath {
        let logURL = URL(fileURLWithPath: logPath)
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
    }
    
    // Always print to stdout for command line usage
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
    
    logMessage("Day check: weekday=\(cronWeekday), workDays=\(config.workDays), isWorkDay=\(isWorkDay)", config: config)
    
    if !isWorkDay {
        return false
    }
    
    return hour >= config.workStartHour && hour < config.workEndHour
}

func openURL(_ urlString: String, config: Config) {
    let targetBrowser = isWorkTime(config: config) ? config.workBrowser : config.personalBrowser
    let timeString = DateFormatter()
    timeString.dateFormat = "HH:mm"
    
    logMessage("Opening \(urlString) in \(targetBrowser) (\(timeString.string(from: Date())))", config: config)
    
    let task = Process()
    task.launchPath = "/usr/bin/open"
    task.arguments = ["-a", targetBrowser, urlString]
    
    do {
        try task.run()
        task.waitUntilExit()
        if task.terminationStatus == 0 {
            logMessage("Successfully opened \(urlString) in \(targetBrowser)", config: config)
        } else {
            logMessage("Error opening \(urlString): exit code \(task.terminationStatus)", config: config)
        }
    } catch {
        logMessage("Error opening \(urlString): \(error)", config: config)
    }
}


// Custom Application Delegate
class URLAppDelegate: NSObject, NSApplicationDelegate {
    let config = Config.loadFromFile()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logMessage("BrowserSchedule app finished launching and ready for URL events", config: config)
        
        // Set up timeout to exit if no URLs received within 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            logMessage("Timeout reached (5s), no URLs received, exiting", config: self.config)
            NSApplication.shared.terminate(nil)
        }
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        logMessage("Received \(urls.count) URLs from macOS via Swift delegate", config: config)
        
        for url in urls {
            let urlString = url.absoluteString
            logMessage("Processing URL from Swift delegate: \(urlString)", config: config)
            openURL(urlString, config: config)
        }
        
        logMessage("URLs processed via Swift delegate, exiting", config: config)
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
        print("  Config file: \(homeDir.appendingPathComponent(".dotfiles/packages/browser-schedule/config.json").path)")
        if isWorkTime(config: config) {
            print("  Current: Work time - using \(config.workBrowser)")
        } else {
            print("  Current: Personal time - using \(config.personalBrowser)")
        }
        exit(0)
        
    case "--set-default":
        let bundleId = "com.example.browserschedule"
        
        // Register the app bundle first
        let registerTask = Process()
        registerTask.launchPath = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
        registerTask.arguments = ["-f", "/Applications/BrowserSchedule.app"]
        
        do {
            try registerTask.run()
            registerTask.waitUntilExit()
            print("Registered app bundle with Launch Services")
        } catch {
            print("Warning: Could not register app bundle: \(error)")
        }
        
        // Set as default for http and https
        let httpStatus = LSSetDefaultHandlerForURLScheme("http" as CFString, bundleId as CFString)
        let httpsStatus = LSSetDefaultHandlerForURLScheme("https" as CFString, bundleId as CFString)
        
        if httpStatus == noErr && httpsStatus == noErr {
            print("Successfully set BrowserSchedule as default browser")
        } else {
            print("Setting default browser requires user consent.")
            print("If prompted, please allow BrowserSchedule to be set as default browser.")
            print("HTTP handler status: \(httpStatus), HTTPS handler status: \(httpsStatus)")
        }
        
        exit(0)
        
    case "--install", "--update":
        print("Use 'task install' or 'task update' to manage app bundle")
        exit(1)
        
    default:
        // Check if it's a URL
        if arg.hasPrefix("http://") || arg.hasPrefix("https://") {
            let config = Config.loadFromFile()
            logMessage("Received URL from macOS via command line: \(arg)", config: config)
            openURL(arg, config: config)
            exit(0)
        }
    }
}

// Default behavior: run as app with URL event handling
let config = Config.loadFromFile()
logMessage("Starting BrowserSchedule as native Swift app", config: config)

let app = NSApplication.shared
let delegate = URLAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.prohibited) // Background app
app.run()