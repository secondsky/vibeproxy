// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CLIProxyMenuBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "CLIProxyMenuBar",
            targets: ["CLIProxyMenuBar"]
        )
    ],
    targets: [
        .executableTarget(
            name: "CLIProxyMenuBar",
            path: "Sources",
            resources: [
                .copy("Resources")
            ]
        )
    ]
)
