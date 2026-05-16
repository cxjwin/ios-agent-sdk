// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "iOSAgentSDK",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "iOSAgentSDK", targets: ["iOSAgentSDK"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "iOSAgentSDK",
            path: "Sources/iOSAgentSDK"
        ),
        .executableTarget(
            name: "MockSmokeTest",
            dependencies: ["iOSAgentSDK"],
            path: "Examples/MockSmokeTest"
        ),
        .executableTarget(
            name: "RealAnthropic",
            dependencies: ["iOSAgentSDK"],
            path: "Examples/RealAnthropic"
        ),
    ]
)
