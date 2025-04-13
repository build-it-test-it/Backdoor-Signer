#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Project.pbxproj Regeneration and Package.resolved Update Script ===${NC}"

# Make sure we're in the root directory of the project
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ $? -ne 0 ]; then
  echo -e "${RED}Error: Not in a git repository. Please run from the project root.${NC}"
  exit 1
fi
cd "$REPO_ROOT" || { echo -e "${RED}Error: Failed to change to $REPO_ROOT${NC}"; exit 1; }

# Ensure Package.swift exists
if [ ! -f "Package.swift" ]; then
  echo -e "${RED}Error: Package.swift not found in $REPO_ROOT${NC}"
  exit 1
fi

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
  echo -e "${RED}Error: xcodebuild not found. Please install Xcode.${NC}"
  exit 1
fi

# Check Xcode version
XCODE_VERSION=$(xcodebuild -version | grep Xcode | awk '{print $2}')
echo -e "${BLUE}Using Xcode version: $XCODE_VERSION${NC}"

# Function to parse Package.swift for dependencies
parse_package_swift() {
  echo -e "${BLUE}Reading dependencies from Package.swift...${NC}"
  dependencies=()
  grep -E '\.package\(.*\)' Package.swift | while read -r line; do
    url=$(echo "$line" | grep -o 'url: *"[a-zA-Z0-9:/.-]*"' | sed 's/url: *"\(.*\)"/\1/')
    version=$(echo "$line" | grep -o '\(from: *"[0-9.]*"\|exact: *"[0-9.]*"\|branch: *"[a-zA-Z0-9-]*"\)' | sed 's/.*"\(.*\)"/\1/')
    if [ -n "$url" ]; then
      package_name=$(basename "$url" .git)
      echo "✓ Dependency: $package_name ($url, Version/Branch: ${version:-unspecified})"
      dependencies+=("$package_name")
    fi
  done
  if [ ${#dependencies[@]} -eq 0 ]; then
    echo -e "${BLUE}No dependencies found in Package.swift${NC}"
  fi
}

# Function to parse Package.resolved for resolved dependencies
parse_package_resolved() {
  resolved_file="backdoor.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
  if [ ! -f "$resolved_file" ]; then
    resolved_file="Package.resolved"
  fi
  if [ -f "$resolved_file" ]; then
    echo -e "${BLUE}Reading resolved dependencies from Package.resolved...${NC}"
    cat "$resolved_file" | grep -E '"package":|"version":|"repositoryURL":' | while read -r line; do
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
    echo -e "${BLUE}Package.resolved not found${NC}"
  fi
}

# Function to verify project.pbxproj includes dependencies
verify_pbxproj() {
  echo -e "${BLUE}Verifying regenerated project.pbxproj includes dependencies...${NC}"
  pbxproj_file="backdoor.xcodeproj/project.pbxproj"
  if [ ! -f "$pbxproj_file" ]; then
    echo -e "${RED}Error: Regenerated project.pbxproj not found at $pbxproj_file${NC}"
    return 1
  fi
  for dep in "${dependencies[@]}"; do
    if grep -qi "$dep" "$pbxproj_file"; then
      echo "✓ Found $dep in project.pbxproj"
    else
      echo -e "${RED}Warning: $dep not found in project.pbxproj${NC}"
    fi
  done
  return 0
}

# Display initial dependencies from Package.swift and store them
declare -a dependencies
parse_package_swift

# Create backup of current project files
echo -e "${BLUE}Creating backup of project files...${NC}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="project_backup_${TIMESTAMP}"
mkdir -p "$BACKUP_DIR" || { echo -e "${RED}Error: Failed to create backup directory $BACKUP_DIR${NC}"; exit 1; }

if [ -d "backdoor.xcodeproj" ]; then
  cp -r backdoor.xcodeproj "$BACKUP_DIR/" || { echo -e "${RED}Error: Failed to backup backdoor.xcodeproj${NC}"; exit 1; }
  echo "✓ Backed up backdoor.xcodeproj to $BACKUP_DIR"
else
  echo -e "${BLUE}No existing backdoor.xcodeproj to backup${NC}"
fi

# Remove existing project to force regeneration
echo -e "${BLUE}Removing existing backdoor.xcodeproj to regenerate...${NC}"
rm -rf backdoor.xcodeproj || { echo -e "${RED}Error: Failed to remove backdoor.xcodeproj${NC}"; exit 1; }

# Resolve dependencies to create Package.resolved
echo -e "${BLUE}Resolving dependencies to generate Package.resolved...${NC}"
swift package resolve > swift_resolve.log 2>&1 || {
  echo -e "${RED}Error: Failed to resolve dependencies with swift package resolve${NC}"
  cat swift_resolve.log
  exit 1
}
echo "✓ Resolved dependencies"

# Check if Package.resolved was created
if [ ! -f "Package.resolved" ]; then
  echo -e "${RED}Error: Package.resolved not generated${NC}"
  exit 1
fi
echo "✓ Package.resolved generated"

# Generate new project using SPM integration
echo -e "${BLUE}Generating new backdoor.xcodeproj...${NC}"

# Create a workspace to help SPM generate the project
mkdir -p backdoor.xcodeproj
mkdir -p backdoor.xcodeproj/project.xcworkspace
cat << EOF > backdoor.xcodeproj/project.xcworkspace/contents.xcworkspacedata
<?xml version="1.0" encoding="UTF-8"?>
<Workspace version = "1.0">
   <FileRef location = "self:">
   </FileRef>
</Workspace>
EOF
echo "✓ Created workspace structure"

# Copy Package.resolved to the workspace
mkdir -p backdoor.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
cp Package.resolved backdoor.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved || {
  echo -e "${RED}Error: Failed to copy Package.resolved to workspace${NC}"
  exit 1
}

# Let SPM generate the project by running xcodebuild
xcodebuild -project backdoor.xcodeproj -configuration Release -resolvePackageDependencies > xcodebuild_resolve.log 2>&1 || {
  echo -e "${BLUE}Initial resolve may fail due to missing project structure, attempting to generate...${NC}"
  cat xcodebuild_resolve.log
}

# Attempt to build to force SPM to generate the project
xcodebuild -project backdoor.xcodeproj -configuration Release build > xcodebuild_build.log 2>&1 || {
  echo -e "${BLUE}Build failed, but project.pbxproj may still be generated${NC}"
  cat xcodebuild_build.log
}

# Check if project.pbxproj was generated
if [ ! -f "backdoor.xcodeproj/project.pbxproj" ]; then
  echo -e "${RED}Error: project.pbxproj was not generated${NC}"
  cat xcodebuild_build.log
  exit 1
fi
echo "✓ project.pbxproj generated"

# Verify scheme
echo -e "${BLUE}Checking for scheme 'backdoor (Release)'...${NC}"
if xcodebuild -project backdoor.xcodeproj -list 2>/dev/null | grep -q "backdoor (Release)"; then
  echo "✓ Found scheme: backdoor (Release)"
else
  echo -e "${BLUE}Warning: Scheme 'backdoor (Release)' not found. It may be generated when opening in Xcode.${NC}"
fi

# Verify regenerated project.pbxproj includes dependencies
verify_pbxproj || echo -e "${BLUE}Continuing despite verification warnings${NC}"

# Display updated dependencies from Package.resolved
parse_package_resolved

# Save updated files to artifacts directory for GitHub Actions
echo -e "${BLUE}Saving regenerated files to artifacts directory...${NC}"
ARTIFACTS_DIR="artifacts"
mkdir -p "$ARTIFACTS_DIR" || { echo -e "${RED}Error: Failed to create artifacts directory $ARTIFACTS_DIR${NC}"; exit 1; }
if [ -f "backdoor.xcodeproj/project.pbxproj" ]; then
  cp backdoor.xcodeproj/project.pbxproj "$ARTIFACTS_DIR/" || { echo -e "${RED}Error: Failed to save project.pbxproj to $ARTIFACTS_DIR${NC}"; exit 1; }
  echo "✓ Saved project.pbxproj to $ARTIFACTS_DIR"
fi
if [ -f "backdoor.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" ]; then
  cp backdoor.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved "$ARTIFACTS_DIR/" || { echo -e "${RED}Error: Failed to save Package.resolved to $ARTIFACTS_DIR${NC}"; exit 1; }
  echo "✓ Saved Package.resolved to $ARTIFACTS_DIR"
else
  echo -e "${RED}Warning: Package.resolved not found in expected location, saving from root${NC}"
  if [ -f "Package.resolved" ]; then
    cp Package.resolved "$ARTIFACTS_DIR/" || { echo -e "${RED}Error: Failed to save Package.resolved to $ARTIFACTS_DIR${NC}"; exit 1; }
    echo "✓ Saved Package.resolved to $ARTIFACTS_DIR"
  fi
fi

echo -e "${GREEN}Project files regenerated, dependencies updated, and artifacts saved!${NC}"
echo -e "Backup saved to: ${BACKUP_DIR}"
echo -e "Artifacts saved to: ${ARTIFACTS_DIR}"
echo -e "${BLUE}Next steps:${NC}"
echo "1. Open backdoor.xcodeproj in Xcode"
echo "2. Verify new dependencies in the project navigator"
echo "3. Build the project with 'backdoor (Release)' scheme (Cmd+B)"
echo "4. Check artifacts in $ARTIFACTS_DIR for CI/CD"
echo "5. Check swift_resolve.log and xcodebuild_*.log files if issues persist"