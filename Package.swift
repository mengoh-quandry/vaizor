// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "vaizor",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "vaizor",
            targets: ["vaizor"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui.git", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "vaizor",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui")
            ],
            path: "Sources/vaizor",
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-warn-concurrency"], .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "vaizorTests",
            dependencies: ["vaizor"],
            path: "Tests/vaizorTests"
        )
    ]
)
