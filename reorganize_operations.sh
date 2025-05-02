#!/bin/bash
set -e

# Create new directory structure
mkdir -p iOS/Operations/AI
mkdir -p iOS/Operations/App
mkdir -p iOS/Operations/Network
mkdir -p iOS/Operations/Security
# Helpers already exists

# Move AI-related operations
mv iOS/Operations/AIDatasetManager.swift iOS/Operations/AI/
mv iOS/Operations/AILearningManager*.swift iOS/Operations/AI/
mv iOS/Operations/BackdoorAIClient*.swift iOS/Operations/AI/
mv iOS/Operations/BackdoorDataCollector.swift iOS/Operations/AI/
mv iOS/Operations/CustomAIContextProvider.swift iOS/Operations/AI/
mv iOS/Operations/CustomAIService*.swift iOS/Operations/AI/
mv iOS/Operations/MinimalBackdoorCollector.swift iOS/Operations/AI/
mv iOS/Operations/NaturalLanguageHelper.swift iOS/Operations/AI/
mv iOS/Operations/OpenAIService.swift iOS/Operations/AI/

# Move CoreML as a subdirectory of AI
mv iOS/Operations/CoreML iOS/Operations/AI/

# Move App-related operations
mv iOS/Operations/AppContextManager*.swift iOS/Operations/App/
mv iOS/Operations/AppDelegate+Terminal.swift iOS/Operations/App/
mv iOS/Operations/AppLifecycleManager.swift iOS/Operations/App/
mv iOS/Operations/AppPerformanceOptimizer.swift iOS/Operations/App/
mv iOS/Operations/CustomCommandProcessor.swift iOS/Operations/App/
mv iOS/Operations/FloatingButtonManager.swift iOS/Operations/App/
mv iOS/Operations/OptimizationIntegrator.swift iOS/Operations/App/
mv iOS/Operations/TableViewOptimizer.swift iOS/Operations/App/
mv iOS/Operations/TerminalButtonManager.swift iOS/Operations/App/

# Move Network-related operations
mv iOS/Operations/NetworkMonitor.swift iOS/Operations/Network/
mv iOS/Operations/SourceRefreshOperation.swift iOS/Operations/Network/
mv iOS/Operations/WebSearchManager.swift iOS/Operations/Network/

# Move Security-related operations
mv iOS/Operations/OfflineSigningManager.swift iOS/Operations/Security/

echo "Operations reorganized successfully!"
