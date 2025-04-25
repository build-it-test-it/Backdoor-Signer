#!/bin/bash
set -e

echo "Running SwiftFormat with project-specific configuration..."

# Ensure output directory exists
mkdir -p build/reports/swiftformat

# Find Swift files and check formatting with dry run
find . -name "*.swift" -type f -not -path "*/\.*" -not -path "*/Pods/*" -not -path "*/Carthage/*" -not -path "*/DerivedData/*" | xargs swiftformat --config Clean/.swiftformat --dryrun > build/reports/swiftformat/changes.txt 2>&1 || true

# Create a summary markdown file
echo "# SwiftFormat Issues Summary" > build/reports/swiftformat/summary.md
echo "## Files with formatting issues:" >> build/reports/swiftformat/summary.md
grep "would have formatted" build/reports/swiftformat/changes.txt | sort | uniq >> build/reports/swiftformat/summary.md || echo "No formatting issues found" >> build/reports/swiftformat/summary.md

# Run in lint mode to generate a more structured report
swiftformat --config Clean/.swiftformat --lint . > build/reports/swiftformat/lint_results.txt 2>&1 || echo "SwiftFormat found issues that should be addressed"

echo "SwiftFormat analysis complete"
