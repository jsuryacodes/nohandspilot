// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Pilot",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "PilotBrain"),
        .executableTarget(name: "Pilot", dependencies: ["PilotBrain"]),
        .executableTarget(name: "BrainCheck", dependencies: ["PilotBrain"]),
    ]
)
