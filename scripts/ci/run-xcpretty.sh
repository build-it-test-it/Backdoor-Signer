#!/bin/bash
set -e

echo "Running XCPretty project analysis..."

# Ensure output directories exist
mkdir -p build/reports/xcpretty
mkdir -p build/reports/analyzer

# Run project listing through xcpretty
xcodebuild -project backdoor.xcodeproj -list | tee build/reports/xcpretty/project_info.txt | xcpretty --color

echo "Running basic build check with warnings as errors..."
xcodebuild clean build \
  -project backdoor.xcodeproj \
  -scheme 'backdoor (Debug)' \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
  GCC_TREAT_WARNINGS_AS_ERRORS=YES \
  | tee build/reports/xcpretty/build_check.txt | xcpretty --color || echo "::warning::Build check found issues that need to be fixed"

echo "Running deep code analysis with xcpretty..."
xcodebuild analyze \
  -project backdoor.xcodeproj \
  -scheme 'backdoor (Debug)' \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CLANG_ANALYZER_OUTPUT=html \
  CLANG_ANALYZER_OUTPUT_DIR=build/reports/analyzer \
  RUN_CLANG_STATIC_ANALYZER=YES \
  | tee build/reports/xcpretty/analyzer_output.txt | xcpretty --color --report html --output build/reports/xcpretty/analysis.html

# Count errors and warnings
ERROR_COUNT=$(grep -c "error:" build/reports/xcpretty/analyzer_output.txt || echo 0)
WARNING_COUNT=$(grep -c "warning:" build/reports/xcpretty/analyzer_output.txt || echo 0)

echo "Analysis found $ERROR_COUNT errors and $WARNING_COUNT warnings"

# Create a summary markdown file
echo "# XCPretty Analysis Results" > build/reports/xcpretty/summary.md
echo "## Issues Found" >> build/reports/xcpretty/summary.md
echo "* Errors: $ERROR_COUNT" >> build/reports/xcpretty/summary.md
echo "* Warnings: $WARNING_COUNT" >> build/reports/xcpretty/summary.md

echo "## Error Details" >> build/reports/xcpretty/summary.md
grep "error:" build/reports/xcpretty/analyzer_output.txt | sort -u >> build/reports/xcpretty/summary.md || echo "No errors found"

echo "## Warning Details" >> build/reports/xcpretty/summary.md
grep "warning:" build/reports/xcpretty/analyzer_output.txt | sort -u >> build/reports/xcpretty/summary.md || echo "No warnings found"

echo "XCPretty analysis complete"
