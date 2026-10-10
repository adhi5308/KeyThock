// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeyThock",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "KeyThock", targets: ["KeyThock"])
    ],
    targets: [
        .executableTarget(name: "KeyThock")
    ]
)
