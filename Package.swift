// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NoType",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NoType", targets: ["NoType"]),
    ],
    targets: [
        .executableTarget(
            name: "NoType",
            path: "NoType",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "NoTypeTests",
            dependencies: ["NoType"],
            path: "NoTypeTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
