#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Project.pbxproj and Package.resolved Regeneration Script ===${NC}"

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

# Check if project file exists
if [ ! -d "backdoor.xcodeproj" ]; then
  echo -e "${RED}Error: backdoor.xcodeproj not found${NC}"
  exit 1
fi

# Create backup of current project files
echo -e "${BLUE}Creating backup of project files...${NC}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="project_backup_${TIMESTAMP}"
mkdir -p "$BACKUP_DIR"

if [ -f "backdoor.xcodeproj/project.pbxproj" ]; then
  cp backdoor.xcodeproj/project.pbxproj "$BACKUP_DIR/"
  echo "✓ Backed up project.pbxproj"
fi

if [ -f "Package.resolved" ]; then
  cp Package.resolved "$BACKUP_DIR/"
  echo "✓ Backed up Package.resolved"
fi

# Generate new project.pbxproj and resolve dependencies
echo -e "${BLUE}Regenerating project.pbxproj and resolving dependencies...${NC}"
swift package generate-xcodeproj --output backdoor.xcodeproj

# Update Package.resolved
echo -e "${BLUE}Updating Package.resolved...${NC}"
xcodebuild -resolvePackageDependencies -project backdoor.xcodeproj

echo -e "${GREEN}Project files regenerated and dependencies resolved!${NC}"
echo -e "Backup saved to: ${BACKUP_DIR}"
echo -e "${BLUE}Next steps:${NC}"
echo "1. Open backdoor.xcodeproj in Xcode"
echo "2. Build the project (Cmd+B)"