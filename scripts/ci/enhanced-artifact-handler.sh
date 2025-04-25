#!/bin/bash
set -eo pipefail

# Enhanced Artifact Handler Script
# This script downloads, extracts, and processes GitHub workflow artifacts
# with improved log file discovery and analysis

echo "📦 Enhanced Artifact Handler: Starting artifact processing"

# Validate required inputs
WORKFLOW_RUN_ID="$1"
if [ -z "$WORKFLOW_RUN_ID" ]; then
  echo "::error::No workflow run ID provided"
  exit 1
fi

# Create directories
mkdir -p artifact-downloads
mkdir -p extracted-artifacts
mkdir -p logs-for-analysis

# Function to download artifacts
download_artifacts() {
  echo "📥 Downloading artifacts for workflow run $WORKFLOW_RUN_ID"
  
  # Create a temporary Node.js script for artifact downloading
  mkdir -p temp
  cat > temp/download-artifacts.js << 'EOL'
const fs = require('fs');
const path = require('path');

async function downloadArtifacts() {
  try {
    // Parse inputs
    const workflowRunId = process.env.WORKFLOW_RUN_ID;
    const token = process.env.GITHUB_TOKEN;
    const [owner, repo] = process.env.GITHUB_REPOSITORY.split('/');
    
    if (!workflowRunId || !token || !owner || !repo) {
      console.error('Missing required environment variables');
      process.exit(1);
    }
    
    console.log(`Downloading artifacts for workflow run ${workflowRunId} in ${owner}/${repo}`);
    
    // Create the Octokit client
    const { Octokit } = require('@octokit/rest');
    const octokit = new Octokit({ auth: token });
    
    // List artifacts
    const { data: artifactsList } = await octokit.actions.listWorkflowRunArtifacts({
      owner,
      repo,
      run_id: workflowRunId
    });
    
    if (!artifactsList.artifacts.length) {
      console.log("No artifacts found for this workflow run");
      process.exit(0);
    }
    
    console.log(`Found ${artifactsList.artifacts.length} artifacts`);
    
    // Download all artifacts, not just build logs
    // This way we can find logs regardless of artifact name
    let artifactsManifest = [];
    
    for (const artifact of artifactsList.artifacts) {
      console.log(`Downloading artifact: ${artifact.name} (${artifact.id})`);
      
      const download = await octokit.actions.downloadArtifact({
        owner,
        repo,
        artifact_id: artifact.id,
        archive_format: 'zip'
      });
      
      // Save the zip file with a unique name
      const zipFilename = `artifact-downloads/${artifact.name.replace(/[
^
a-zA-Z0-9]/g, '_')}.zip`;
      fs.writeFileSync(zipFilename, Buffer.from(download.data));
      
      // Add to manifest
      artifactsManifest.push({
        id: artifact.id,
        name: artifact.name,
        size: artifact.size_in_bytes,
        zip_path: zipFilename
      });
      
      console.log(`Saved artifact to ${zipFilename}`);
    }
    
    // Save the manifest file
    fs.writeFileSync('artifact-manifest.json', JSON.stringify(artifactsManifest, null, 2));
    console.log('Successfully created artifact manifest');
    process.exit(0);
  } catch (error) {
    console.error('Error downloading artifacts:', error.message);
    process.exit(1);
  }
}

downloadArtifacts();
EOL

  # Install octokit
  npm install @octokit/rest

  # Set environment variables and run the script
  export WORKFLOW_RUN_ID="$WORKFLOW_RUN_ID"
  export GITHUB_TOKEN="${GITHUB_TOKEN}"

  echo "Running download script..."
  node temp/download-artifacts.js
}

# Function to extract all downloaded artifacts
extract_artifacts() {
  echo "📂 Extracting artifacts..."
  
  # Get list of downloaded artifacts
  ARTIFACT_ZIPS=$(find artifact-downloads -name "*.zip")
  
  if [ -z "$ARTIFACT_ZIPS" ]; then
    echo "::warning::No artifact ZIP files found"
    return 1
  fi
  
  # Extract each artifact to its own directory
  for ZIP_FILE in $ARTIFACT_ZIPS; do
    ARTIFACT_NAME=$(basename "$ZIP_FILE" .zip)
    EXTRACT_DIR="extracted-artifacts/$ARTIFACT_NAME"
    
    echo "Extracting $ZIP_FILE to $EXTRACT_DIR"
    mkdir -p "$EXTRACT_DIR"
    unzip -o "$ZIP_FILE" -d "$EXTRACT_DIR" || echo "Warning: Extraction issues with $ZIP_FILE"
    
    # List extracted contents
    find "$EXTRACT_DIR" -type f | sort > "$EXTRACT_DIR/file_list.txt"
    echo "Extracted $(wc -l < "$EXTRACT_DIR/file_list.txt") files from $ARTIFACT_NAME"
  done
}

# Function to find log files across all extracted artifacts
find_log_files() {
  echo "🔍 Searching for build log files..."
  
  # Common log file patterns for build logs
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
  FOUND_LOGS=()
  
  for PATTERN in "${LOG_PATTERNS[@]}"; do
    # Use find with case-insensitive matching
    while IFS= read -r LOG_FILE; do
      # Only include if it's a file
      if [ -f "$LOG_FILE" ]; then
        FOUND_LOGS+=("$LOG_FILE")
        echo "Found potential log: $LOG_FILE"
      fi
    done < <(find extracted-artifacts -type f -iname "$PATTERN" 2>/dev/null || echo "")
  done
  
  if [ ${#FOUND_LOGS[@]} -eq 0 ]; then
    echo "::warning::No log files found in artifacts"
    return 1
  fi
  
  echo "Found ${#FOUND_LOGS[@]} potential log files"
  
  # Copy log files to analysis directory
  mkdir -p logs-for-analysis
  
  # First, look for obvious build logs - higher priority
  for LOG_FILE in "${FOUND_LOGS[@]}"; do
    # Check if the file is likely a build log by looking for common patterns
    if grep -q -E "error:|warning:|fatal error:|linker command failed|swift" "$LOG_FILE"; then
      LOG_BASENAME=$(basename "$LOG_FILE")
      echo "Copying build log: $LOG_FILE → logs-for-analysis/$LOG_BASENAME"
      cp "$LOG_FILE" "logs-for-analysis/$LOG_BASENAME"
    fi
  done
  
  # If we didn't find any obvious build logs, copy all potential logs
  if [ -z "$(ls -A logs-for-analysis)" ]; then
    echo "No obvious build logs found, copying all potential logs"
    for LOG_FILE in "${FOUND_LOGS[@]}"; do
      LOG_BASENAME=$(basename "$LOG_FILE")
      cp "$LOG_FILE" "logs-for-analysis/$LOG_BASENAME"
    done
  fi
  
  # Create a combined log file for easier analysis
  if [ -n "$(ls -A logs-for-analysis)" ]; then
    echo "Creating combined log file"
    cat logs-for-analysis/* > logs-for-analysis/combined_build_logs.txt
    echo "Created combined log file: logs-for-analysis/combined_build_logs.txt"
    
    # Create a main build_log.txt for backward compatibility
    cp logs-for-analysis/combined_build_logs.txt ./build_log.txt
    echo "Created main build log: ./build_log.txt"
    
    # Create a manifest of log files
    find logs-for-analysis -type f | sort > logs-for-analysis/log_file_manifest.txt
    echo "Created log file manifest: logs-for-analysis/log_file_manifest.txt"
  else
    echo "::warning::No log files found for analysis"
    # Create an empty log file to prevent errors in subsequent steps
    echo "No build log found. This is a placeholder." > build_log.txt
    return 1
  fi
}

# Main execution flow
download_artifacts
extract_artifacts
find_log_files

# Clean up temporary files
rm -rf temp

echo "✅ Enhanced artifact processing complete"
echo "Log files are ready for analysis in the 'logs-for-analysis' directory"
echo "Combined log is available at: ./build_log.txt"
