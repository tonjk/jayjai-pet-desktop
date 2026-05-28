// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "JayJaiPetDesktop",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "JayJaiPetDesktop"
        )
    ]
)
