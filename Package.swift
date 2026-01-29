// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "pi-terminal-notifier",
    platforms: [
        .macOS(.v10_15)
    ],
    products: [
        .executable(name: "pi-terminal-notifier", targets: ["TerminalNotifier"])
    ],
    targets: [
        .executableTarget(
            name: "TerminalNotifier",
            path: "Sources"
        )
    ]
)