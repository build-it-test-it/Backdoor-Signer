// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BackdoorDependencies",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v15)
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
    swiftLanguageVersions: [.v5]
)