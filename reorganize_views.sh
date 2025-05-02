#!/bin/bash
set -e

# Create consistent subdirectory structure for all view modules
# Only creating directories we plan to reorganize

# AI section restructuring
mkdir -p iOS/Views/AI/Core
mkdir -p iOS/Views/AI/Cells
mkdir -p iOS/Views/AI/History

# Move files from AI Assistant to their proper places
mv iOS/Views/AI\ Assistant/AIViewController.swift iOS/Views/AI/Core/
mv iOS/Views/AI\ Assistant/AIFeedbackView.swift iOS/Views/AI/Core/
mv iOS/Views/AI\ Assistant/ChatViewController.swift iOS/Views/AI/Core/
mv iOS/Views/AI\ Assistant/ChatViewController+AILearning.swift iOS/Views/AI/Core/
mv iOS/Views/AI\ Assistant/ChatHistoryViewController.swift iOS/Views/AI/History/
mv iOS/Views/AI\ Assistant/AIMessageCell.swift iOS/Views/AI/Cells/
mv iOS/Views/AI\ Assistant/SystemMessageCell.swift iOS/Views/AI/Cells/
mv iOS/Views/AI\ Assistant/UserMessageCell.swift iOS/Views/AI/Cells/

# Remove empty AI Assistant directory if it exists
rmdir iOS/Views/AI\ Assistant 2>/dev/null || true

# Terminal section restructuring
mkdir -p iOS/Views/Terminal/Core
mkdir -p iOS/Views/Terminal/Components

# Add a TODO to TerminalFileManager.swift
echo "import Foundation

// TODO: Implement TerminalFileManager functionality
// This file is intended to provide file management capabilities for the Terminal
" > iOS/Views/Terminal/TerminalFileManager.swift

# Move terminal files to better locations
mv iOS/Views/Terminal/TerminalViewController.swift iOS/Views/Terminal/Core/
mv iOS/Views/Terminal/TerminalService.swift iOS/Views/Terminal/Core/
mv iOS/Views/Terminal/CommandHistory.swift iOS/Views/Terminal/Components/
mv iOS/Views/Terminal/CommandInputView.swift iOS/Views/Terminal/Components/
mv iOS/Views/Terminal/FloatingTerminalButton.swift iOS/Views/Terminal/Components/
mv iOS/Views/Terminal/TerminalTextView.swift iOS/Views/Terminal/Components/

# Settings restructuring (mostly keeping existing directories)
mkdir -p iOS/Views/Settings/General
mkdir -p iOS/Views/Settings/Core

# Add a TODO to ModifyAppDelegate.swift
echo "import UIKit

// TODO: Implement ModifyAppDelegate functionality
// This file is intended to provide app delegate modification capabilities
" > iOS/Views/Settings/ModifyAppDelegate.swift

# Move the settings main file
mv iOS/Views/Settings/SettingsViewController.swift iOS/Views/Settings/Core/

# Extra section structuring
mkdir -p iOS/Views/Extra/Popups
mkdir -p iOS/Views/Extra/Previews

# Organize extra files
mv iOS/Views/Extra/PopupViewController*.swift iOS/Views/Extra/Popups/
mv iOS/Views/Extra/StartupPopupViewController.swift iOS/Views/Extra/Popups/
mv iOS/Views/Extra/TransferPreview.swift iOS/Views/Extra/Previews/

echo "Views reorganized successfully!"
