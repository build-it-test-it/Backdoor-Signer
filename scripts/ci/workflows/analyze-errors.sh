#!/bin/bash
set -eo pipefail

# Script to run the error analysis on build logs
# Usage: ./analyze-errors.sh [log_file]

LOG_FILE="${1:-build_log.txt}"

echo "Analyzing build errors in $LOG_FILE..."

# Run the Python error analyzer
python3 scripts/ci/auto-fix-build-errors.py "$LOG_FILE" || echo "Analysis completed with warnings"

# Check if reports were generated
if [ -f "build_error_report.html" ]; then
    echo "report_generated=true" >> $GITHUB_OUTPUT
    echo "✅ Build error report generated successfully"
else
    echo "report_generated=false" >> $GITHUB_OUTPUT
    echo "⚠️ No error report was generated"
fi

echo "✅ Error analysis complete"
