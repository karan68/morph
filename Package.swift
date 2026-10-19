// swift-tools-version:5.9
import PackageDescription

// Morph — zero-click offline file converter for macOS (M1 scope, see docs/spec/README.md §4.2).
// Pure-logic targets (Capabilities, Jobs, Engines' Foundation-only files, DragKit geometry)
// also build on Linux so their unit tests can run on the Tokyo VM.

var targets: [Target] = [
    .target(name: "Capabilities", path: "Sources/Capabilities"),
    .target(name: "Jobs", dependencies: ["Capabilities"], path: "Sources/Jobs"),
    .target(name: "Engines", dependencies: ["Capabilities", "Jobs"], path: "Sources/Engines"),
    .target(name: "DragKit", dependencies: ["Capabilities", "A11y"], path: "Sources/DragKit"),
    .target(name: "A11y", path: "Sources/A11y"),
    .testTarget(name: "CoreTests", dependencies: ["Capabilities", "Jobs", "Engines", "DragKit"], path: "Tests/CoreTests"),
]

#if os(macOS)
targets += [
    .target(name: "ToolWindows", dependencies: ["Engines", "Jobs", "A11y"], path: "Sources/ToolWindows"),
    .executableTarget(
        name: "MorphApp",
        dependencies: ["Capabilities", "Jobs", "Engines", "DragKit", "ToolWindows", "A11y"],
        path: "Sources/MorphApp",
        linkerSettings: [.linkedFramework("Carbon")]
    ),
    .executableTarget(name: "MorphCLI", dependencies: ["Capabilities", "Jobs", "Engines"], path: "Sources/MorphCLI"),
    .testTarget(name: "EngineTests", dependencies: ["Engines", "Jobs", "Capabilities"], path: "Tests/EngineTests"),
]
#endif

let package = Package(
    name: "Morph",
    platforms: [.macOS(.v13)],
    targets: targets
)
