// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GorgeeKit",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "GorgeeCore", targets: ["GorgeeCore"]),
    ],
    targets: [
        .target(name: "GorgeeCore"),
        .testTarget(name: "GorgeeCoreTests", dependencies: ["GorgeeCore"]),
    ]
)
