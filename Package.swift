// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MacCat",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.6")
    ],
    targets: [
        .executableTarget(
            name: "MacCat",
            dependencies: [.product(name: "Sparkle", package: "Sparkle")],
            resources: [.copy("Resources/Cats"), .copy("Resources/PawCorrections")],
            linkerSettings: [.unsafeFlags([
                "-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks",
                "-Xlinker", "-rpath", "-Xlinker", "@executable_path"
            ])]
        ),
        .testTarget(name: "MacCatTests", dependencies: ["MacCat"])
    ]
)
