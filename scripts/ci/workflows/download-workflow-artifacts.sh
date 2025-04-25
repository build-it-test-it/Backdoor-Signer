#!/bin/bash
set -eo pipefail

# Script to download artifacts from a GitHub workflow run
# Usage: ./download-workflow-artifacts.sh WORKFLOW_RUN_ID

WORKFLOW_RUN_ID="$1"
if [ -z "$WORKFLOW_RUN_ID" ]; then
    echo "::error::No workflow run ID provided"
    exit 1
fi

echo "Downloading artifacts for workflow run: $WORKFLOW_RUN_ID"

# Create a temporary script to download artifacts using GitHub API
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
    
    // Download all artifacts
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

# Clean up temporary files
rm -rf temp

echo "✅ Artifact download complete"
