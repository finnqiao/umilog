#!/bin/bash
# increment_build.sh - Auto-increment build number for CI/CD
# Usage: ./scripts/increment_build.sh [--commit]

set -e

PROJECT_YML="project.yml"

# Get current build number
CURRENT_BUILD=$(grep "CURRENT_PROJECT_VERSION:" "$PROJECT_YML" | head -1 | sed 's/.*: //')

# Increment
NEW_BUILD=$((CURRENT_BUILD + 1))

# Update project.yml
sed -i '' "s/CURRENT_PROJECT_VERSION: $CURRENT_BUILD/CURRENT_PROJECT_VERSION: $NEW_BUILD/" "$PROJECT_YML"

echo "Build number incremented: $CURRENT_BUILD → $NEW_BUILD"

# Optionally commit
if [ "$1" = "--commit" ]; then
    git add "$PROJECT_YML"
    git commit -m "chore: bump build number to $NEW_BUILD"
    echo "Committed build number change"
fi
