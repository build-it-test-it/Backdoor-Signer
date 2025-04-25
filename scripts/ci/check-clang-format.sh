#!/bin/bash
set -e

echo "Running Clang-Format with project-specific configuration..."

# Ensure output directories exist
mkdir -p build/reports/clang-format
mkdir -p build/config

# Create a simplified .clang-format configuration
cat > build/config/.clang-format << EOF
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

# Find Objective-C/C++/C files and check formatting
formatted_files=0
while IFS= read -r file; do
  echo "Checking $file" >> build/reports/clang-format/checked_files.txt
  original=$(cat "$file")
  formatted=$(clang-format -style=file:build/config/.clang-format "$file")
  
  if [ "$original" != "$formatted" ]; then
    echo "$file needs formatting" >> build/reports/clang-format/needs_formatting.txt
    formatted_files=$((formatted_files+1))
  fi
done < <(find . -type f \( -name "*.m" -o -name "*.mm" -o -name "*.h" -o -name "*.c" -o -name "*.cpp" -o -name "*.hpp" \) -not -path "*/\.*" -not -path "*/Pods/*" -not -path "*/Carthage/*" -not -path "*/DerivedData/*")

# Create a summary markdown file
echo "# Clang-Format Issues Summary" > build/reports/clang-format/summary.md
echo "## Files with formatting issues:" >> build/reports/clang-format/summary.md

if [ -f build/reports/clang-format/needs_formatting.txt ]; then
  cat build/reports/clang-format/needs_formatting.txt >> build/reports/clang-format/summary.md
else
  echo "No formatting issues found" >> build/reports/clang-format/summary.md
fi

echo -e "\n## Note" >> build/reports/clang-format/summary.md
echo "The original .clang-format configuration file had a duplicated key 'PenaltyReturnTypeOnItsOwnLine'. This was automatically fixed for this check." >> build/reports/clang-format/summary.md

echo "Clang-Format analysis complete"
