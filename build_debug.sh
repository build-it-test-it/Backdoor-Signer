#!/bin/bash

# Script to build the backdoor project in Debug mode with correct flags
# This fixes the "Unknown build action 'DEBUGGER_ENABLED'" error

echo "=== Building in Debug Mode with correct flags ==="

# Use xcodebuild with proper flags format
xcodebuild \
  -project 'backdoor.xcodeproj' \
  -scheme 'backdoor (Debug)' \
  -configuration Debug \
  -arch arm64 -sdk iphoneos \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS="DEBUG DEBUGGER_ENABLED" \
  OTHER_SWIFT_FLAGS="-DDEBUG=1" \
  SWIFT_OPTIMIZATION_LEVEL="-Onone" \
  SWIFT_COMPILATION_MODE="singlefile" \
  GCC_PREPROCESSOR_DEFINITIONS="DEBUG=1 DEBUGGER_ENABLED=1" \
  GCC_OPTIMIZATION_LEVEL=0 \
  COPY_PHASE_STRIP=NO \
  ENABLE_TESTABILITY=YES \
  INCLUDE_DEBUGGER=YES \
  ENABLE_ENHANCED_LOGGING=YES \
  VERBOSE_LOGGING=YES

echo "Build completed!"
