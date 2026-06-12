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
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.3")
    ],
    targets: [
        .executableTarget(
            name: "MacVerce",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "Sources/MacVerce",
            linkerSettings: [
                .linkedFramework("Security"),
                .linkedFramework("ServiceManagement"),
                .unsafeFlags([
                    "-Xlinker", "-rpath",
                    "-Xlinker", "@executable_path/../Frameworks"
                ])
            ]
        )
    ]
)
