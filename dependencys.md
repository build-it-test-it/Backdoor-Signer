# Dependencies and Usage Instructions for Your Project

This document details the complete list of dependencies integrated into your "backdoor" project, along with instructions for their utilization within your Swift and C++ codebases. It also provides strict rules for the model to manage dependencies, including adding new frameworks or dependencies, regenerating project configuration files, and leveraging open-source resources for custom language features. The model must adhere to these rules without deviation.

---

## Dependencies Overview

| # | Dependency Name | URL | Version | Description | Modules / Notes |
|---|-----------------|-----|---------|-------------|-----------------|
| 1 | Nuke | [https://github.com/kean/Nuke](https://github.com/kean/Nuke) | Up to next major from 12.7.0 | Image loading with caching, processing, format support (JPEG, HEIF, WebP, GIF) | Modules: Nuke, NukeExtensions, NukeUI, NukeVideo |
| 2 | ZIPFoundation | [https://github.com/weichsel/ZIPFoundation](https://github.com/weichsel/ZIPFoundation) | Up to next major from 0.9.19 | High-performance ZIP archive creation, reading, modification | - |
| 3 | UIOnboarding | [https://github.com/khcrysalis/UIOnboarding-18](https://github.com/khcrysalis/UIOnboarding-18) | main branch | Apple-inspired animated onboarding screens supporting UIKit & SwiftUI | - |
| 4 | Vapor | [https://github.com/vapor/vapor](https://github.com/vapor/vapor) | Up to next major from 4.104.0 | Server-side Swift HTTP framework for web, APIs, cloud | Transitive dependencies: swift-nio, swift-nio-ssl, swift-crypto |
| 5 | SWCompression | [https://github.com/tsolomko/SWCompression](https://github.com/tsolomko/SWCompression) | Up to next major from 4.8.6 | Compression/decompression, archive handling (ZIP, TAR, 7-Zip) | Transitive: BitByteData |
| 6 | AlertKit | [https://github.com/sparrowcode/AlertKit](https://github.com/sparrowcode/AlertKit) | Up to next major from 5.1.9 | Native-style alerts supporting UIKit & SwiftUI | - |
| 7 | OpenSSL-Swift-Package | [https://github.com/HAHALOSAH/OpenSSL-Swift-Package](https://github.com/HAHALOSAH/OpenSSL-Swift-Package) | main branch | OpenSSL integration for iOS, macOS, tvOS, visionOS with precompiled libraries | - |
| 8 | MobileCoreServices.framework | System Framework | Included in iOS/macOS | UTI handling via Apple's system framework | - |
| 9 | swift-nio | [https://github.com/apple/swift-nio](https://github.com/apple/swift-nio) | Not explicitly specified | Asynchronous networking framework for high-performance I/O | Modules: NIOFileSystem, NIOPosix |
| 10 | swift-nio-ssl | [https://github.com/apple/swift-nio-ssl](https://github.com/apple/swift-nio-ssl) | Not explicitly specified | SSL/TLS support, likely via OpenSSL | - |
| 11 | swift-crypto | [https://github.com/apple/swift-crypto](https://github.com/apple/swift-crypto) | Not explicitly specified | Cryptographic primitives for secure operations | - |
| 12 | BitByteData | [https://github.com/tsolomko/BitByteData](https://github.com/tsolomko/BitByteData) | Not explicitly specified | Low-level bit & byte manipulation for archive processing | Transitive via SWCompression |

---

## Usage Instructions

### Swift Projects

- **Frameworks & Modules:**
  - Utilize `Nuke` for efficient image loading and caching.
  - Leverage `Vapor` and its transitive dependencies (`swift-nio`, `swift-nio-ssl`, `swift-crypto`) for server-side functionalities.
  - Implement `SWCompression` and `BitByteData` for archive handling.
  - Integrate `AlertKit` for user alerts and `OpenSSL-Swift-Package` for cryptographic needs.
  - Use `MobileCoreServices` for UTI handling where necessary.

### Custom Language / Terminal Development

For building and extending the custom language features:

- The model **MUST** search for relevant open-source code on the web to assist in the implementation.
- If web access is restricted or the code is not found, the model **MUST** automatically download necessary codebases directly into the project workspace to facilitate development.

---

## Model Rules for Adding New Dependencies

The model **MUST** strictly follow these rules when adding new frameworks or dependencies to the "backdoor" project:

1. **Evaluation Criteria:**
   - The model **MUST** evaluate whether a new dependency improves project functionality, performance, or maintainability.
   - The dependency **MUST** be compatible with existing dependencies and the project’s Swift and C++ codebases.
   - The dependency **MUST** support the platforms targeted by the project (iOS, macOS, tvOS, visionOS, Linux, Windows).
   - The dependency **MUST** have a permissive license (e.g., MIT) to avoid legal conflicts.

2. **Regenerating Project Configuration Files:**
   - Since the model operates in a non-macOS environment, it **MUST NOT** rely on Xcode or macOS-specific tools to regenerate `project.pbxproj` and `package.resolved`.
   - Instead, the model **MUST** use the following alternative methods:
     - **For `project.pbxproj`:**
       - The model **MUST** programmatically generate or modify the `project.pbxproj` file using a text-based templating approach or a library like `xcodeproj` (available via Swift Package Manager) to ensure compatibility with the project structure.
       - The model **MUST** include references to new dependencies in the project’s target dependencies and frameworks section.
       - The model **MUST** validate the generated `project.pbxproj` file for syntactic correctness and compatibility with Xcode.
     - **For `package.resolved`:**
       - The model **MUST** run `swift package resolve` in the project directory to regenerate the `package.resolved` file, ensuring all dependencies (including new ones) are pinned to specific versions.
       - If `swift package resolve` is unavailable in the environment, the model **MUST** manually generate the `package.resolved` file by querying the Swift Package Manager’s dependency graph and serializing it into the correct JSON format.
       - The model **MUST** verify that the `package.resolved` file reflects the exact versions and dependencies specified in `Package.swift`.

3. **Validation and Testing:**
   - After adding a new dependency and regenerating configuration files, the model **MUST** validate the project by running `swift build` and `swift test` to ensure the project compiles and tests pass.
   - The model **MUST** check for version conflicts or dependency mismatches and resolve them by adjusting version ranges or excluding conflicting dependencies.

4. **Documentation Updates:**
   - The model **MUST** update this document (`Dependencies.md`) to include the new dependency in the "Dependencies Overview" table.
   - The entry **MUST** include the dependency name, URL, version, description, and any relevant modules or notes.
   - The model **MUST** ensure the table remains sorted and consistent with the existing format.

5. **Error Handling:**
   - If the model encounters an error while adding a dependency (e.g., network issues, version conflicts, or invalid configuration files), it **MUST** halt the process and report the error clearly, including steps to resolve it manually.
   - The model **MUST NOT** proceed with partial or broken configurations.

6. **Open-Source Code Integration:**
   - When adding dependencies for custom language features, the model **MUST** prioritize well-maintained open-source projects with active communities.
   - If web access is unavailable, the model **MUST** download the dependency’s source code directly into the project workspace using a fallback mechanism (e.g., cloning the repository via Git).
   - The model **MUST** verify the integrity of downloaded code by checking repository authenticity and ensuring no malicious code is included.

---

## Important Notes

- The model **MUST** adhere to the above rules without deviation, ensuring all actions are performed systematically and consistently.
- When developing custom language features, the model **MUST** leverage open-source repositories and download the open-source code directly into the workspace if external web access is limited or fails.
- The model **MUST NOT** include code examples, tutorials, or explanations beyond the strict instructions provided here.
- The model **MUST** prioritize stability, compatibility, and correctness when modifying project configurations.

---

**End of Document**