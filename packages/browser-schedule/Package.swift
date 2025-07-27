// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "BrowserSchedule",
    platforms: [.macOS(.v11)],
    dependencies: [
        .package(url: "https://github.com/LebJe/TOMLKit.git", from: "0.6.0")
    ],
    targets: [
        .executableTarget(
            name: "BrowserSchedule",
            dependencies: ["TOMLKit"],
            path: ".",
            exclude: ["config.template.toml", "Taskfile.yml", "browser-schedule-swift", ".gitignore"],
            sources: ["main.swift"]
        )
    ]
)