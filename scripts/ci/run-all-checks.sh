#!/bin/bash
set -e

echo "Running all code quality checks..."

# Create necessary directories
mkdir -p build/reports

# Run all checks
./scripts/ci/check-swiftlint.sh
./scripts/ci/check-swiftformat.sh
./scripts/ci/check-clang-format.sh
./scripts/ci/run-xcpretty.sh

echo "All checks complete"
