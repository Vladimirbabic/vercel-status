// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacVerce",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "MacVerce", targets: ["MacVerce"])
    ],
    targets: [
        .executableTarget(
            name: "MacVerce",
            path: "Sources/MacVerce",
            linkerSettings: [
                .linkedFramework("Security"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
