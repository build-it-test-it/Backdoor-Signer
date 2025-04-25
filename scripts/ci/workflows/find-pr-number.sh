#!/bin/bash
set -eo pipefail

# Script to find PR number from a workflow run
# Usage: ./find-pr-number.sh WORKFLOW_RUN_ID

WORKFLOW_RUN_ID="$1"
if [ -z "$WORKFLOW_RUN_ID" ]; then
    echo "::error::No workflow run ID provided"
    exit 1
fi

echo "Finding PR number for workflow run: $WORKFLOW_RUN_ID"

# Create temporary script to find PR number
mkdir -p temp
cat > temp/find-pr.js << 'EOL'
const fs = require('fs');

async function findPrNumber() {
  try {
    // Parse inputs
    const workflowRunId = process.env.WORKFLOW_RUN_ID;
    const token = process.env.GITHUB_TOKEN;
    const [owner, repo] = process.env.GITHUB_REPOSITORY.split('/');
    
    if (!workflowRunId || !token || !owner || !repo) {
      console.error('Missing required environment variables');
      process.exit(1);
    }
    
    // Create the Octokit client
    const { Octokit } = require('@octokit/rest');
    const octokit = new Octokit({ auth: token });
    
    // Get the workflow run
    const run = await octokit.actions.getWorkflowRun({
      owner,
      repo,
      run_id: workflowRunId
    });
    
    // Extract PR number from the run data
    const prNumber = run.data.pull_requests[0]?.number;
    if (prNumber) {
      console.log(`Found PR number: ${prNumber}`);
      // Write the PR number to a file for the bash script to read
      fs.writeFileSync('pr_number.txt', prNumber.toString());
      process.exit(0);
    } else {
      console.log("Could not determine PR number from workflow run");
      process.exit(1);
    }
  } catch (error) {
    console.error('Error finding PR number:', error.message);
    process.exit(1);
  }
}

findPrNumber();
EOL

# Install octokit if needed
npm install @octokit/rest

# Set environment variables and run the script
export WORKFLOW_RUN_ID="$WORKFLOW_RUN_ID"
export GITHUB_TOKEN="${GITHUB_TOKEN}"

echo "Running PR finder script..."
node temp/find-pr.js

# Read PR number from file
if [ -f "pr_number.txt" ]; then
    PR_NUMBER=$(cat pr_number.txt)
    echo "pr_number=$PR_NUMBER" >> $GITHUB_OUTPUT
    echo "✅ Found PR #$PR_NUMBER"
else
    echo "pr_number=" >> $GITHUB_OUTPUT
    echo "⚠️ No PR number found"
fi

# Clean up temporary files
rm -rf temp pr_number.txt

echo "✅ PR number search complete"
