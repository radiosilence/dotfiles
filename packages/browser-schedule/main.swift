import AppKit
import CoreServices
import Foundation
import os.log

// Configuration struct with native JSON parsing
struct Config: Codable {
  let workBrowser: String
  let personalBrowser: String
  let workStartHour: Int
  let workEndHour: Int
  let workDays: String
  let logEnabled: Bool

  enum CodingKeys: String, CodingKey {
    case workBrowser = "work_browser"
    case personalBrowser = "personal_browser"
    case workStartHour = "work_start_hour"
    case workEndHour = "work_end_hour"
    case workDays = "work_days"
    case logEnabled = "log_enabled"
  }

  init(
    workBrowser: String = "Google Chrome", personalBrowser: String = "Zen", workStartHour: Int = 9,
    workEndHour: Int = 18, workDays: String = "1-5", logEnabled: Bool = false
  ) {
    self.workBrowser = workBrowser
    self.personalBrowser = personalBrowser
    self.workStartHour = workStartHour
    self.workEndHour = workEndHour
    self.workDays = workDays
    self.logEnabled = logEnabled
  }

  static func loadFromFile() -> Config {
    let homeDir = FileManager.default.homeDirectoryForCurrentUser
    let configPath = homeDir.appendingPathComponent(".config/browser-schedule/config.json")

    guard let configData = try? Data(contentsOf: configPath) else {
      let defaults = Config()
      print("Config file not found at \(configPath.path), using defaults")
      if defaults.logEnabled { logger.info("Config file not found, using defaults") }
      return defaults
    }

    do {
      let config = try JSONDecoder().decode(Config.self, from: configData)
      // Config loaded successfully
      print("Loaded config from \(configPath.path)")
      if config.logEnabled { logger.info("Loaded config from \(configPath.path)") }
      return config
    } catch {
      let defaults = Config()
      print("Error parsing config file at \(configPath.path): \(error), using defaults")
      if defaults.logEnabled {
        logger.error("Error parsing config file: \(error.localizedDescription)")
      }
      return defaults
    }
  }
}

let logger = Logger(subsystem: "com.radiosilence.browser-schedule", category: "main")

func isWorkTime(config: Config) -> Bool {
  let now = Date()
  let calendar = Calendar.current
  let hour = calendar.component(.hour, from: now)
  let weekday = calendar.component(.weekday, from: now)  // 1=Sunday, 2=Monday, etc.

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

  let dayCheckMsg =
    "Day check: weekday=\(cronWeekday), workDays=\(config.workDays), isWorkDay=\(isWorkDay)"
  print(dayCheckMsg)
  if config.logEnabled { logger.info("\(dayCheckMsg)") }

  if !isWorkDay {
    return false
  }

  return hour >= config.workStartHour && hour < config.workEndHour
}

func openURL(_ urlString: String, config: Config) {
  let targetBrowser = isWorkTime(config: config) ? config.workBrowser : config.personalBrowser
  let timeString = DateFormatter()
  timeString.dateFormat = "HH:mm"

  let openMsg = "Opening \(urlString) in \(targetBrowser) (\(timeString.string(from: Date())))"
  print(openMsg)
  if config.logEnabled { logger.info("\(openMsg)") }

  let task = Process()
  task.launchPath = "/usr/bin/open"
  task.arguments = ["-a", targetBrowser, urlString]

  do {
    try task.run()
    task.waitUntilExit()
    if task.terminationStatus == 0 {
      let successMsg = "Successfully opened \(urlString) in \(targetBrowser)"
      print(successMsg)
      if config.logEnabled { logger.info("\(successMsg)") }
    } else {
      let errorMsg = "Error opening \(urlString): exit code \(task.terminationStatus)"
      print(errorMsg)
      if config.logEnabled { logger.error("\(errorMsg)") }
    }
  } catch {
    let errorMsg = "Error opening \(urlString): \(error)"
    print(errorMsg)
    if config.logEnabled { logger.error("\(errorMsg)") }
  }
}

// Custom Application Delegate
class URLAppDelegate: NSObject, NSApplicationDelegate {
  let config = Config.loadFromFile()

  func applicationDidFinishLaunching(_ notification: Notification) {
    print("BrowserSchedule app finished launching and ready for URL events")
    if config.logEnabled { logger.info("App finished launching and ready for URL events") }

    // Set up timeout to exit if no URLs received within 5 seconds
    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
      print("Timeout reached (5s), no URLs received, exiting")
      if self.config.logEnabled { logger.info("Timeout reached, no URLs received, exiting") }
      NSApplication.shared.terminate(nil)
    }
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    print("Received \(urls.count) URLs from macOS via Swift delegate")
    if config.logEnabled {
      logger.info("Received \(urls.count) URLs from macOS via Swift delegate")
    }

    for url in urls {
      let urlString = url.absoluteString
      print("Processing URL from Swift delegate: \(urlString)")
      if config.logEnabled { logger.info("Processing URL from Swift delegate: \(urlString)") }
      openURL(urlString, config: config)
    }

    print("URLs processed via Swift delegate, exiting")
    if config.logEnabled { logger.info("URLs processed via Swift delegate, exiting") }
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
    print("  Logging: \(config.logEnabled ? "enabled (unified logging)" : "disabled")")
    if config.logEnabled {
      print(
        "  View logs: log show --predicate 'subsystem == \"com.radiosilence.browser-schedule\"' --last 1h"
      )
    }
    let homeDir = FileManager.default.homeDirectoryForCurrentUser
    let configPath = homeDir.appendingPathComponent(".config/browser-schedule/config.json")
    print("  Config file: \(configPath.path)")
    if isWorkTime(config: config) {
      print("  Current: Work time - using \(config.workBrowser)")
    } else {
      print("  Current: Personal time - using \(config.personalBrowser)")
    }
    exit(0)

  case "--set-default":
    let bundleId = "com.radiosilence.browser-schedule"

    // Register the app bundle first
    let registerTask = Process()
    registerTask.launchPath =
      "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
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
      print("Received URL from macOS via command line: \(arg)")
      if config.logEnabled { logger.info("Received URL from macOS via command line: \(arg)") }
      openURL(arg, config: config)
      exit(0)
    }
  }
}

// Default behavior: run as app with URL event handling
let config = Config.loadFromFile()
print("Starting BrowserSchedule as native Swift app")
if config.logEnabled { logger.info("Starting BrowserSchedule as native Swift app") }

let app = NSApplication.shared
let delegate = URLAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.prohibited)  // Background app
app.run()
