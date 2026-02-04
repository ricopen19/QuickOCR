// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QuickOCR",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "QuickOCR",
            path: "Sources/QuickOCR"
        ),
        .executableTarget(
            name: "QuickOCRApp",
            dependencies: ["QuickOCR"],
            path: "Sources/QuickOCRApp"
        ),
        .testTarget(
            name: "QuickOCRTests",
            dependencies: ["QuickOCR"],
            path: "Tests/QuickOCRTests"
        )
    ]
)
