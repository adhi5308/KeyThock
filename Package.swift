// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Haptyk",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Haptyk", targets: ["Haptyk"])
    ],
    targets: [
        .executableTarget(name: "Haptyk")
    ]
)
