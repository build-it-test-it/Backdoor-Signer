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

# Create a simplified swiftformat config to avoid compatibility problems
echo "Creating compatible SwiftFormat config..."
TEMP_SWIFTFORMAT="./.temp-swiftformat-config"
cat > $TEMP_SWIFTFORMAT << EOF
--indent 4
--indentcase true
--trimwhitespace always
--importgrouping alphabetized
--semicolons never
--header strip
--disable redundantSelf
--linebreaks lf
--maxwidth 120
--wraparguments beforeFirst
--wrapparameters beforeFirst
--closureparameters sameLine
--trailingclosures always
--allman true
--spacearoundoperators true
EOF

# Auto-fix SwiftFormat issues with compatibility mode
echo "Automatically fixing SwiftFormat issues..."
swiftformat . --config $TEMP_SWIFTFORMAT || {
    echo "⚠️ SwiftFormat encountered issues, but continuing..."
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
