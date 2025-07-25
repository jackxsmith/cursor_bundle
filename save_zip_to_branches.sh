#!/usr/bin/env bash
# Script to save the latest code zip to each branch

set -euo pipefail

VERSION=$(cat VERSION)
ZIP_FILE="cursor_bundle_v${VERSION}_complete_with_policy_enforcer.zip"
CURRENT_BRANCH=$(git branch --show-current)

echo "📦 Saving $ZIP_FILE to all branches..."
echo "🔍 Current branch: $CURRENT_BRANCH"

# Ensure zip file exists
if [[ ! -f "$ZIP_FILE" ]]; then
    echo "❌ Zip file not found: $ZIP_FILE"
    exit 1
fi

# Get list of branches to update (main and recent release branches)
BRANCHES_TO_UPDATE=(
    "main"
    "release/v6.9.208"
    "release/v6.9.207"
    "release/v6.9.206"
    "release/v6.9.205"
)

echo "📋 Branches to update: ${BRANCHES_TO_UPDATE[*]}"

# Save to each branch
for branch in "${BRANCHES_TO_UPDATE[@]}"; do
    echo
    echo "🔄 Processing branch: $branch"
    
    # Skip if current branch
    if [[ "$branch" == "$CURRENT_BRANCH" ]]; then
        echo "  ✅ Already on $branch - zip file already present"
        continue
    fi
    
    # Check if branch exists
    if ! git show-ref --verify --quiet "refs/heads/$branch" && ! git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
        echo "  ⚠️  Branch $branch does not exist - skipping"
        continue
    fi
    
    # Switch to branch
    echo "  🔀 Switching to branch $branch"
    if git show-ref --verify --quiet "refs/heads/$branch"; then
        git checkout "$branch"
    else
        git checkout -b "$branch" "origin/$branch"
    fi
    
    # Copy zip file if it doesn't exist or is different
    if [[ ! -f "$ZIP_FILE" ]]; then
        echo "  📁 Copying zip file to $branch"
        cp "../${ZIP_FILE}" .
        git add "$ZIP_FILE"
        git commit -m "chore: add latest code archive $ZIP_FILE" || echo "  ℹ️  No changes to commit"
        
        # Push to remote
        echo "  ⬆️  Pushing to remote"
        git push origin "$branch" || echo "  ⚠️  Push failed - continuing"
    else
        echo "  ✅ Zip file already exists in $branch"
    fi
done

# Return to original branch
echo
echo "🔙 Returning to original branch: $CURRENT_BRANCH"
git checkout "$CURRENT_BRANCH"

echo
echo "✅ Zip file distribution complete!"
echo "📦 Archive: $ZIP_FILE"
echo "🌿 Updated branches: ${BRANCHES_TO_UPDATE[*]}"