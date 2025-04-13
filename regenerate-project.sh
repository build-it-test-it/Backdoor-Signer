#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Project.pbxproj and Package.resolved Update Script ===${NC}"

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

# Function to parse Package.swift for dependencies
parse_package_swift() {
  echo -e "${BLUE}Reading dependencies from Package.swift...${NC}"
  # Extract package URLs and versions (basic parsing for common formats)
  grep -E '\.package\(.*\)' Package.swift | while read -r line; do
    # Extract URL
    url=$(echo "$line" | grep -o 'url: *"[a-zA-Z0-9:/.-]*"' | sed 's/url: *"\(.*\)"/\1/')
    # Extract version or branch (from, exact, branch, etc.)
    version=$(echo "$line" | grep -o '\(from: *"[0-9.]*"\|exact: *"[0-9.]*"\|branch: *"[a-zA-Z0-9-]*"\)' | sed 's/.*"\(.*\)"/\1/')
    if [ -n "$url" ]; then
      echo "✓ Dependency: $url (Version/Branch: ${version:-unspecified})"
    fi
  done
}

# Function to parse Package.resolved for resolved dependencies
parse_package_resolved() {
  if [ -f "backdoor.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" ]; then
    echo -e "${BLUE}Reading resolved dependencies from Package.resolved...${NC}"
    # Extract package names and versions (assuming JSON format)
    cat "backdoor.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" | grep -E '"package":|"version":|"repositoryURL":' | while read -r line; do
      if echo "$line" | grep -q '"package":'; then
        package=$(echo "$line" | sed 's/.*"package": "\(.*\)",/\1/')
      elif echo "$line" | grep -q '"version":'; then
        version=$(echo "$line" | sed 's/.*"version": "\(.*\)",/\1/')
      elif echo "$line" | grep -q '"repositoryURL":'; then
        url=$(echo "$line" | sed 's/.*"repositoryURL": "\(.*\)",/\1/')
        echo "✓ Resolved: $package ($version) from $url"
      fi
    done
  else
    echo -e "${RED}Package.resolved not found yet${NC}"
  fi
}

# Display initial dependencies from Package.swift
parse_package_swift

# Create backup of current project files
echo -e "${BLUE}Creating backup of project files...${NC}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="project_backup_${TIMESTAMP}"
mkdir -p "$BACKUP_DIR"

if [ -f "backdoor.xcodeproj/project.pbxproj" ]; then
  cp backdoor.xcodeproj/project.pbxproj "$BACKUP_DIR/"
  echo "✓ Backed up project.pbxproj"
fi

if [ -f "backdoor.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" ]; then
  cp backdoor.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved "$BACKUP_DIR/"
  echo "✓ Backed up Package.resolved"
fi

# Clean the project to ensure a fresh state
echo -e "${BLUE}Cleaning project...${NC}"
xcodebuild clean -project backdoor.xcodeproj -configuration Release

# Update Package.resolved
echo -e "${BLUE}Updating Package.resolved...${NC}"
xcodebuild -resolvePackageDependencies -project backdoor.xcodeproj

# Verify the scheme exists
echo -e "${BLUE}Verifying scheme 'backdoor (Release)'...${NC}"
if ! xcodebuild -project backdoor.xcodeproj -list | grep -q "backdoor (Release)"; then
  echo -e "${RED}Error: Scheme 'backdoor (Release)' not found${NC}"
  exit 1
fi
echo "✓ Using scheme: backdoor (Release)"

# Force Xcode to update project.pbxproj by generating schemes and running a build
echo -e "${BLUE}Updating project.pbxproj to include new dependencies...${NC}"
xcodebuild -project backdoor.xcodeproj -list > /dev/null
xcodebuild -project backdoor.xcodeproj -scheme "backdoor (Release)" -configuration Release build > /dev/null 2>&1 || true

# Display updated dependencies from Package.resolved
parse_package_resolved

# Save updated files to artifacts directory for GitHub Actions
echo -e "${BLUE}Saving updated files to artifacts directory...${NC}"
ARTIFACTS_DIR="artifacts"
mkdir -p "$ARTIFACTS_DIR"
if [ -f "backdoor.xcodeproj/project.pbxproj" ]; then
  cp backdoor.xcodeproj/project.pbxproj "$ARTIFACTS_DIR/"
  echo "✓ Saved project.pbxproj to $ARTIFACTS_DIR"
fi
if [ -f "backdoor.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" ]; then
  cp backdoor.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved "$ARTIFACTS_DIR/"
  echo "✓ Saved Package.resolved to $ARTIFACTS_DIR"
fi

echo -e "${GREEN}Project files updated, dependencies linked, and artifacts saved!${NC}"
echo -e "Backup saved to: ${BACKUP_DIR}"
echo -e "Artifacts saved to: ${ARTIFACTS_DIR}"
echo -e "${BLUE}Next steps:${NC}"
echo "1. Open backdoor.xcodeproj in Xcode"
echo "2. Verify new dependencies in the project navigator"
echo "3. Build the project with 'backdoor (Release)' scheme (Cmd+B)"
echo "4. Check artifacts in $ARTIFACTS_DIR for CI/CD"