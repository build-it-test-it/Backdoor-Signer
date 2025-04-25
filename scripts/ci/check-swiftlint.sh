#!/bin/bash
set -e

echo "Running SwiftLint with project-specific configuration..."

# Ensure output directory exists
mkdir -p build/reports/swiftlint

# Run SwiftLint with various reporters
swiftlint lint --config Clean/.swiftlint.yml --reporter json > build/reports/swiftlint/swiftlint.json || true
swiftlint lint --config Clean/.swiftlint.yml --reporter html > build/reports/swiftlint/swiftlint.html || true
swiftlint lint --config Clean/.swiftlint.yml --strict || echo "WARNING: SwiftLint found issues that should be addressed"

# Create a summary markdown file
echo "# SwiftLint Issues Summary" > build/reports/swiftlint/summary.md
echo "## Critical Issues" >> build/reports/swiftlint/summary.md

# Extract critical issues (assuming jq is installed)
if command -v jq &> /dev/null; then
  jq -r '.[] | select(.severity == "Error") | "Rule: \(.rule_id)\nReason: \(.reason)\nLine: \(.line)\nCharacter: \(.character)\n---"' build/reports/swiftlint/swiftlint.json >> build/reports/swiftlint/summary.md || echo "No critical issues found" >> build/reports/swiftlint/summary.md
else
  # Fallback if jq is not available
  grep -A 3 '"severity":"Error"' build/reports/swiftlint/swiftlint.json | grep -E '"rule"|"reason"|"line"|"character"' >> build/reports/swiftlint/summary.md || echo "No critical issues found" >> build/reports/swiftlint/summary.md
fi

echo "SwiftLint analysis complete"
