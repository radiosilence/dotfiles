import AppKit
import CoreServices
import Foundation
import os.log

// Configuration struct with native JSON parsing
struct Config: Codable {
  let browsers: Browsers
  let overrideDomains: OverrideDomains?
  let workTime: WorkTime
  let workDays: WorkDays
  let logEnabled: Bool
  
  struct Browsers: Codable {
    let work: String
    let personal: String
  }
  
  struct OverrideDomains: Codable {
    let personal: [String]?
    let work: [String]?
  }
  
  struct WorkTime: Codable {
    let start: String
    let end: String
  }
  
  struct WorkDays: Codable {
    let start: String
    let end: String
  }

  enum CodingKeys: String, CodingKey {
    case browsers
    case overrideDomains = "override_domains"
    case workTime = "work_time"
    case workDays = "work_days"
    case logEnabled = "log_enabled"
  }

  init(
    browsers: Browsers = Browsers(work: "Google Chrome", personal: "Zen"),
    overrideDomains: OverrideDomains? = nil,
    workTime: WorkTime = WorkTime(start: "9:00", end: "18:00"),
    workDays: WorkDays = WorkDays(start: "Mon", end: "Fri"),
    logEnabled: Bool = false
  ) {
    self.browsers = browsers
    self.overrideDomains = overrideDomains
    self.workTime = workTime
    self.workDays = workDays
    self.logEnabled = logEnabled
  }

  static func loadFromFile() -> Config {
    let homeDir = FileManager.default.homeDirectoryForCurrentUser
    let configPath = homeDir.appendingPathComponent(".config/browser-schedule/config.json")

    guard let configData = try? Data(contentsOf: configPath) else {
      let defaults = Config()
      if defaults.logEnabled {
        logger.info("Config file not found at \(configPath.path), using defaults")
      } else {
        print("Config file not found at \(configPath.path), using defaults")
      }
      return defaults
    }

    do {
      let config = try JSONDecoder().decode(Config.self, from: configData)
      // Config loaded successfully
      if config.logEnabled {
        logger.info("Loaded config from \(configPath.path)")
      } else {
        print("Loaded config from \(configPath.path)")
      }
      return config
    } catch {
      let defaults = Config()
      if defaults.logEnabled {
        logger.error("Error parsing config file at \(configPath.path): \(error.localizedDescription)")
      } else {
        print("Error parsing config file at \(configPath.path): \(error), using defaults")
      }
      return defaults
    }
  }
}

let logger = Logger(subsystem: "com.radiosilence.browser-schedule", category: "main")

func parseTime(_ timeString: String) -> Int {
  let components = timeString.split(separator: ":").map { String($0) }
  return Int(components[0]) ?? 0
}

func dayNameToWeekday(_ dayName: String) -> Int {
  let days = ["Sun": 1, "Mon": 2, "Tue": 3, "Wed": 4, "Thu": 5, "Fri": 6, "Sat": 7]
  return days[dayName] ?? 1
}

func isWorkTime(config: Config) -> Bool {
  let now = Date()
  let calendar = Calendar.current
  let hour = calendar.component(.hour, from: now)
  let weekday = calendar.component(.weekday, from: now)  // 1=Sunday, 2=Monday, etc.

  // Parse work time
  let startHour = parseTime(config.workTime.start)
  let endHour = parseTime(config.workTime.end)
  
  // Parse work days
  let startWeekday = dayNameToWeekday(config.workDays.start)
  let endWeekday = dayNameToWeekday(config.workDays.end)
  
  // Check if current day is within work days range
  let isWorkDay = weekday >= startWeekday && weekday <= endWeekday

  let dayCheckMsg = "Day check: weekday=\(weekday), workDays=\(config.workDays.start)-\(config.workDays.end), isWorkDay=\(isWorkDay)"
  if config.logEnabled {
    logger.debug("\(dayCheckMsg)")
  }

  if !isWorkDay {
    return false
  }

  return hour >= startHour && hour < endHour
}

func getBrowserForURL(_ urlString: String, config: Config) -> String {
  // Check domain overrides first
  if let overrides = config.overrideDomains {
    if let url = URL(string: urlString), let host = url.host {
      // Check personal overrides
      if let personalDomains = overrides.personal {
        for domain in personalDomains {
          if host.contains(domain) {
            return config.browsers.personal
          }
        }
      }
      
      // Check work overrides
      if let workDomains = overrides.work {
        for domain in workDomains {
          if host.contains(domain) {
            return config.browsers.work
          }
        }
      }
    }
  }
  
  // Fall back to time-based selection
  return isWorkTime(config: config) ? config.browsers.work : config.browsers.personal
}

func openURL(_ urlString: String, config: Config) {
  let targetBrowser = getBrowserForURL(urlString, config: config)
  let timeString = DateFormatter()
  timeString.dateFormat = "HH:mm"

  let openMsg = "Opening \(urlString) in \(targetBrowser) (\(timeString.string(from: Date())))"
  if config.logEnabled {
    logger.info("\(openMsg)")
  } else {
    print(openMsg)
  }

  let task = Process()
  task.launchPath = "/usr/bin/open"
  task.arguments = ["-a", targetBrowser, urlString]

  do {
    try task.run()
    task.waitUntilExit()
    if task.terminationStatus == 0 {
      let successMsg = "Successfully opened \(urlString) in \(targetBrowser)"
      if config.logEnabled {
        logger.info("\(successMsg)")
      } else {
        print(successMsg)
      }
    } else {
      let errorMsg = "Error opening \(urlString): exit code \(task.terminationStatus)"
      if config.logEnabled {
        logger.error("\(errorMsg)")
      } else {
        print(errorMsg)
      }
    }
  } catch {
    let errorMsg = "Error opening \(urlString): \(error)"
    if config.logEnabled {
      logger.error("\(errorMsg)")
    } else {
      print(errorMsg)
    }
  }
}

// Custom Application Delegate
class URLAppDelegate: NSObject, NSApplicationDelegate {
  let config = Config.loadFromFile()

  func applicationDidFinishLaunching(_ notification: Notification) {
    if config.logEnabled {
      logger.info("BrowserSchedule app finished launching and ready for URL events")
    }

    // Set up timeout to exit if no URLs received within 5 seconds
    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
      if self.config.logEnabled {
        logger.info("Timeout reached (5s), no URLs received, exiting")
      }
      NSApplication.shared.terminate(nil)
    }
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    if config.logEnabled {
      logger.info("Received \(urls.count) URLs from macOS via Swift delegate")
    }

    for url in urls {
      let urlString = url.absoluteString
      if config.logEnabled {
        logger.info("Processing URL from Swift delegate: \(urlString)")
      }
      openURL(urlString, config: config)
    }

    if config.logEnabled {
      logger.info("URLs processed via Swift delegate, exiting")
    }
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
    print("  Work browser: \(config.browsers.work)")
    print("  Personal browser: \(config.browsers.personal)")
    print("  Work hours: \(config.workTime.start)-\(config.workTime.end)")
    print("  Work days: \(config.workDays.start)-\(config.workDays.end)")
    if let overrides = config.overrideDomains {
      if let personal = overrides.personal, !personal.isEmpty {
        print("  Personal overrides: \(personal.joined(separator: ", "))")
      }
      if let work = overrides.work, !work.isEmpty {
        print("  Work overrides: \(work.joined(separator: ", "))")
      }
    }
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
      print("  Current: Work time - using \(config.browsers.work)")
    } else {
      print("  Current: Personal time - using \(config.browsers.personal)")
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
      if config.logEnabled {
        logger.info("Received URL from macOS via command line: \(arg)")
      }
      openURL(arg, config: config)
      exit(0)
    }
  }
}

// Default behavior: run as app with URL event handling
let config = Config.loadFromFile()
if config.logEnabled {
  logger.info("Starting BrowserSchedule as native Swift app")
}

let app = NSApplication.shared
let delegate = URLAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.prohibited)  // Background app
app.run()
