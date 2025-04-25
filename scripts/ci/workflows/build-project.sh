#!/bin/bash
set -eo pipefail

# Script to build the project and capture logs for error analysis
# Usage: ./build-project.sh

echo "Building project for error analysis..."

# Create logs directory
mkdir -p build-logs

# Run the build with output capture
echo "Running xcodebuild..."
set +e
xcodebuild -project backdoor.xcodeproj -scheme "backdoor (Release)" -configuration Release CODE_SIGNING_ALLOWED=NO | tee build-logs/xcodebuild.log
BUILD_RESULT=$?
set -e

# Check build result
if [ $BUILD_RESULT -ne 0 ]; then
    echo "build_failed=true" >> $GITHUB_OUTPUT
    echo "✅ Build failed as expected, logs captured for analysis"
else
    echo "build_failed=false" >> $GITHUB_OUTPUT
    echo "Build succeeded, no errors to analyze"
fi

# Always link the log to the expected location
cp build-logs/xcodebuild.log build_log.txt

echo "✅ Build process complete"
