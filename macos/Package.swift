// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "PoindexterCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "PoindexterCore", targets: ["PoindexterCore"]),
        .executable(name: "poindexter-cli", targets: ["poindexter-cli"]),
    ],
    targets: [
        .target(name: "PoindexterCore"),
        .executableTarget(name: "poindexter-cli", dependencies: ["PoindexterCore"]),
        // Generates the app icon (scripts/app-icon.sh); not shipped in the app.
        .executableTarget(name: "make-icon"),
        .testTarget(name: "PoindexterCoreTests", dependencies: ["PoindexterCore"]),
    ]
)
