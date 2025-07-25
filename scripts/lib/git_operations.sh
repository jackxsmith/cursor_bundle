#!/usr/bin/env bash
# Git Operations Library with Race Condition Protection
# Provides atomic Git operations and proper locking mechanisms

set -euo pipefail
IFS=$'\n\t'

# Source error handling library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/error_handling.sh"

# Git operation configuration
declare -g GIT_LOCK_DIR="${GIT_LOCK_DIR:-${XDG_RUNTIME_DIR:-/tmp}/git-locks}"
declare -g GIT_LOCK_TIMEOUT="${GIT_LOCK_TIMEOUT:-300}"  # 5 minutes
declare -g GIT_OPERATION_TIMEOUT="${GIT_OPERATION_TIMEOUT:-60}"  # 1 minute
declare -g GIT_RETRY_ATTEMPTS="${GIT_RETRY_ATTEMPTS:-3}"
declare -g GIT_RETRY_DELAY="${GIT_RETRY_DELAY:-2}"

# Git lock management
declare -A GIT_LOCKS=()

# Initialize Git operations
init_git_operations() {
    local context="init_git_operations"
    
    # Create lock directory
    if [[ ! -d "$GIT_LOCK_DIR" ]]; then
        safe_execute "mkdir -p '$GIT_LOCK_DIR'" \
            "Failed to create Git lock directory" \
            "" \
            "$context"
    fi
    
    # Validate Git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        handle_critical_error "Not in a Git repository" "$context"
    fi
    
    # Set up cleanup on exit
    trap 'cleanup_git_locks' EXIT
    
    log_error "INFO" "Git operations initialized" "$context"
}

# Acquire exclusive lock for Git operations
acquire_git_lock() {
    local operation="${1:-general}"
    local timeout="${2:-$GIT_LOCK_TIMEOUT}"
    local context="${3:-${FUNCNAME[1]:-unknown}}"
    local lock_file="$GIT_LOCK_DIR/git-$operation.lock"
    local start_time=$(date +%s)
    local pid=$$
    
    log_error "DEBUG" "Attempting to acquire Git lock for operation: $operation" "$context"
    
    while true; do
        # Try to acquire lock atomically
        if (set -C; echo "$pid" > "$lock_file") 2>/dev/null; then
            GIT_LOCKS["$operation"]="$lock_file"
            log_error "DEBUG" "Git lock acquired for operation: $operation" "$context"
            return 0
        fi
        
        # Check if existing lock is stale
        if [[ -f "$lock_file" ]]; then
            local lock_pid
            lock_pid=$(cat "$lock_file" 2>/dev/null || echo "unknown")
            
            # Check if process still exists
            if [[ "$lock_pid" != "unknown" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
                log_error "WARNING" "Removing stale Git lock (PID: $lock_pid)" "$context"
                safe_ignore "rm -f '$lock_file'" \
                    "Failed to remove stale lock - will retry" \
                    "$context"
                continue
            fi
        fi
        
        # Check timeout
        local current_time=$(date +%s)
        if (( current_time - start_time >= timeout )); then
            handle_error 1 "Timeout waiting for Git lock: $operation" "$context"
            return 1
        fi
        
        log_error "DEBUG" "Git lock busy, waiting... (operation: $operation)" "$context"
        sleep 1
    done
}

# Release Git lock
release_git_lock() {
    local operation="${1:-general}"
    local context="${2:-${FUNCNAME[1]:-unknown}}"
    local lock_file="${GIT_LOCKS[$operation]:-}"
    
    if [[ -n "$lock_file" ]] && [[ -f "$lock_file" ]]; then
        safe_ignore "rm -f '$lock_file'" \
            "Failed to remove Git lock file" \
            "$context"
        unset GIT_LOCKS["$operation"]
        log_error "DEBUG" "Git lock released for operation: $operation" "$context"
    fi
}

# Cleanup all Git locks on exit
cleanup_git_locks() {
    local operation
    
    for operation in "${!GIT_LOCKS[@]}"; do
        release_git_lock "$operation" "cleanup_git_locks"
    done
    
    log_error "DEBUG" "All Git locks cleaned up" "cleanup_git_locks"
}

# Execute Git command with lock protection
safe_git_execute() {
    local operation="$1"
    local command="$2"
    local error_message="${3:-Git operation failed}"
    local context="${4:-${FUNCNAME[1]:-unknown}}"
    local timeout="${5:-$GIT_OPERATION_TIMEOUT}"
    
    log_error "DEBUG" "Executing Git operation: $operation" "$context"
    
    # Acquire lock for this operation
    if ! acquire_git_lock "$operation" "$GIT_LOCK_TIMEOUT" "$context"; then
        handle_error 1 "Failed to acquire Git lock for operation: $operation" "$context"
        return 1
    fi
    
    # Execute command with timeout
    local result=0
    if ! timeout "$timeout" bash -c "$command"; then
        result=$?
        if [[ $result -eq 124 ]]; then
            handle_error 124 "Git operation timed out: $operation" "$context"
        else
            handle_error $result "$error_message" "$context"
        fi
    fi
    
    # Always release lock
    release_git_lock "$operation" "$context"
    
    return $result
}

# Atomic Git operations with retry logic
atomic_git_push() {
    local ref="${1:-HEAD}"
    local remote="${2:-origin}"
    local context="${3:-${FUNCNAME[1]:-unknown}}"
    local force_flag="${4:-}"
    
    local push_command="git push"
    [[ -n "$force_flag" ]] && push_command="$push_command --force-with-lease"
    push_command="$push_command '$remote' '$ref'"
    
    log_error "INFO" "Starting atomic Git push: $remote/$ref" "$context"
    
    safe_execute_with_retry \
        "safe_git_execute 'push' '$push_command' 'Git push failed'" \
        "$GIT_RETRY_ATTEMPTS" \
        "$GIT_RETRY_DELAY" \
        "Failed to push $ref to $remote after retries" \
        "$context"
}

# Atomic Git pull with conflict resolution
atomic_git_pull() {
    local remote="${1:-origin}"
    local branch="${2:-$(git branch --show-current)}"
    local context="${3:-${FUNCNAME[1]:-unknown}}"
    local strategy="${4:-merge}"  # merge, rebase, or ff-only
    
    log_error "INFO" "Starting atomic Git pull: $remote/$branch" "$context"
    
    # Pre-pull validation
    validate_git_state "$context"
    
    local pull_command="git pull"
    case "$strategy" in
        "rebase")
            pull_command="$pull_command --rebase"
            ;;
        "ff-only")
            pull_command="$pull_command --ff-only"
            ;;
        "merge")
            pull_command="$pull_command --no-ff"
            ;;
        *)
            handle_error 1 "Invalid pull strategy: $strategy" "$context"
            return 1
            ;;
    esac
    
    pull_command="$pull_command '$remote' '$branch'"
    
    safe_execute_with_retry \
        "safe_git_execute 'pull' '$pull_command' 'Git pull failed'" \
        "$GIT_RETRY_ATTEMPTS" \
        "$GIT_RETRY_DELAY" \
        "Failed to pull from $remote/$branch after retries" \
        "$context"
}

# Atomic branch creation and switching
atomic_git_checkout() {
    local branch_name="$1"
    local create_flag="${2:-false}"
    local base_branch="${3:-}"
    local context="${4:-${FUNCNAME[1]:-unknown}}"
    
    log_error "INFO" "Starting atomic Git checkout: $branch_name" "$context"
    
    # Validate branch name
    if ! validate_branch_name "$branch_name"; then
        handle_error 1 "Invalid branch name: $branch_name" "$context"
        return 1
    fi
    
    local checkout_command="git checkout"
    
    if [[ "$create_flag" == "true" ]]; then
        checkout_command="$checkout_command -b"
        [[ -n "$base_branch" ]] && checkout_command="$checkout_command '$branch_name' '$base_branch'" || checkout_command="$checkout_command '$branch_name'"
    else
        checkout_command="$checkout_command '$branch_name'"
    fi
    
    safe_git_execute \
        "checkout" \
        "$checkout_command" \
        "Failed to checkout branch: $branch_name" \
        "$context"
}

# Atomic tag creation and push
atomic_git_tag() {
    local tag_name="$1"
    local commit="${2:-HEAD}"
    local message="${3:-}"
    local push_flag="${4:-true}"
    local context="${5:-${FUNCNAME[1]:-unknown}}"
    
    log_error "INFO" "Starting atomic Git tag creation: $tag_name" "$context"
    
    # Validate tag name
    if ! validate_tag_name "$tag_name"; then
        handle_error 1 "Invalid tag name: $tag_name" "$context"
        return 1
    fi
    
    # Create tag
    local tag_command="git tag"
    [[ -n "$message" ]] && tag_command="$tag_command -a -m '$message'" || tag_command="$tag_command"
    tag_command="$tag_command '$tag_name' '$commit'"
    
    safe_git_execute \
        "tag" \
        "$tag_command" \
        "Failed to create tag: $tag_name" \
        "$context"
    
    # Push tag if requested
    if [[ "$push_flag" == "true" ]]; then
        atomic_git_push "refs/tags/$tag_name" "origin" "$context"
    fi
}

# Atomic merge operation
atomic_git_merge() {
    local branch_name="$1"
    local strategy="${2:-recursive}"
    local no_ff="${3:-true}"
    local context="${4:-${FUNCNAME[1]:-unknown}}"
    
    log_error "INFO" "Starting atomic Git merge: $branch_name" "$context"
    
    # Pre-merge validation
    validate_git_state "$context"
    
    local merge_command="git merge"
    [[ "$no_ff" == "true" ]] && merge_command="$merge_command --no-ff"
    merge_command="$merge_command --strategy='$strategy' '$branch_name'"
    
    safe_git_execute \
        "merge" \
        "$merge_command" \
        "Failed to merge branch: $branch_name" \
        "$context"
}

# Git state validation
validate_git_state() {
    local context="${1:-${FUNCNAME[1]:-unknown}}"
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        handle_warning "Working directory has uncommitted changes" "$context"
    fi
    
    # Check for untracked files that might interfere
    local untracked_count
    untracked_count=$(git ls-files --others --exclude-standard | wc -l)
    if [[ $untracked_count -gt 0 ]]; then
        log_error "DEBUG" "Found $untracked_count untracked files" "$context"
    fi
    
    # Check Git configuration
    if ! git config user.name >/dev/null || ! git config user.email >/dev/null; then
        handle_error 1 "Git user configuration missing (name/email)" "$context"
        return 1
    fi
}

# Input validation functions
validate_branch_name() {
    local branch_name="$1"
    local pattern='^[a-zA-Z0-9/._-]+$'
    
    # Check basic pattern
    if [[ ! "$branch_name" =~ $pattern ]]; then
        return 1
    fi
    
    # Check Git naming rules (excluding valid forward slashes)
    if [[ "$branch_name" =~ (\.\.|^-|^/|/$|@\{|\[|\\|\*|\?|~|\^|:| ) ]]; then
        return 1
    fi
    
    return 0
}

validate_tag_name() {
    local tag_name="$1"
    local pattern='^[a-zA-Z0-9._-]+$'
    
    # Check basic pattern
    if [[ ! "$tag_name" =~ $pattern ]]; then
        return 1
    fi
    
    # Check for valid semantic version if it looks like one
    if [[ "$tag_name" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        if [[ ! "$tag_name" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9._-]+)?(\+[a-zA-Z0-9._-]+)?$ ]]; then
            return 1
        fi
    fi
    
    return 0
}

# Repository status and information
get_git_status() {
    local context="${1:-${FUNCNAME[1]:-unknown}}"
    local status_info=""
    
    status_info=$(cat <<EOF
{
  "branch": "$(git branch --show-current 2>/dev/null || echo 'detached')",
  "commit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
  "short_commit": "$(git rev-parse --short HEAD 2>/dev/null || echo 'unknown')",
  "dirty": $(git diff-index --quiet HEAD -- 2>/dev/null && echo 'false' || echo 'true'),
  "untracked": $(git ls-files --others --exclude-standard | wc -l),
  "ahead": $(git rev-list --count @{u}..HEAD 2>/dev/null || echo '0'),
  "behind": $(git rev-list --count HEAD..@{u} 2>/dev/null || echo '0'),
  "remote": "$(git config --get branch.$(git branch --show-current).remote 2>/dev/null || echo 'origin')"
}
EOF
    )
    
    echo "$status_info"
}

# Check for merge conflicts
check_merge_conflicts() {
    local context="${1:-${FUNCNAME[1]:-unknown}}"
    local conflict_files
    
    conflict_files=$(git ls-files --unmerged 2>/dev/null | cut -f2 | sort -u)
    
    if [[ -n "$conflict_files" ]]; then
        log_error "ERROR" "Merge conflicts detected in files:" "$context"
        while IFS= read -r file; do
            log_error "ERROR" "  - $file" "$context"
        done <<< "$conflict_files"
        return 1
    fi
    
    return 0
}

# Export all functions
export -f init_git_operations acquire_git_lock release_git_lock cleanup_git_locks
export -f safe_git_execute atomic_git_push atomic_git_pull atomic_git_checkout
export -f atomic_git_tag atomic_git_merge validate_git_state
export -f validate_branch_name validate_tag_name get_git_status check_merge_conflicts

# Auto-initialize if sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    init_git_operations
fi