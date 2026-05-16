// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "iOSAgentSDK",
    platforms: [
        .iOS(.v18),
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
        .testTarget(
            name: "iOSAgentSDKTests",
            dependencies: ["iOSAgentSDK"],
            path: "Tests/iOSAgentSDKTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
