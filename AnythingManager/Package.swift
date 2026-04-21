// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AnythingManager",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "AnythingManager", targets: ["AnythingManager"])
    ],
    targets: [
        .executableTarget(
            name: "AnythingManager",
            swiftSettings: [.unsafeFlags(["-parse-as-library"])]
        )
    ]
)
