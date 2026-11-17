// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacCat",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "MacCat", resources: [.copy("Resources/Cats"), .copy("Resources/PawCorrections")]),
        .testTarget(name: "MacCatTests", dependencies: ["MacCat"])
    ]
)
