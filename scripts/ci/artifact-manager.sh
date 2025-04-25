#!/bin/bash
set -eo pipefail

# Focused Artifact Manager Script
# Prioritizes finding and analyzing build logs from artifacts

echo "📦 Artifact Manager: Finding build logs in artifacts"

# Create directories for organized processing
mkdir -p artifact-extracts
mkdir -p build-logs

# Find all artifacts in the current directory and artifact-contents
find_artifacts() {
  echo "🔍 Searching for artifact files..."
  
  # Common locations where artifacts might be found in GitHub Actions
  ARTIFACT_DIRS=(
    "."
    "artifact-contents"
    "artifacts"
    "downloads"
    "/home/runner/work/_temp"
  )
  
  # Look for zip files in these directories
  for DIR in "${ARTIFACT_DIRS[@]}"; do
    if [ -d "$DIR" ]; then
      echo "Searching in $DIR"
      find "$DIR" -name "*.zip" -type f | while read -r ZIP_FILE; do
        echo "Found artifact: $ZIP_FILE"
        extract_artifact "$ZIP_FILE"
      done
    fi
  done
}

# Extract an artifact file
extract_artifact() {
  ZIP_FILE="$1"
  EXTRACT_DIR="artifact-extracts/$(basename "$ZIP_FILE" .zip)"
  
  echo "Extracting $ZIP_FILE to $EXTRACT_DIR"
  mkdir -p "$EXTRACT_DIR"
  unzip -q -o "$ZIP_FILE" -d "$EXTRACT_DIR" || echo "Warning: Extraction issues with $ZIP_FILE"
  
  # Look for build logs in the extracted content
  find_logs_in_extract "$EXTRACT_DIR"
}

# Find log files in an extracted artifact
find_logs_in_extract() {
  EXTRACT_DIR="$1"
  echo "Searching for logs in $EXTRACT_DIR"
  
  # Common build log patterns
  LOG_PATTERNS=(
    "*build*.log"
    "*build*.txt"
    "*xcodebuild*.log"
    "*output*.log"
    "*compile*.log"
    "*.build.log"
    "*.txt"
  )
  
  # Find all potential log files
  for PATTERN in "${LOG_PATTERNS[@]}"; do
    find "$EXTRACT_DIR" -type f -iname "$PATTERN" 2>/dev/null | while read -r LOG_FILE; do
      echo "Checking potential log: $LOG_FILE"
      
      # Check if this looks like a build log (contains error/warning messages)
      if grep -q -E "error:|warning:|fatal error:|linker command failed|swift|xcodebuild" "$LOG_FILE"; then
        echo "✅ Found build log: $LOG_FILE"
        cp "$LOG_FILE" "build-logs/$(basename "$LOG_FILE")"
      fi
    done
  done
}

# Combine all found logs into a single file for analysis
combine_logs() {
  echo "Combining logs for analysis..."
  
  if [ -z "$(ls -A build-logs 2>/dev/null)" ]; then
    echo "::warning::No build logs found in artifacts"
    echo "No build log found. This is a placeholder." > build_log.txt
    return 1
  fi
  
  # Combine all logs with headers separating them
  > combined_build_log.txt
  for LOG_FILE in build-logs/*; do
    echo "=== $(basename "$LOG_FILE") ===" >> combined_build_log.txt
    echo "" >> combined_build_log.txt
    cat "$LOG_FILE" >> combined_build_log.txt
    echo "" >> combined_build_log.txt
    echo "=== END OF $(basename "$LOG_FILE") ===" >> combined_build_log.txt
    echo "" >> combined_build_log.txt
  done
  
  # Create the main build log file for backward compatibility
  cp combined_build_log.txt build_log.txt
  echo "Created combined log file: build_log.txt"
  
  # Create a manifest of log files
  find build-logs -type f | sort > build-logs/log_manifest.txt
  echo "Created log manifest: build-logs/log_manifest.txt"
  
  return 0
}

# Main execution flow
find_artifacts
combine_logs

# Summary
echo "✅ Artifact processing complete"
if [ -f "build_log.txt" ]; then
  echo "Log files ready for analysis: build_log.txt"
  echo "Individual logs available in: build-logs/"
fi
