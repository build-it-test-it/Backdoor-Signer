#!/bin/bash
set -e

echo "=== Starting codebase reorganization ==="

# Perform reorganization
echo "Step 1: Reorganizing Extensions..."
./reorganize_extensions.sh

echo "Step 2: Reorganizing Operations..."
./reorganize_operations.sh

echo "Step 3: Reorganizing Views..."
./reorganize_views.sh

echo "Step 4: Reorganizing Magic..."
./reorganize_magic.sh

echo "Step 5: Reorganizing Management..."
./reorganize_management.sh

echo "=== All reorganization completed successfully! ==="
echo "The codebase has been reorganized for improved modularity and maintainability."
