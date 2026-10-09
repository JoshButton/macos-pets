// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "macos-pets",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MacOSPetsKit", targets: ["MacOSPetsKit"]),
        .executable(name: "macos-pets", targets: ["macos-pets"]),
    ],
    targets: [
        .target(
            name: "MacOSPetsKit",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "macos-pets",
            dependencies: ["MacOSPetsKit"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)