// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "{{SDK_SLUG}}-swift",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(
            name: "SdkTpl",
            targets: ["SdkTpl"]
        ),
    ],
    targets: [
        .target(
            name: "SdkTpl",
            path: "Sources/SdkTpl"
        ),
        .testTarget(
            name: "SdkTplTests",
            dependencies: ["SdkTpl"],
            path: "Tests/SdkTplTests"
        ),
    ]
)
