// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KelimeCore",
    defaultLocalization: "tr",
    platforms: [
        .iOS(.v17),
        // macOS is only here so `swift test` can run the logic tests on the build Mac.
        .macOS(.v14),
    ],
    products: [
        .library(name: "KelimeCore", targets: ["KelimeCore"]),
        .library(name: "KelimeUI", targets: ["KelimeUI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.9.0"),
    ],
    targets: [
        .target(
            name: "KelimeCore",
            dependencies: [.product(name: "GRDB", package: "GRDB.swift")]
        ),
        .target(
            name: "KelimeUI",
            dependencies: ["KelimeCore"]
        ),
        .testTarget(
            name: "KelimeCoreTests",
            dependencies: ["KelimeCore"]
        ),
        .testTarget(
            name: "KelimeUITests",
            dependencies: ["KelimeUI"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
