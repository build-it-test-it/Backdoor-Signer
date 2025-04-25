#!/bin/bash
set -e

echo "Running auto-fix scripts for code quality issues..."

# Auto-fix SwiftLint issues
echo "Automatically fixing SwiftLint issues..."
swiftlint autocorrect --config Clean/.swiftlint.yml || true

# Auto-fix SwiftFormat issues
echo "Automatically fixing SwiftFormat issues..."
swiftformat . --config Clean/.swiftformat || true

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

# Clean up temporary .clang-format
rm -f .clang-format

echo "Auto-fix complete"
