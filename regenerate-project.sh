#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Simple project.pbxproj Regeneration Script ===${NC}"

# Make sure we're in the root directory of the project
REPO_ROOT=$(git rev-parse --show-toplevel)
cd "$REPO_ROOT"

# Ensure Package.swift exists
if [ ! -f "Package.swift" ]; then
  echo -e "${RED}Error: Package.swift not found${NC}"
  exit 1
fi

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
  echo -e "${RED}Error: xcodebuild not found. Please install Xcode.${NC}"
  exit 1
fi

# Create backup of current project files
echo -e "${BLUE}Creating backup of project files...${NC}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="project_backup_${TIMESTAMP}"
mkdir -p "$BACKUP_DIR"

if [ -d "backdoor.xcodeproj" ]; then
  cp -r backdoor.xcodeproj "$BACKUP_DIR/"
  echo "✓ Backed up backdoor.xcodeproj"
fi

if [ -d "backdoor.xcworkspace" ]; then
  cp -r backdoor.xcworkspace "$BACKUP_DIR/"
  echo "✓ Backed up backdoor.xcworkspace"
fi

if [ -f "Package.resolved" ]; then
  cp Package.resolved "$BACKUP_DIR/"
  echo "✓ Backed up Package.resolved"
fi

# Use Xcode's package resolution
echo -e "${BLUE}Resolving Swift Package dependencies...${NC}"
xcodebuild -resolvePackageDependencies -project backdoor.xcodeproj

echo -e "${GREEN}Project dependencies have been refreshed!${NC}"
echo -e "Backup saved to: ${BACKUP_DIR}"
echo -e "${BLUE}Next steps:${NC}"
echo "1. Open backdoor.xcodeproj in Xcode"
echo "2. Wait for Xcode to finish resolving packages"
echo "3. Clean the build folder (Shift+Cmd+K)"
echo "4. Build the project (Cmd+B)"
