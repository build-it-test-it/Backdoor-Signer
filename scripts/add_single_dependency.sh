#!/bin/bash

# Script to add a single Swift Package dependency to the project
# This is a convenience wrapper around add_dependency.py

set -e

# Function to show usage information
show_usage() {
  echo "Usage: $0 --name NAME --url URL --kind KIND [--version VERSION] [--branch BRANCH] [--revision REVISION] --products PRODUCT1,PRODUCT2,..."
  echo ""
  echo "Arguments:"
  echo "  --name NAME          The name of the package"
  echo "  --url URL            The repository URL of the package"
  echo "  --kind KIND          The requirement kind: upToNextMajorVersion, exactVersion, branch, or revision"
  echo "  --version VERSION    The version for upToNextMajorVersion or exactVersion requirement (e.g., 1.0.0)"
  echo "  --branch BRANCH      The branch name for branch requirement"
  echo "  --revision REVISION  The commit hash for revision requirement"
  echo "  --products PRODUCTS  Comma-separated list of product names to include"
  echo "  --update-file        Update dep-bdg.json with this dependency instead of using a temporary file"
  echo ""
  echo "Examples:"
  echo "  $0 --name SDWebImage --url https://github.com/SDWebImage/SDWebImage.git --kind upToNextMajorVersion --version 5.18.3 --products SDWebImage,SDWebImageMapKit"
  echo "  $0 --name SwiftUIX --url https://github.com/SwiftUIX/SwiftUIX.git --kind branch --branch main --products SwiftUIX"
  echo "  $0 --name KeychainAccess --url https://github.com/kishikawakatsumi/KeychainAccess.git --kind exactVersion --version 4.2.2 --products KeychainAccess --update-file"
  exit 1
}

# Initialize variables
NAME=""
URL=""
KIND=""
VERSION=""
BRANCH=""
REVISION=""
PRODUCTS=""
UPDATE_FILE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)
      NAME="$2"
      shift 2
      ;;
    --url)
      URL="$2"
      shift 2
      ;;
    --kind)
      KIND="$2"
      shift 2
      ;;
    --version)
      VERSION="$2"
      shift 2
      ;;
    --branch)
      BRANCH="$2"
      shift 2
      ;;
    --revision)
      REVISION="$2"
      shift 2
      ;;
    --products)
      PRODUCTS="$2"
      shift 2
      ;;
    --update-file)
      UPDATE_FILE=true
      shift
      ;;
    --help)
      show_usage
      ;;
    *)
      echo "Unknown option: $1"
      show_usage
      ;;
  esac
done

# Validate required arguments
if [[ -z "$NAME" || -z "$URL" || -z "$KIND" || -z "$PRODUCTS" ]]; then
  echo "Error: Missing required arguments"
  show_usage
fi

# Validate requirement kind and associated values
if [[ "$KIND" == "upToNextMajorVersion" || "$KIND" == "exactVersion" ]]; then
  if [[ -z "$VERSION" ]]; then
    echo "Error: --version is required for kind '$KIND'"
    show_usage
  fi
elif [[ "$KIND" == "branch" ]]; then
  if [[ -z "$BRANCH" ]]; then
    echo "Error: --branch is required for kind 'branch'"
    show_usage
  fi
elif [[ "$KIND" == "revision" ]]; then
  if [[ -z "$REVISION" ]]; then
    echo "Error: --revision is required for kind 'revision'"
    show_usage
  fi
else
  echo "Error: Invalid kind '$KIND'. Must be one of: upToNextMajorVersion, exactVersion, branch, revision"
  show_usage
fi

# Convert comma-separated products to JSON array
IFS=',' read -ra PRODUCT_ARRAY <<< "$PRODUCTS"
PRODUCTS_JSON=""
for product in "${PRODUCT_ARRAY[@]}"; do
  if [[ -n "$PRODUCTS_JSON" ]]; then
    PRODUCTS_JSON+=",$product"
  else
    PRODUCTS_JSON="$product"
  fi
done
PRODUCTS_JSON=$(echo "$PRODUCTS_JSON" | sed 's/\([^,]*\)/"\1"/g')

# Create dependency JSON
create_dependency_json() {
  local json=""
  
  if [[ "$KIND" == "upToNextMajorVersion" ]]; then
    json='{
    "name": "'$NAME'",
    "url": "'$URL'",
    "requirement": {
      "kind": "upToNextMajorVersion",
      "minimumVersion": "'$VERSION'"
    },
    "products": ['$PRODUCTS_JSON']
  }'
  elif [[ "$KIND" == "exactVersion" ]]; then
    json='{
    "name": "'$NAME'",
    "url": "'$URL'",
    "requirement": {
      "kind": "exactVersion",
      "version": "'$VERSION'"
    },
    "products": ['$PRODUCTS_JSON']
  }'
  elif [[ "$KIND" == "branch" ]]; then
    json='{
    "name": "'$NAME'",
    "url": "'$URL'",
    "requirement": {
      "kind": "branch",
      "branch": "'$BRANCH'"
    },
    "products": ['$PRODUCTS_JSON']
  }'
  elif [[ "$KIND" == "revision" ]]; then
    json='{
    "name": "'$NAME'",
    "url": "'$URL'",
    "requirement": {
      "kind": "revision",
      "revision": "'$REVISION'"
    },
    "products": ['$PRODUCTS_JSON']
  }'
  fi
  
  echo "$json"
}

# Handle updating dep-bdg.json
if [ "$UPDATE_FILE" = true ]; then
  DEPENDENCY_FILE="dep-bdg.json"
  
  # Create the file if it doesn't exist
  if [ ! -f "$DEPENDENCY_FILE" ]; then
    echo "Creating new $DEPENDENCY_FILE file"
    echo "[]" > "$DEPENDENCY_FILE"
  fi
  
  # Add dependency to the file
  DEPENDENCY_JSON=$(create_dependency_json)
  
  # Use jq if available for pretty formatting, otherwise use a simple approach
  if command -v jq &> /dev/null; then
    # Check if the file is empty or contains only whitespace
    if [ ! -s "$DEPENDENCY_FILE" ] || [ "$(cat "$DEPENDENCY_FILE" | tr -d '[:space:]')" = "" ]; then
      echo "[$DEPENDENCY_JSON]" | jq '.' > "$DEPENDENCY_FILE"
    else
      # Use jq to add the dependency
      TEMP_CONTENT=$(cat "$DEPENDENCY_FILE" | jq ". += [$DEPENDENCY_JSON]")
      echo "$TEMP_CONTENT" > "$DEPENDENCY_FILE"
    fi
  else
    # Simple approach without jq
    if [ "$(cat "$DEPENDENCY_FILE" | tr -d '[:space:]')" = "[]" ]; then
      # File is empty or just contains []
      echo "[$DEPENDENCY_JSON]" > "$DEPENDENCY_FILE"
    else
      # Append to existing array
      # Remove the closing bracket, add a comma and the new dependency, then close the array
      sed -i.bak '$s/]$/,/' "$DEPENDENCY_FILE"
      echo "$DEPENDENCY_JSON]" >> "$DEPENDENCY_FILE"
      rm -f "${DEPENDENCY_FILE}.bak"
    fi
  fi
  
  echo "Updated $DEPENDENCY_FILE with dependency: $NAME"
  
  # Run the Python script with the updated file
  python scripts/add_dependency.py "$DEPENDENCY_FILE"
else
  # Create temporary JSON file
  TEMP_FILE=$(mktemp)
  trap "rm -f $TEMP_FILE" EXIT
  
  # Create temp file with a single dependency
  echo "[$(create_dependency_json)]" > "$TEMP_FILE"
  
  # Print info
  echo "Adding dependency with the following details:"
  echo "  Name: $NAME"
  echo "  URL: $URL"
  echo "  Requirement: $KIND"
  if [[ "$KIND" == "upToNextMajorVersion" || "$KIND" == "exactVersion" ]]; then
    echo "  Version: $VERSION"
  elif [[ "$KIND" == "branch" ]]; then
    echo "  Branch: $BRANCH"
  elif [[ "$KIND" == "revision" ]]; then
    echo "  Revision: $REVISION"
  fi
  echo "  Products: ${PRODUCTS_JSON//\"/}"
  
  # Run the Python script with the temporary file
  python scripts/add_dependency.py "$TEMP_FILE"
fi
