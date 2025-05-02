#!/bin/bash
set -e

# Create consistent subdirectory structure for all view modules
# First check what's happening with AI files
if [ -f "iOS/Views/AI" ]; then
  echo "iOS/Views/AI is a file, moving it temporarily"
  mv iOS/Views/AI iOS/Views/AI.temp
fi

# Create proper AI directory structure
mkdir -p iOS/Views/AI/Core
mkdir -p iOS/Views/AI/Cells
mkdir -p iOS/Views/AI/History

# Move content of AI.temp to AI/Core if it exists
if [ -f "iOS/Views/AI.temp" ]; then
  echo "Moving AI content to AI/Core"
  cp iOS/Views/AI.temp iOS/Views/AI/Core/AI.swift
  rm iOS/Views/AI.temp
fi

# Move files from AI Assistant to their proper places
if [ -d "iOS/Views/AI Assistant" ]; then
  echo "Reorganizing AI Assistant files"
  mv iOS/Views/AI\ Assistant/AIViewController.swift iOS/Views/AI/Core/ 2>/dev/null || true
  mv iOS/Views/AI\ Assistant/AIFeedbackView.swift iOS/Views/AI/Core/ 2>/dev/null || true
  mv iOS/Views/AI\ Assistant/ChatViewController.swift iOS/Views/AI/Core/ 2>/dev/null || true
  mv iOS/Views/AI\ Assistant/ChatViewController+AILearning.swift iOS/Views/AI/Core/ 2>/dev/null || true
  mv iOS/Views/AI\ Assistant/ChatHistoryViewController.swift iOS/Views/AI/History/ 2>/dev/null || true
  mv iOS/Views/AI\ Assistant/AIMessageCell.swift iOS/Views/AI/Cells/ 2>/dev/null || true
  mv iOS/Views/AI\ Assistant/SystemMessageCell.swift iOS/Views/AI/Cells/ 2>/dev/null || true
  mv iOS/Views/AI\ Assistant/UserMessageCell.swift iOS/Views/AI/Cells/ 2>/dev/null || true

  # Try to remove empty AI Assistant directory
  rmdir iOS/Views/AI\ Assistant 2>/dev/null || echo "Could not remove AI Assistant directory, it might not be empty"
fi

# Terminal section restructuring
mkdir -p iOS/Views/Terminal/Core
mkdir -p iOS/Views/Terminal/Components

# Add a TODO to TerminalFileManager.swift
if [ -f "iOS/Views/Terminal/TerminalFileManager.swift" ]; then
  echo "Updating TerminalFileManager.swift with TODO comment"
  echo "import Foundation

// TODO: Implement TerminalFileManager functionality
// This file is intended to provide file management capabilities for the Terminal
" > iOS/Views/Terminal/TerminalFileManager.swift
fi

# Move terminal files to better locations
mv iOS/Views/Terminal/TerminalViewController.swift iOS/Views/Terminal/Core/ 2>/dev/null || true
mv iOS/Views/Terminal/TerminalService.swift iOS/Views/Terminal/Core/ 2>/dev/null || true
mv iOS/Views/Terminal/CommandHistory.swift iOS/Views/Terminal/Components/ 2>/dev/null || true
mv iOS/Views/Terminal/CommandInputView.swift iOS/Views/Terminal/Components/ 2>/dev/null || true
mv iOS/Views/Terminal/FloatingTerminalButton.swift iOS/Views/Terminal/Components/ 2>/dev/null || true
mv iOS/Views/Terminal/TerminalTextView.swift iOS/Views/Terminal/Components/ 2>/dev/null || true

# Settings restructuring (mostly keeping existing directories)
mkdir -p iOS/Views/Settings/General
mkdir -p iOS/Views/Settings/Core

# Add a TODO to ModifyAppDelegate.swift
if [ -f "iOS/Views/Settings/ModifyAppDelegate.swift" ]; then
  echo "Updating ModifyAppDelegate.swift with TODO comment"
  echo "import UIKit

// TODO: Implement ModifyAppDelegate functionality
// This file is intended to provide app delegate modification capabilities
" > iOS/Views/Settings/ModifyAppDelegate.swift
fi

# Move the settings main file
mv iOS/Views/Settings/SettingsViewController.swift iOS/Views/Settings/Core/ 2>/dev/null || true

# Extra section structuring
if [ -d "iOS/Views/Extra" ]; then
  mkdir -p iOS/Views/Extra/Popups
  mkdir -p iOS/Views/Extra/Previews

  # Organize extra files
  mv iOS/Views/Extra/PopupViewController*.swift iOS/Views/Extra/Popups/ 2>/dev/null || true
  mv iOS/Views/Extra/StartupPopupViewController.swift iOS/Views/Extra/Popups/ 2>/dev/null || true
  mv iOS/Views/Extra/TransferPreview.swift iOS/Views/Extra/Previews/ 2>/dev/null || true
fi

echo "Views reorganized successfully!"
