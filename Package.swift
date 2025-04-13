// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Backdoor",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        // Define as an executable app target, not a library
        .executable(
            name: "Backdoor",
            targets: ["Backdoor"])
    ],
    dependencies: [
        // UI and Image handling
        .package(url: "https://github.com/kean/Nuke.git", from: "12.7.0"),
        .package(url: "https://github.com/sparrowcode/AlertKit.git", from: "5.1.9"),
        
        // Onboarding
        .package(url: "https://github.com/khcrysalis/UIOnboarding-18.git", branch: "main"),

        // File and Archive Management
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19"),
        .package(url: "https://github.com/tsolomko/SWCompression.git", from: "4.8.6"),
        
        // Security
        .package(url: "https://github.com/HAHALOSAH/OpenSSL-Swift-Package.git", branch: "main"),

        // Server-side components
        .package(url: "https://github.com/vapor/vapor.git", from: "4.104.0")
    ],
    targets: [
        // Define as an executable target since this is an app, not a library
        .executableTarget(
            name: "Backdoor",
            dependencies: [
                // UI and Image handling
                .product(name: "Nuke", package: "Nuke"),
                .product(name: "NukeUI", package: "Nuke"),
                .product(name: "NukeExtensions", package: "Nuke"),
                .product(name: "NukeVideo", package: "Nuke"),
                .product(name: "AlertKit", package: "AlertKit"),
                
                // Onboarding
                .product(name: "UIOnboarding", package: "UIOnboarding-18"),
                
                // File Management
                .product(name: "ZIPFoundation", package: "ZIPFoundation"),
                .product(name: "SWCompression", package: "SWCompression"),
                
                // Security
                .product(name: "OpenSSL", package: "OpenSSL-Swift-Package"),

                // Server-side components
                .product(name: "Vapor", package: "vapor")
            ],
            path: ".",
            exclude: [
                // Project files
                "backdoor.xcodeproj",
                "backdoor.xcworkspace",

                // Documentation
                "FAQ.md",
                "CODE_OF_CONDUCT.md",

                // Tools and scripts
                "scripts",
                "Makefile",
                "Clean",
                "app-repo.json",
                
                // Mixed language source files - handled specially
                "Shared/Magic/openssl_tools.mm",
                "Shared/Magic/openssl_tools.hpp",
                "Shared/Magic/zsign",

                // Backup and temporary files
                ".project_backup",
                "Project.swift"
            ],
            swiftSettings: [
                // Debug optimization settings
                .define("DEBUG", .when(configuration: .debug)),
                .unsafeFlags(["-Onone"], .when(configuration: .debug)),
                
                // Release optimization settings
                .define("RELEASE", .when(configuration: .release)),
                .unsafeFlags(["-O"], .when(configuration: .release))
            ]
        )
    ],
    swiftLanguageVersions: [.v5]
)