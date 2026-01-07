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
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui.git", from: "2.0.0"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.2"),
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0")
    ],
    targets: [
        .executableTarget(
            name: "vaizor",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                .product(name: "GRDB", package: "GRDB.swift"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
                .product(name: "ZIPFoundation", package: "ZIPFoundation")
            ],
            path: "Sources/vaizor",
            resources: [
                .process("../../Resources")
            ],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-warn-concurrency"], .when(configuration: .debug))
            ]
        )
    ]
)
