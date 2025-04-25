#!/bin/bash
set -eo pipefail

# Enhanced Artifact Downloader Script
# Downloads workflow artifacts and finds build logs with improved fallback mechanisms

echo "📦 Enhanced Artifact Handler: Finding and processing build logs"

# Validate required inputs
WORKFLOW_RUN_ID="$1"
if [ -z "$WORKFLOW_RUN_ID" ]; then
  echo "::error::No workflow run ID provided"
  exit 1
fi

# Create directories for organized processing
mkdir -p artifact-extracts
mkdir -p build-logs

# Download artifacts using GitHub API
download_artifacts() {
  echo "📥 Downloading artifacts for workflow run: $WORKFLOW_RUN_ID"
  
  # Create a temporary script to download artifacts
  mkdir -p temp
  cat > temp/download-artifacts.js << 'EOL'
const fs = require('fs');

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
    
    // Download all artifacts to analyze
    for (const artifact of artifactsList.artifacts) {
      console.log(`Downloading: ${artifact.name} (${artifact.id})`);
      
      const download = await octokit.actions.downloadArtifact({
        owner,
        repo,
        artifact_id: artifact.id,
        archive_format: 'zip'
      });
      
      // Save with artifact name to keep track of everything
      const filename = `${artifact.name.replace(/[
^
a-zA-Z0-9]/g, '_')}.zip`;
      fs.writeFileSync(filename, Buffer.from(download.data));
      console.log(`Saved to ${filename}`);
    }
    
    console.log('All artifacts downloaded successfully');
    process.exit(0);
  } catch (error) {
    console.error('Error downloading artifacts:', error.message);
    process.exit(1);
  }
}

downloadArtifacts();
EOL

  # Install octokit if needed
  npm install @octokit/rest

  # Set environment variables and run the script
  export WORKFLOW_RUN_ID="$WORKFLOW_RUN_ID"
  export GITHUB_TOKEN="${GITHUB_TOKEN}"

  echo "Running download script..."
  node temp/download-artifacts.js
}

# Extract all artifacts and find build logs
process_artifacts() {
  echo "📂 Processing artifacts and searching for build logs..."
  
  # Find all artifacts
  ARTIFACT_ZIPS=$(find . -name "*.zip" -type f)
  
  if [ -z "$ARTIFACT_ZIPS" ]; then
    echo "::warning::No artifact ZIP files found"
    return 1
  fi
  
  # Extract each artifact to its own directory
  for ZIP_FILE in $ARTIFACT_ZIPS; do
    ARTIFACT_NAME=$(basename "$ZIP_FILE" .zip)
    EXTRACT_DIR="artifact-extracts/$ARTIFACT_NAME"
    
    echo "Extracting $ZIP_FILE to $EXTRACT_DIR"
    mkdir -p "$EXTRACT_DIR"
    unzip -q -o "$ZIP_FILE" -d "$EXTRACT_DIR" || echo "Warning: Extraction issues with $ZIP_FILE"
    
    # Look for build logs in the extracted content
    find "$EXTRACT_DIR" -type f -name "*.log" -o -name "*.txt" | while read -r LOG_FILE; do
      echo "Checking potential log: $LOG_FILE"
      
      # Check if this looks like a build log
      if grep -q -E "error:|warning:|fatal error:|linker command failed|swift|xcodebuild" "$LOG_FILE"; then
        echo "✅ Found build log: $LOG_FILE"
        cp "$LOG_FILE" "build-logs/$(basename "$LOG_FILE")"
      fi
    done
  done
  
  # Also check the main artifact-contents directory if it exists
  if [ -d "artifact-contents" ]; then
    echo "Checking artifact-contents directory..."
    
    # Look for build logs there too
    find "artifact-contents" -type f -name "*.log" -o -name "*.txt" | while read -r LOG_FILE; do
      if grep -q -E "error:|warning:|fatal error:|linker command failed|swift|xcodebuild" "$LOG_FILE"; then
        echo "✅ Found build log in artifact-contents: $LOG_FILE"
        cp "$LOG_FILE" "build-logs/$(basename "$LOG_FILE")"
      fi
    done
  fi
}

# Combine logs into a single file
combine_logs() {
  echo "Combining logs for analysis..."
  
  if [ -z "$(ls -A build-logs 2>/dev/null)" ]; then
    echo "::warning::No build logs found in artifacts"
    
    # Look for build logs in original location as fallback
    if [ -f "artifact-contents/build_log.txt" ]; then
      echo "Using original build_log.txt as fallback"
      cp artifact-contents/build_log.txt ./build_log.txt
      return 0
    elif [ -f "artifact-contents/xcodebuild.log" ]; then
      echo "Using xcodebuild.log as fallback"
      cp artifact-contents/xcodebuild.log ./build_log.txt
      return 0
    else
      # Create an empty log file to prevent errors in subsequent steps
      echo "No build log found. This is a placeholder." > build_log.txt
      return 1
    fi
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
download_artifacts
process_artifacts
combine_logs

# Clean up temporary files
rm -rf temp

echo "✅ Enhanced artifact processing complete"
echo "Log files ready for analysis: build_log.txt"
