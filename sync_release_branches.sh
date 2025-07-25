#!/bin/bash
# Simple Release Branch Synchronization Script
# Synchronizes all release branches with main branch content

set -euo pipefail

echo "🔄 Starting release branch synchronization..."

# Ensure we're on main
git checkout main
MAIN_COMMIT=$(git rev-parse HEAD)
echo "📍 Main branch commit: $MAIN_COMMIT"

# Get all release branches
RELEASE_BRANCHES=$(git branch | grep "release/" | sed 's/^..//g' | sort -V)
TOTAL_BRANCHES=$(echo "$RELEASE_BRANCHES" | wc -l)

echo "📊 Found $TOTAL_BRANCHES release branches to synchronize"

PROCESSED=0
SUCCESSFUL=0
FAILED=0

# Process each branch
while IFS= read -r branch; do
    [[ -z "$branch" ]] && continue
    
    PROCESSED=$((PROCESSED + 1))
    echo "🔄 Processing branch $PROCESSED/$TOTAL_BRANCHES: $branch"
    
    # Extract version from branch name
    VERSION=$(echo "$branch" | sed 's/release\/v//')
    
    # Check out the branch
    if git checkout "$branch" 2>/dev/null; then
        echo "✅ Checked out $branch"
        
        # Reset to main content
        if git reset --hard "$MAIN_COMMIT" 2>/dev/null; then
            echo "🔄 Reset $branch to main content"
            
            # Restore the VERSION file with the branch-specific version
            echo "$VERSION" > VERSION
            
            # Commit the VERSION change if there are changes
            if git add VERSION && git commit -m "feat: sync $branch with main (preserve version $VERSION)" 2>/dev/null; then
                echo "💾 Committed VERSION update for $branch"
            fi
            
            # Push the updated branch
            if git push origin "$branch" --force-with-lease 2>/dev/null; then
                echo "🚀 Successfully pushed $branch"
                SUCCESSFUL=$((SUCCESSFUL + 1))
            else
                echo "❌ Failed to push $branch"
                FAILED=$((FAILED + 1))
            fi
        else
            echo "❌ Failed to reset $branch"
            FAILED=$((FAILED + 1))
        fi
    else
        echo "❌ Failed to checkout $branch"
        FAILED=$((FAILED + 1))
    fi
    
    # Small delay between operations
    sleep 0.5
    
done <<< "$RELEASE_BRANCHES"

# Return to main
git checkout main

echo ""
echo "📊 Branch synchronization summary:"
echo "   Total processed: $PROCESSED"
echo "   Successful: $SUCCESSFUL"
echo "   Failed: $FAILED"

if [[ $FAILED -eq 0 ]]; then
    echo "✅ All branches synchronized successfully!"
    exit 0
else
    echo "⚠️  Some branches failed to sync. Check the output above for details."
    exit 1
fi