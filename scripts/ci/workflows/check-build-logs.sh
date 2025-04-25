#!/bin/bash
set -eo pipefail

# Script to check if build logs were found and set GitHub outputs
# Usage: ./check-build-logs.sh

# Look for build logs in the expected location
if [ -f "build_log.txt" ] && [ -s "build_log.txt" ]; then
    echo "build_log_found=true" >> $GITHUB_OUTPUT
    echo "✅ Build log found and ready for analysis"
else
    echo "build_log_found=false" >> $GITHUB_OUTPUT
    echo "⚠️ No valid build logs found in artifacts"
    
    # Create the output directory if it doesn't exist
    mkdir -p build-logs
    
    # Look for any potential log files
    FOUND_LOGS=$(find . -type f -name "*.log" -o -name "*.txt")
    
    if [ -n "$FOUND_LOGS" ]; then
        echo "Found potential log files:"
        echo "$FOUND_LOGS"
        
        # Copy the first log file found as a fallback
        FIRST_LOG=$(echo "$FOUND_LOGS" | head -n 1)
        if [ -n "$FIRST_LOG" ]; then
            echo "Using $FIRST_LOG as fallback log"
            cp "$FIRST_LOG" "build_log.txt"
            echo "build_log_found=true" >> $GITHUB_OUTPUT
        fi
    fi
fi
