#!/bin/bash
# Branch Synchronization Script
# Synchronizes all release branches with main branch content

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/scripts/lib/comprehensive_logging.sh"
source "$SCRIPT_DIR/scripts/lib/error_handling.sh"
source "$SCRIPT_DIR/scripts/lib/git_operations.sh"

track_function_entry "sync_branches" "$*"

# Configuration
MAIN_BRANCH="main"
BATCH_SIZE=5
DRY_RUN="${DRY_RUN:-false}"

log_error "INFO" "Starting branch synchronization process" "sync_branches"

# Get current main commit
MAIN_COMMIT=$(git rev-parse HEAD)
log_error "INFO" "Main branch commit: $MAIN_COMMIT" "sync_branches"

# Get all release branches
RELEASE_BRANCHES=$(git branch | grep "release/" | sed 's/^..//g' | sort -V)
BRANCH_COUNT=$(echo "$RELEASE_BRANCHES" | wc -l)

log_error "INFO" "Found $BRANCH_COUNT release branches to synchronize" "sync_branches"

# Counter for tracking progress
PROCESSED=0
SUCCESSFUL=0
FAILED=0

# Process branches in batches
while IFS= read -r branch; do
    [[ -z "$branch" ]] && continue
    
    PROCESSED=$((PROCESSED + 1))
    log_error "INFO" "Processing branch $PROCESSED/$BRANCH_COUNT: $branch" "sync_branches"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_error "INFO" "DRY RUN: Would synchronize $branch with main" "sync_branches"
        SUCCESSFUL=$((SUCCESSFUL + 1))
        continue
    fi
    
    # Check if branch exists remotely
    if ! git ls-remote --heads origin "$branch" | grep -q "$branch"; then
        log_error "WARNING" "Branch $branch not found in remote, skipping" "sync_branches"
        continue
    fi
    
    # Synchronize branch
    if synchronize_branch "$branch"; then
        SUCCESSFUL=$((SUCCESSFUL + 1))
        log_error "INFO" "Successfully synchronized $branch" "sync_branches"
    else
        FAILED=$((FAILED + 1))
        log_error "ERROR" "Failed to synchronize $branch" "sync_branches"
    fi
    
    # Brief pause between operations
    sleep 1
    
done <<< "$RELEASE_BRANCHES"

# Summary
log_error "INFO" "Branch synchronization completed" "sync_branches"
log_error "INFO" "Total processed: $PROCESSED" "sync_branches"
log_error "INFO" "Successful: $SUCCESSFUL" "sync_branches"
log_error "INFO" "Failed: $FAILED" "sync_branches"

track_function_exit "sync_branches" 0

# Function to synchronize a single branch
synchronize_branch() {
    local branch="$1"
    local context="synchronize_branch"
    
    track_function_entry "$context" "$branch"
    
    # Extract version from branch name
    local version
    version=$(echo "$branch" | sed 's/release\/v//')
    
    # Check out the branch
    if ! atomic_git_checkout "$branch" false "" "$context"; then
        log_error "ERROR" "Failed to checkout branch $branch" "$context"
        track_function_exit "$context" 1
        return 1
    fi
    
    # Reset branch to main content but keep VERSION file
    if ! reset_branch_to_main "$branch" "$version" "$context"; then
        log_error "ERROR" "Failed to reset branch $branch to main" "$context"
        track_function_exit "$context" 1
        return 1
    fi
    
    # Push changes
    if ! atomic_git_push "HEAD" "origin" "$context" "--force-with-lease"; then
        log_error "ERROR" "Failed to push branch $branch" "$context"
        track_function_exit "$context" 1
        return 1
    fi
    
    track_function_exit "$context" 0
    return 0
}

# Function to reset branch to main content while preserving VERSION
reset_branch_to_main() {
    local branch="$1"
    local version="$2"
    local context="reset_branch_to_main"
    
    track_function_entry "$context" "$branch $version"
    
    # Save current VERSION file
    local temp_version_file="/tmp/version_${branch//\//_}"
    echo "$version" > "$temp_version_file"
    
    # Hard reset to main
    if ! git reset --hard "$MAIN_COMMIT"; then
        log_error "ERROR" "Failed to reset $branch to main commit" "$context"
        track_function_exit "$context" 1
        return 1
    fi
    
    # Restore VERSION file with branch-specific version
    if ! cp "$temp_version_file" "VERSION"; then
        log_error "ERROR" "Failed to restore VERSION file for $branch" "$context"
        track_function_exit "$context" 1
        return 1
    fi
    
    # Clean up temp file
    rm -f "$temp_version_file"
    
    # Commit the VERSION change
    if ! git add VERSION; then
        log_error "ERROR" "Failed to add VERSION file for $branch" "$context"
        track_function_exit "$context" 1
        return 1
    fi
    
    if ! git diff --cached --quiet; then
        if ! git commit -m "feat: sync branch $branch with main (preserve version $version)"; then
            log_error "ERROR" "Failed to commit VERSION change for $branch" "$context"
            track_function_exit "$context" 1
            return 1
        fi
    fi
    
    track_function_exit "$context" 0
    return 0
}

# Cleanup function
cleanup() {
    log_error "INFO" "Cleaning up branch synchronization" "cleanup"
    
    # Return to main branch
    if ! git checkout main 2>/dev/null; then
        log_error "WARNING" "Failed to return to main branch" "cleanup"
    fi
    
    # Clean up any temporary files
    rm -f /tmp/version_release_*
}

# Set up cleanup on exit
trap cleanup EXIT

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being executed directly
    echo "Branch Synchronization Script"
    echo "============================="
    echo "This will synchronize all release branches with main branch content"
    echo "while preserving each branch's VERSION file."
    echo ""
    
    if [[ "${1:-}" == "--dry-run" ]]; then
        export DRY_RUN=true
        echo "Running in DRY RUN mode - no changes will be made"
        echo ""
    fi
    
    if [[ "$DRY_RUN" != "true" ]]; then
        echo "WARNING: This will force-push to all release branches!"
        echo "Press Enter to continue or Ctrl+C to cancel..."
        read -r
    fi
    
    # Run the synchronization
    main "$@"
fi