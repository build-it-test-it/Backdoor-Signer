# Codebase Reorganization Plan

This document outlines the plan for reorganizing the Backdoor-Signer codebase for improved modularity and maintainability.

## Goals

- Group related files by feature/functionality
- Create logical hierarchies for easier navigation
- Maintain all existing functionality
- Add TODOs to empty files
- Improve organization for better maintainability

## iOS Directory Reorganization

### Extensions
- **UIKit/**: All UI-related extensions
  - UIView+*.swift, UIButton+*.swift, etc.
- **Foundation/**: Standard library extensions
  - String+Crypto.swift, etc.
- **Feature/**: Feature-specific extensions
  - AILearningManager+*.swift, AppDelegate+*.swift, etc.

### Operations
- **AI/**: AI-related operations
  - AILearningManager*.swift, CustomAIService*.swift, etc.
  - Includes CoreML/ subdirectory
- **App/**: App lifecycle and management
  - AppContextManager*.swift, AppLifecycleManager.swift, etc.
- **Network/**: Network operations
  - NetworkMonitor.swift, WebSearchManager.swift, etc.
- **Security/**: Security-related operations
  - OfflineSigningManager.swift
- **Helpers/**: Utility functions (existing)
  - CryptoHelper.swift, UIHelpers.swift

### Views
- **AI/**: AI-related views with better organization
  - Core/: Main AI controllers
  - Cells/: Table cells for AI views
  - History/: Chat history views
- **Terminal/**: Better organized terminal views
  - Core/: Main terminal functionality
  - Components/: Terminal UI components
- (Other view directories remain largely the same)

## Shared Directory Reorganization

### Magic
- **Signing/**: App signing functionality
  - AppSigner.swift, TweakHandler.swift, esign/, zsign/
- **Security/**: Security-related functionality
  - BackdoorEncryption.swift, openssl_tools.*
- **FileHandling/**: File operations
  - BackdoorFileHandler.swift, decompression/

### Management
- **Network/**: Network management
  - NetworkManager*.swift
- **Downloads/**: Download handling
  - AppDownload.swift, DownloadTaskManager.swift, etc.
- **Cloud/**: Cloud services
  - DropboxService variants
- **Utilities/**: Utility functions
  - BundleIdChecker.swift, CertData.swift, etc.

## Empty Files

The following empty files will be populated with TODO comments:
- ModifyAppDelegate.swift
- TerminalFileManager.swift
- BackdoorCLI.swift

## Backup Files

The following backup files were found and will be preserved:
- scripts/ci/download-artifacts.sh.bak
