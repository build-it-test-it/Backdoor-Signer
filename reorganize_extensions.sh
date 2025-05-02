#!/bin/bash
set -e

# Create new directory structure
mkdir -p iOS/Extensions/UIKit
mkdir -p iOS/Extensions/Foundation
mkdir -p iOS/Extensions/Feature

# Move UI-related extensions
mv iOS/Extensions/UIApplication+*.swift iOS/Extensions/UIKit/
mv iOS/Extensions/UIButton+*.swift iOS/Extensions/UIKit/
mv iOS/Extensions/UIColor+*.swift iOS/Extensions/UIKit/
mv iOS/Extensions/UIControl+*.swift iOS/Extensions/UIKit/
mv iOS/Extensions/UIImage+*.swift iOS/Extensions/UIKit/
mv iOS/Extensions/UINavigationController+*.swift iOS/Extensions/UIKit/
mv iOS/Extensions/UITabBar+*.swift iOS/Extensions/UIKit/
mv iOS/Extensions/UIUserInterfaceStyle+*.swift iOS/Extensions/UIKit/
mv iOS/Extensions/UIView+*.swift iOS/Extensions/UIKit/
mv iOS/Extensions/UIViewController+*.swift iOS/Extensions/UIKit/
mv iOS/Extensions/View+*.swift iOS/Extensions/UIKit/

# Move Foundation-related extensions
mv iOS/Extensions/String+*.swift iOS/Extensions/Foundation/
mv iOS/Extensions/BasicLayoutAnchorsHolding.swift iOS/Extensions/Foundation/

# Make sure Compatibility folder exists in Foundation
mkdir -p iOS/Extensions/Foundation/Compatibility
mv iOS/Extensions/Compatibility/BitwiseCopyableShim.swift iOS/Extensions/Foundation/Compatibility/

# Move feature-specific extensions
mv iOS/Extensions/AILearningManager+*.swift iOS/Extensions/Feature/
mv iOS/Extensions/AppDelegate+*.swift iOS/Extensions/Feature/
mv iOS/Extensions/CertificateManager+*.swift iOS/Extensions/Feature/
mv iOS/Extensions/Nuke+*.swift iOS/Extensions/Feature/
mv iOS/Extensions/SettingsViewController+*.swift iOS/Extensions/Feature/

# Remove the old Compatibility directory if it's now empty
rmdir iOS/Extensions/Compatibility 2>/dev/null || true

echo "Extensions reorganized successfully!"
