import ProjectDescription

let project = Project(
    name: "backdoor",
    organizationName: "Your Organization",
    packages: [
        .local(path: ".")  // Using your local Package.swift
    ],
    settings: .settings(
        base: ["DEVELOPMENT_TEAM": "YOUR_TEAM_ID"],
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release")
        ]
    ),
    targets: [
        .target(
            name: "backdoor",
            platform: .iOS,
            product: .app,
            bundleId: "com.yourorganization.backdoor",
            deploymentTarget: .iOS(targetVersion: "15.0", devices: [.iphone, .ipad]),
            infoPlist: .file(path: "iOS/Info.plist"),
            sources: ["iOS/**"],
            resources: ["iOS/Resources/**"],
            entitlements: "iOS/backdoor.entitlements",
            scripts: [
                // Add any build scripts you need here
            ],
            dependencies: [
                // Reference all the package products you need
                .package(product: "Nuke"),
                .package(product: "NukeUI"),
                .package(product: "NukeExtensions"),
                .package(product: "NukeVideo"),
                .package(product: "UIOnboarding"),
                .package(product: "AlertKit"),
                .package(product: "ZIPFoundation"),
                .package(product: "SWCompression"),
                .package(product: "BitByteData"),
                .package(product: "Vapor"),
                .package(product: "CryptoSwift"),
                .package(product: "SnapKit"),
                .package(product: "Lottie"),
                .package(product: "Moya"),
                .package(product: "RswiftLibrary"),
                .package(product: "SSNaturalLanguage"),
                .package(product: "NIO"),
                .package(product: "NIOTransportServices"),
                .package(product: "Logging"),
                .package(product: "Algorithms"),
                .package(product: "Collections"),
                // Add any other dependencies from your Package.swift
            ]
        )
    ],
    schemes: [
        .scheme(
            name: "backdoor (Debug)",
            shared: true,
            buildAction: .buildAction(targets: ["backdoor"]),
            testAction: .targets([]),
            runAction: .runAction(configuration: "Debug"),
            archiveAction: .archiveAction(configuration: "Debug")
        ),
        .scheme(
            name: "backdoor (Release)",
            shared: true,
            buildAction: .buildAction(targets: ["backdoor"]),
            testAction: .targets([]),
            runAction: .runAction(configuration: "Release"),
            archiveAction: .archiveAction(configuration: "Release")
        )
    ]
)