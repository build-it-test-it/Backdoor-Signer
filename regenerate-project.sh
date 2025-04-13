#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Project.pbxproj Regeneration and Package.resolved Update Script ===${NC}"

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
}

# Function to parse Package.resolved for resolved dependencies
parse_package_resolved() {
  if [ -f "backdoor.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" ]; then
    echo -e "${BLUE}Reading resolved dependencies from Package.resolved...${NC}"
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

# Function to verify project.pbxproj includes dependencies
verify_pbxproj() {
  echo -e "${BLUE}Verifying regenerated project.pbxproj includes dependencies...${NC}"
  pbxproj_file="backdoor.xcodeproj/project.pbxproj"
  if [ ! -f "$pbxproj_file" ]; then
    echo -e "${RED}Error: Regenerated project.pbxproj not found${NC}"
    exit 1
  fi
  for dep in "${dependencies[@]}"; do
    if grep -qi "$dep" "$pbxproj_file"; then
      echo "✓ Found $dep in project.pbxproj"
    else
      echo -e "${RED}Warning: $dep not found in project.pbxproj${NC}"
      echo -e "${RED}project.pbxproj may not have regenerated correctly${NC}"
    fi
  done
}

# Display initial dependencies from Package.swift and store them
declare -a dependencies
parse_package_swift

# Create backup of current project files
echo -e "${BLUE}Creating backup of project files...${NC}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="project_backup_${TIMESTAMP}"
mkdir -p "$BACKUP_DIR"

if [ -d "backdoor.xcodeproj" ]; then
  cp -r backdoor.xcodeproj "$BACKUP_DIR/"
  echo "✓ Backed up backdoor.xcodeproj"
fi

# Remove existing project to force regeneration
echo -e "${BLUE}Removing existing backdoor.xcodeproj to regenerate...${NC}"
rm -rf backdoor.xcodeproj

# Generate new project by resolving dependencies and building
echo -e "${BLUE}Regenerating project.pbxproj and updating Package.resolved...${NC}"
# First, resolve dependencies to create Package.resolved
xcodebuild -resolvePackageDependencies

# Create a temporary Xcode project to force SPM integration
echo -e "${BLUE}Creating temporary project structure...${NC}"
mkdir -p backdoor.xcodeproj
cat << EOF > backdoor.xcodeproj/project.pbxproj
// !$*UTF8*$!
{
  archiveVersion = 1;
  classes = {
  };
  objectVersion = 50;
  objects = {};
  rootObject = "";
}
EOF

# Force SPM to generate project structure
xcodebuild -project backdoor.xcodeproj -scheme "backdoor (Release)" -configuration Release -resolvePackageDependencies

# Build to ensure project.pbxproj is fully populated
xcodebuild -project backdoor.xcodeproj -scheme "backdoor (Release)" -configuration Release build > /dev/null 2>&1 || true

# Verify the scheme exists
echo -e "${BLUE}Verifying scheme 'backdoor (Release)'...${NC}"
if ! xcodebuild -project backdoor.xcodeproj -list | grep -q "backdoor (Release)"; then
  echo -e "${RED}Error: Scheme 'backdoor (Release)' not found after regeneration${NC}"
  exit 1
fi
echo "✓ Using scheme: backdoor (Release)"

# Verify regenerated project.pbxproj includes dependencies
verify_pbxproj

# Display updated dependencies from Package.resolved
parse_package_resolved

# Save updated files to artifacts directory for GitHub Actions
echo -e "${BLUE}Saving regenerated files to artifacts directory...${NC}"
ARTIFACTS_DIR="artifacts"
mkdir -p "$ARTIFACTS_DIR"
if [ -f "backdoor.xcodeproj/project.pbxproj" ]; then
  cp backdoor.xcodeproj/project.pbxproj "$ARTIFACTS_DIR/"
  echo "✓ Saved project.pbxproj to $ARTIFACTS_DIR"
fi
if [ -f "backdoor.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved" ]; then
  cp backdoor.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved "$ARTIFACTS_DIR/"
  echo "✓ Saved Package.resolved to $ARTIFACTS_DIR"
else
  echo -e "${RED}Warning: Package.resolved not found, may not have been generated${NC}"
fi

echo -e "${GREEN}Project files regenerated, dependencies linked, and artifacts saved!${NC}"
echo -e "Backup saved to: ${BACKUP_DIR}"
echo -e "Artifacts saved to: ${ARTIFACTS_DIR}"
echo -e "${BLUE}Next steps:${NC}"
echo "1. Open backdoor.xcodeproj in Xcode"
echo "2. Verify new dependencies in the project navigator"
echo "3. Build the project with 'backdoor (Release)' scheme (Cmd+B)"
echo "4. Check artifacts in $ARTIFACTS_DIR for CI/CD"