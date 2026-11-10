// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PilotLight",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "PilotLight", targets: ["PilotLight"])
    ],
    targets: [
        .executableTarget(
            name: "PilotLight",
            path: "Sources/PilotLight"
        )
    ]
)
