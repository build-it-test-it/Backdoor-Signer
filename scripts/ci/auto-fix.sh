#!/bin/bash
# Setting this to ensure the workflow fails if there are unhandled errors
set -eo pipefail

echo "Running auto-fix scripts for code quality issues..."

# Auto-fix SwiftLint issues
echo "Automatically fixing SwiftLint issues..."
# Fix the SwiftLint command to properly autocorrect files
find . -name "*.swift" -not -path "*/\.*" -not -path "*/Pods/*" -not -path "*/Carthage/*" -not -path "*/DerivedData/*" | xargs swiftlint --fix --config Clean/.swiftlint.yml || {
    echo "⚠️ SwiftLint autocorrect encountered issues, but continuing..."
}

# Create a minimal swiftformat config with only the most basic options
echo "Creating minimal SwiftFormat config..."
TEMP_SWIFTFORMAT="./.temp-swiftformat-config"
cat > $TEMP_SWIFTFORMAT << EOF
--indent 4
--trimwhitespace always
--semicolons never
--header strip
--linebreaks lf
--maxwidth 120
EOF

# First try with the minimal config
echo "Automatically fixing SwiftFormat issues with minimal config..."
swiftformat . --config $TEMP_SWIFTFORMAT || {
    echo "⚠️ SwiftFormat encountered issues with minimal config, trying individual rules..."
    
    # If the config approach fails, try applying individual rules one by one
    echo "Applying individual formatting rules..."
    swiftformat . --indent 4 || true
    swiftformat . --trimwhitespace always || true
    swiftformat . --semicolons never || true
    swiftformat . --linebreaks lf || true
    swiftformat . --maxwidth 120 || true
    
    echo "Basic formatting applied despite configuration issues."
}

# Auto-fix Clang-Format issues
echo "Creating basic .clang-format configuration..."
cat > .clang-format << EOF
BasedOnStyle: LLVM
IndentWidth: 4
TabWidth: 4
UseTab: Never
ColumnLimit: 120
BreakBeforeBraces: Allman
IndentCaseLabels: true
AlignAfterOpenBracket: Align
SpaceBeforeParens: ControlStatements
EOF

echo "Automatically fixing Clang-Format issues..."
find . -type f \( -name "*.m" -o -name "*.mm" -o -name "*.h" -o -name "*.c" -o -name "*.cpp" -o -name "*.hpp" \) -not -path "*/\.*" -not -path "*/Pods/*" -not -path "*/Carthage/*" -not -path "*/DerivedData/*" -exec clang-format -i -style=file {} \;

# Clean up temporary files
rm -f .clang-format
rm -f $TEMP_SWIFTFORMAT

echo "Auto-fix complete"
# Exit with success - even with warnings, we want the process to continue for the commit step
exit 0
