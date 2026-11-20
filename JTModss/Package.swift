// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "HNMod",

    platforms: [
        .iOS(.v13)
    ],

    products: [
        .library(
            name: "HNMod",
            type: .dynamic,
            targets: ["HNMod"]
        )
    ],

    targets: [
        .target(
            name: "HNModBootstrap",
            path: "HNModBootstrap",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("UIKit")
            ]
        ),

        .target(
            name: "HNMod",
            dependencies: ["HNModBootstrap"],
            path: "iOS_Mod"
        )
    ]
)