import AppKit
import CoreServices
import Foundation
import os.log
import TOMLKit

// Configuration struct with TOML parsing
struct Config: Codable {
  let browsers: Browsers
  let urls: OverrideUrls?
  let workTime: WorkTime
  let workDays: WorkDays
  let log: Log?
  
  struct Browsers: Codable {
    let work: String
    let personal: String
  }
  
  struct OverrideUrls: Codable {
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
  
  struct Log: Codable {
    let enabled: Bool
  }

  enum CodingKeys: String, CodingKey {
    case browsers
    case urls
    case workTime = "work_time"
    case workDays = "work_days"
    case log
  }

  init(
    browsers: Browsers = Browsers(work: "Google Chrome", personal: "Zen"),
    urls: OverrideUrls? = nil,
    workTime: WorkTime = WorkTime(start: "9:00", end: "18:00"),
    workDays: WorkDays = WorkDays(start: "Mon", end: "Fri"),
    log: Log? = nil
  ) {
    self.browsers = browsers
    self.urls = urls
    self.workTime = workTime
    self.workDays = workDays
    self.log = log
  }

  static func loadFromFile() -> Config {
    let homeDir = FileManager.default.homeDirectoryForCurrentUser
    let configPath = homeDir.appendingPathComponent(".config/browser-schedule/config.toml")
    let localConfigPath = homeDir.appendingPathComponent(".config/browser-schedule/config.local.toml")

    // Load main config
    guard let configData = try? String(contentsOf: configPath) else {
      let defaults = Config()
      if isLoggingEnabled(defaults) {
        logger.info("Config file not found at \(configPath.path), using defaults")
      } else {
        print("Config file not found at \(configPath.path), using defaults")
      }
      return defaults
    }

    do {
      let tomlTable = try TOMLTable(string: configData)
      var config = try TOMLDecoder().decode(Config.self, from: tomlTable)
      
      // Try to load and merge local config
      if let localConfigData = try? String(contentsOf: localConfigPath) {
        do {
          let localTomlTable = try TOMLTable(string: localConfigData)
          let localConfig = try TOMLDecoder().decode(LocalConfig.self, from: localTomlTable)
          config = mergeConfigs(base: config, local: localConfig)
          if isLoggingEnabled(config) {
            logger.info("Loaded config from \(configPath.path) and merged \(localConfigPath.path)")
          } else {
            print("Loaded config from \(configPath.path) and merged \(localConfigPath.path)")
          }
        } catch {
          if isLoggingEnabled(config) {
            logger.error("Error parsing local config file at \(localConfigPath.path): \(error.localizedDescription)")
          } else {
            print("Error parsing local config file at \(localConfigPath.path): \(error)")
          }
        }
      } else {
        if isLoggingEnabled(config) {
          logger.info("Loaded config from \(configPath.path)")
        } else {
          print("Loaded config from \(configPath.path)")
        }
      }
      
      return config
    } catch {
      let defaults = Config()
      if isLoggingEnabled(defaults) {
        logger.error("Error parsing config file at \(configPath.path): \(error.localizedDescription)")
      } else {
        print("Error parsing config file at \(configPath.path): \(error), using defaults")
      }
      return defaults
    }
  }
  
  static func mergeConfigs(base: Config, local: LocalConfig) -> Config {
    // Merge override domains
    var mergedPersonalDomains: [String] = []
    var mergedWorkDomains: [String] = []
    
    // Add base config domains
    if let baseOverrides = base.urls {
      if let personal = baseOverrides.personal {
        mergedPersonalDomains.append(contentsOf: personal)
      }
      if let work = baseOverrides.work {
        mergedWorkDomains.append(contentsOf: work)
      }
    }
    
    // Add local config domains
    if let localOverrides = local.urls {
      if let personal = localOverrides.personal {
        mergedPersonalDomains.append(contentsOf: personal)
      }
      if let work = localOverrides.work {
        mergedWorkDomains.append(contentsOf: work)
      }
    }
    
    let mergedOverrides = OverrideUrls(
      personal: mergedPersonalDomains.isEmpty ? nil : mergedPersonalDomains,
      work: mergedWorkDomains.isEmpty ? nil : mergedWorkDomains
    )
    
    return Config(
      browsers: local.browsers ?? base.browsers, // Local takes precedence for browsers
      urls: mergedOverrides,
      workTime: local.workTime ?? base.workTime, // Local takes precedence for work time
      workDays: local.workDays ?? base.workDays, // Local takes precedence for work days  
      log: local.log ?? base.log // Local takes precedence for logging
    )
  }
}

let logger = Logger(subsystem: "com.radiosilence.browser-schedule", category: "main")

func isLoggingEnabled(_ config: Config) -> Bool {
  return config.log?.enabled ?? false
}

func parseTime(_ timeString: String) -> Int? {
  let components = timeString.split(separator: ":").map { String($0) }
  guard components.count == 2, let hour = Int(components[0]), hour >= 0, hour <= 23,
        let minute = Int(components[1]), minute >= 0, minute <= 59 else {
    return nil
  }
  return hour
}

func dayNameToWeekday(_ dayName: String) -> Int? {
  let days = ["Sun": 1, "Mon": 2, "Tue": 3, "Wed": 4, "Thu": 5, "Fri": 6, "Sat": 7]
  return days[dayName]
}

struct ConfigValidation {
  let isValid: Bool
  let errors: [String]
  
  static func validate(_ config: Config) -> ConfigValidation {
    var errors: [String] = []
    
    // Validate work time
    if parseTime(config.workTime.start) == nil {
      errors.append("Invalid work start time: \(config.workTime.start) (use HH:MM format)")
    }
    if parseTime(config.workTime.end) == nil {
      errors.append("Invalid work end time: \(config.workTime.end) (use HH:MM format)")
    }
    
    // Validate work days
    if dayNameToWeekday(config.workDays.start) == nil {
      errors.append("Invalid work start day: \(config.workDays.start) (use Sun,Mon,Tue,Wed,Thu,Fri,Sat)")
    }
    if dayNameToWeekday(config.workDays.end) == nil {
      errors.append("Invalid work end day: \(config.workDays.end) (use Sun,Mon,Tue,Wed,Thu,Fri,Sat)")
    }
    
    // Validate day range makes sense
    if let startDay = dayNameToWeekday(config.workDays.start),
       let endDay = dayNameToWeekday(config.workDays.end),
       startDay > endDay {
      errors.append("Work day range invalid: \(config.workDays.start) is after \(config.workDays.end)")
    }
    
    // Note: We allow inverse time ranges for night shifts (e.g., 18:00-9:00)
    // No validation needed for time range order
    
    return ConfigValidation(isValid: errors.isEmpty, errors: errors)
  }
}

func isWorkTime(config: Config) -> Bool {
  let validation = ConfigValidation.validate(config)
  if !validation.isValid {
    // Config is invalid, default to personal browser
    return false
  }
  
  let now = Date()
  let calendar = Calendar.current
  let hour = calendar.component(.hour, from: now)
  let weekday = calendar.component(.weekday, from: now)  // 1=Sunday, 2=Monday, etc.

  // Parse work time (we know these are valid from validation)
  let startHour = parseTime(config.workTime.start)!
  let endHour = parseTime(config.workTime.end)!
  
  // Parse work days (we know these are valid from validation)
  let startWeekday = dayNameToWeekday(config.workDays.start)!
  let endWeekday = dayNameToWeekday(config.workDays.end)!
  
  // Check if current day is within work days range
  let isWorkDay = weekday >= startWeekday && weekday <= endWeekday
  
  // Handle time ranges (including night shifts that span midnight)
  let isWorkHour: Bool
  if startHour < endHour {
    // Normal day shift (e.g., 9:00-18:00)
    isWorkHour = hour >= startHour && hour < endHour
  } else {
    // Night shift spanning midnight (e.g., 18:00-9:00)
    isWorkHour = hour >= startHour || hour < endHour
  }

  let shiftType = startHour < endHour ? "day" : "night"
  let dayCheckMsg = "\(shiftType) shift check: weekday=\(weekday), workDays=\(config.workDays.start)-\(config.workDays.end), hour=\(hour), workHours=\(config.workTime.start)-\(config.workTime.end), isWorkDay=\(isWorkDay), isWorkHour=\(isWorkHour)"
  if isLoggingEnabled(config) {
    logger.debug("\(dayCheckMsg)")
  }

  return isWorkDay && isWorkHour
}

func getBrowserForURL(_ urlString: String, config: Config) -> String {
  guard URL(string: urlString) != nil else {
    // Fall back to time-based selection if URL parsing fails
    return isWorkTime(config: config) ? config.browsers.work : config.browsers.personal
  }
  
  // Check URL fragment overrides (already merged from config + local)
  if let overrides = config.urls {
    // Check personal overrides first
    if let personalFragments = overrides.personal {
      for fragment in personalFragments {
        if urlString.contains(fragment) {
          return config.browsers.personal
        }
      }
    }
    
    // Check work overrides
    if let workFragments = overrides.work {
      for fragment in workFragments {
        if urlString.contains(fragment) {
          return config.browsers.work
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
  if isLoggingEnabled(config) {
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
      if isLoggingEnabled(config) {
        logger.info("\(successMsg)")
      } else {
        print(successMsg)
      }
    } else {
      let errorMsg = "Error opening \(urlString): exit code \(task.terminationStatus)"
      if isLoggingEnabled(config) {
        logger.error("\(errorMsg)")
      } else {
        print(errorMsg)
      }
    }
  } catch {
    let errorMsg = "Error opening \(urlString): \(error)"
    if isLoggingEnabled(config) {
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
    if isLoggingEnabled(config) {
      logger.info("BrowserSchedule app finished launching and ready for URL events")
    }

    // Set up timeout to exit if no URLs received within 5 seconds
    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
      if isLoggingEnabled(self.config) {
        logger.info("Timeout reached (5s), no URLs received, exiting")
      }
      NSApplication.shared.terminate(nil)
    }
  }

  func application(_ application: NSApplication, open urls: [URL]) {
    if isLoggingEnabled(config) {
      logger.info("Received \(urls.count) URLs from macOS via Swift delegate")
    }

    for url in urls {
      let urlString = url.absoluteString
      if isLoggingEnabled(config) {
        logger.info("Processing URL from Swift delegate: \(urlString)")
      }
      openURL(urlString, config: config)
    }

    if isLoggingEnabled(config) {
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
    let validation = ConfigValidation.validate(config)
    
    print("Current configuration:")
    print("  Work browser: \(config.browsers.work)")
    print("  Personal browser: \(config.browsers.personal)")
    let startHour = parseTime(config.workTime.start) ?? 0
    let endHour = parseTime(config.workTime.end) ?? 0
    let shiftType = startHour < endHour ? "" : " (night shift)"
    print("  Work hours: \(config.workTime.start)-\(config.workTime.end)\(shiftType)")
    print("  Work days: \(config.workDays.start)-\(config.workDays.end)")
    // Show merged domain overrides
    if let overrides = config.urls {
      if let personal = overrides.personal, !personal.isEmpty {
        print("  Personal overrides: \(personal.joined(separator: ", "))")
      }
      if let work = overrides.work, !work.isEmpty {
        print("  Work overrides: \(work.joined(separator: ", "))")
      }
    }
    
    print("  Logging: \(isLoggingEnabled(config) ? "enabled (unified logging)" : "disabled")")
    if isLoggingEnabled(config) {
      print(
        "  View logs: log show --predicate 'subsystem == \"com.radiosilence.browser-schedule\"' --last 1h"
      )
    }
    
    let homeDir = FileManager.default.homeDirectoryForCurrentUser
    let configPath = homeDir.appendingPathComponent(".config/browser-schedule/config.toml")
    let localConfigPath = homeDir.appendingPathComponent(".config/browser-schedule/config.local.toml")
    print("  Config file: \(configPath.path)")
    if FileManager.default.fileExists(atPath: localConfigPath.path) {
      print("  Local config: \(localConfigPath.path) (merged)")
    }
    
    if !validation.isValid {
      print("  ⚠️  Configuration errors:")
      for error in validation.errors {
        print("     - \(error)")
      }
      print("  Current: Using personal browser (\(config.browsers.personal)) due to config errors")
    } else {
      if isWorkTime(config: config) {
        print("  Current: Work time - using \(config.browsers.work)")
      } else {
        print("  Current: Personal time - using \(config.browsers.personal)")
      }
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
      if isLoggingEnabled(config) {
        logger.info("Received URL from macOS via command line: \(arg)")
      }
      openURL(arg, config: config)
      exit(0)
    }
  }
}

// Default behavior: run as app with URL event handling
let config = Config.loadFromFile()
if isLoggingEnabled(config) {
  logger.info("Starting BrowserSchedule as native Swift app")
}

let app = NSApplication.shared
let delegate = URLAppDelegate()
app.delegate = delegate
app.setActivationPolicy(.prohibited)  // Background app
app.run()

// Local config struct - all fields optional for partial overrides
struct LocalConfig: Codable {
  let browsers: Config.Browsers?
  let urls: Config.OverrideUrls?
  let workTime: Config.WorkTime?
  let workDays: Config.WorkDays?
  let log: Config.Log?
  
  enum CodingKeys: String, CodingKey {
    case browsers
    case urls
    case workTime = "work_time"
    case workDays = "work_days"
    case log
  }
}
