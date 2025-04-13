#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Regenerating backdoor.xcodeproj and Updating Dependencies ===${NC}"

# Ensure we're in the project root
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || { echo -e "${RED}Error: Not in a git repository${NC}"; exit 1; }
cd "$REPO_ROOT" || { echo -e "${RED}Error: Failed to change to $REPO_ROOT${NC}"; exit 1; }

# Verify Package.swift exists
[ -f "Package.swift" ] || { echo -e "${RED}Error: Package.swift not found${NC}"; exit 1; }

# Check Xcode installation
command -v xcodebuild &>/dev/null || { echo -e "${RED}Error: xcodebuild not found${NC}"; exit 1; }
XCODE_VERSION=$(xcodebuild -version | grep Xcode | awk '{print $2}')
echo -e "${BLUE}Using Xcode $XCODE_VERSION${NC}"

# Backup existing project
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_DIR="project_backup_${TIMESTAMP}"
mkdir -p "$BACKUP_DIR"
[ -d "backdoor.xcodeproj" ] && cp -r backdoor.xcodeproj "$BACKUP_DIR/" && echo "✓ Backed up backdoor.xcodeproj to $BACKUP_DIR"

# Remove existing project
echo -e "${BLUE}Removing existing backdoor.xcodeproj...${NC}"
rm -rf backdoor.xcodeproj

# Resolve dependencies
echo -e "${BLUE}Resolving dependencies...${NC}"
swift package resolve > swift_resolve.log 2>&1 || {
    echo -e "${RED}Error: Failed to resolve dependencies${NC}"
    cat swift_resolve.log
    exit 1
}
[ -f "Package.resolved" ] || { echo -e "${RED}Error: Package.resolved not generated${NC}"; exit 1; }
echo "✓ Package.resolved generated"

# Generate project with SPM
echo -e "${BLUE}Generating backdoor.xcodeproj...${NC}"
swift package generate-xcodeproj --xcconfig-overrides Release.xcconfig > swift_generate.log 2>&1 || {
    echo -e "${RED}Error: Failed to generate project${NC}"
    cat swift_generate.log
    exit 1
}
echo "✓ Generated backdoor.xcodeproj"

# Create Release.xcconfig if not present (for optimization and Vapor)
if [ ! -f "Release.xcconfig" ]; then
    cat << EOF > Release.xcconfig
// Release configuration for Backdoor
SWIFT_OPTIMIZATION_LEVEL = -O
GCC_OPTIMIZATION_LEVEL = 3
SWIFT_ACTIVE_COMPILATION_CONDITIONS = RELEASE
EOF
    echo "✓ Created Release.xcconfig"
fi

# Verify project.pbxproj exists
[ -f "backdoor.xcodeproj/project.pbxproj" ] || { echo -e "${RED}Error: project.pbxproj not generated${NC}"; exit 1; }
echo "✓ project.pbxproj generated"

# Resolve project dependencies
echo -e "${BLUE}Resolving project dependencies...${NC}"
xcodebuild -project backdoor.xcodeproj -configuration Release -resolvePackageDependencies > xcodebuild_resolve.log 2>&1 || {
    echo -e "${RED}Error: Failed to resolve project dependencies${NC}"
    cat xcodebuild_resolve.log
    exit 1
}
echo "✓ Resolved project dependencies"

# Verify scheme
echo -e "${BLUE}Checking scheme 'Backdoor'...${NC}"
xcodebuild -project backdoor.xcodeproj -list 2>/dev/null | grep -q "Backdoor" && echo "✓ Found scheme" || {
    echo -e "${BLUE}Generating scheme...${NC}"
    xcodebuild -project backdoor.xcodeproj -scheme Backdoor -configuration Release > xcodebuild_scheme.log 2>&1 || {
        echo -e "${BLUE}Scheme may generate on Xcode open${NC}"
        cat xcodebuild_scheme.log
    }
}

# Attempt to build to catch issues (optional, for validation)
echo -e "${BLUE}Attempting to build project...${NC}"
xcodebuild -project backdoor.xcodeproj -scheme Backdoor -configuration Release build > xcodebuild_build.log 2>&1 || {
    echo -e "${BLUE}Build failed, but project may still be valid${NC}"
    cat xcodebuild_build.log
}

# Save artifacts
ARTIFACTS_DIR="artifacts"
mkdir -p "$ARTIFACTS_DIR"
cp backdoor.xcodeproj/project.pbxproj "$ARTIFACTS_DIR/" && echo "✓ Saved project.pbxproj to $ARTIFACTS_DIR"
cp Package.resolved "$ARTIFACTS_DIR/" && echo "✓ Saved Package.resolved to $ARTIFACTS_DIR"

echo -e "${GREEN}Success! Project regenerated and artifacts saved to $ARTIFACTS_DIR${NC}"
echo "Backup in: $BACKUP_DIR"
echo "Logs: swift_resolve.log, swift_generate.log, xcodebuild_*.log"