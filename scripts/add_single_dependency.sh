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
  echo ""
  echo "Examples:"
  echo "  $0 --name SDWebImage --url https://github.com/SDWebImage/SDWebImage.git --kind upToNextMajorVersion --version 5.18.3 --products SDWebImage,SDWebImageMapKit"
  echo "  $0 --name SwiftUIX --url https://github.com/SwiftUIX/SwiftUIX.git --kind branch --branch main --products SwiftUIX"
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

# Create temporary JSON file
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

# Construct the JSON based on the requirement kind
if [[ "$KIND" == "upToNextMajorVersion" ]]; then
  cat > "$TEMP_FILE" << EOF
[
  {
    "name": "$NAME",
    "url": "$URL",
    "requirement": {
      "kind": "upToNextMajorVersion",
      "minimumVersion": "$VERSION"
    },
    "products": [$PRODUCTS_JSON]
  }
]
EOF
elif [[ "$KIND" == "exactVersion" ]]; then
  cat > "$TEMP_FILE" << EOF
[
  {
    "name": "$NAME",
    "url": "$URL",
    "requirement": {
      "kind": "exactVersion",
      "version": "$VERSION"
    },
    "products": [$PRODUCTS_JSON]
  }
]
EOF
elif [[ "$KIND" == "branch" ]]; then
  cat > "$TEMP_FILE" << EOF
[
  {
    "name": "$NAME",
    "url": "$URL",
    "requirement": {
      "kind": "branch",
      "branch": "$BRANCH"
    },
    "products": [$PRODUCTS_JSON]
  }
]
EOF
elif [[ "$KIND" == "revision" ]]; then
  cat > "$TEMP_FILE" << EOF
[
  {
    "name": "$NAME",
    "url": "$URL",
    "requirement": {
      "kind": "revision",
      "revision": "$REVISION"
    },
    "products": [$PRODUCTS_JSON]
  }
]
EOF
fi

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
