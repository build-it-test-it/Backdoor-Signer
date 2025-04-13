import ProjectDescription

let project = Project(
    name: "backdoor",
    organizationName: "backdoor",
    packages: [
        .local(path: ".")
    ],
    settings: .settings(
        base: [
            "IPHONEOS_DEPLOYMENT_TARGET": "15.0",
            "MARKETING_VERSION": "1.4.1",
            "CURRENT_PROJECT_VERSION": "6",
            "INFOPLIST_KEY_CFBundleDisplayName": "backdoor",
            "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.utilities",
            "INFOPLIST_KEY_NSHumanReadableCopyright": "Copyright (c) 2025 Joseph C (backdoor)",
            "SWIFT_VERSION": "5.0"
        ],
        configurations: [
            .debug(name: "Debug", settings: [
                "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
                "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "",
                "GCC_OPTIMIZATION_LEVEL": "0"
            ]),
            .release(name: "Release", settings: [
                "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "",
                "SWIFT_COMPILATION_MODE": "wholemodule"
            ])
        ]
    ),
    targets: [
        .target(
            name: "backdoor",
            platform: .iOS,
            product: .app,
            bundleId: "com.bdg.backdoor",
            deploymentTarget: .iOS("15.0"),
            infoPlist: .file(path: "iOS/Info.plist"),
            sources: ["iOS/**", "Shared/**"],
            resources: [
                "iOS/Resources/**",
                "Shared/Localizations/**/*.strings"
            ],
            headers: .headers(
                public: [],
                private: [],
                project: ["Shared/Magic/backdoor-Bridging-Header.h"]
            ),
            entitlements: "iOS/backdoor.entitlements",
            dependencies: [
                // Reference the executable target from Package.swift
                .package(product: "Backdoor"),
                
                // External dependencies from Package.swift
                .package(product: "Nuke"),
                .package(product: "NukeUI"),
                .package(product: "NukeExtensions"),
                .package(product: "NukeVideo"),
                .package(product: "UIOnboarding"),
                .package(product: "AlertKit"),
                .package(product: "ZIPFoundation"),
                .package(product: "SWCompression"),
                .package(product: "Vapor"),
                .package(product: "OpenSSL")
            ],
            settings: .settings(
                base: [
                    "SWIFT_OBJC_BRIDGING_HEADER": "Shared/Magic/backdoor-Bridging-Header.h",
                    "LIBRARY_SEARCH_PATHS": "$(inherited) $(PROJECT_DIR)/Shared/Magic $(PROJECT_DIR)/Shared/Resources",
                    "SUPPORTS_MACCATALYST": "NO",
                    "SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD": "YES",
                    "OTHER_CPLUSPLUSFLAGS[arch=*]": "$(OTHER_CFLAGS) -w -Wno-everything"
                ]
            )
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