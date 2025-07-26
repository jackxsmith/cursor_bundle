#\!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# bump_merged-v2.sh - Professional Release Management Framework v2.0
# Enterprise-grade release automation with robust error handling and self-correcting mechanisms
# ============================================================================

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="2.0.0"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Configuration Management
readonly REPO_OWNER="${REPO_OWNER:-jackxsmith}"
readonly REPO_NAME="${REPO_NAME:-cursor_bundle}"
readonly RELEASE_CONFIG_DIR="${HOME}/.config/cursor-release"
readonly RELEASE_CACHE_DIR="${HOME}/.cache/cursor-release"
readonly RELEASE_LOG_DIR="${RELEASE_CONFIG_DIR}/logs"

# Logging Configuration
readonly LOG_FILE="${RELEASE_LOG_DIR}/release_${TIMESTAMP}.log"
readonly ERROR_LOG="${RELEASE_LOG_DIR}/release_errors_${TIMESTAMP}.log"
readonly AUDIT_LOG="${RELEASE_LOG_DIR}/release_audit_${TIMESTAMP}.log"

# Lock Management
readonly LOCK_FILE="${RELEASE_CONFIG_DIR}/.release.lock"
readonly PID_FILE="${RELEASE_CONFIG_DIR}/.release.pid"

# Global Variables
declare -g RELEASE_CONFIG="${RELEASE_CONFIG_DIR}/release.conf"
declare -g VERBOSE_MODE=false
declare -g DRY_RUN_MODE=false
declare -g RELEASE_SUCCESS=true
declare -g NEW_VERSION=""

# Enhanced error handling with self-correction
error_handler() {
    local line_no="$1"
    local bash_command="$2"
    local exit_code="$3"
    
    log_error "Error on line $line_no: Command '$bash_command' failed with exit code $exit_code"
    
    # Self-correction attempts
    case "$bash_command" in
        *"git"*)
            log_info "Git command failed, checking repository status..."
            check_git_status
            ;;
        *"curl"* < /dev/null | *"wget"*)
            log_info "Network command failed, checking connectivity..."
            check_network_connectivity
            ;;
        *"mkdir"*)
            log_info "Directory creation failed, attempting to fix permissions..."
            fix_directory_permissions
            ;;
    esac
    
    cleanup_on_error
}

# Professional logging system
log_info() {
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [INFO] $message" | tee -a "$LOG_FILE"
    [[ "$VERBOSE_MODE" == "true" ]] && echo "[INFO] $message" >&2
}

log_error() {
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [ERROR] $message" | tee -a "$LOG_FILE" >&2
    echo "[$timestamp] [ERROR] $message" >> "$ERROR_LOG"
}

log_warning() {
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')  
    echo "[$timestamp] [WARNING] $message" | tee -a "$LOG_FILE"
    [[ "$VERBOSE_MODE" == "true" ]] && echo "[WARNING] $message" >&2
}

log_audit() {
    local action="$1"
    local target="$2"
    local result="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] AUDIT: $action - $target = $result" >> "$AUDIT_LOG"
}

# Initialize release framework
initialize_release_framework() {
    log_info "Initializing Professional Release Management Framework v${VERSION}"
    
    # Set up error handling
    trap 'error_handler ${LINENO} "$BASH_COMMAND" $?' ERR
    trap 'cleanup_on_exit' EXIT
    trap 'log_info "Received interrupt signal, cleaning up..."; cleanup_on_exit; exit 130' INT TERM
    
    # Create directory structure
    create_directory_structure
    
    # Load configuration
    load_configuration
    
    # Validate environment
    validate_environment
    
    # Acquire lock
    acquire_lock
    
    log_info "Release framework initialization completed successfully"
}

# Create directory structure with retry logic
create_directory_structure() {
    local dirs=("$RELEASE_CONFIG_DIR" "$RELEASE_CACHE_DIR" "$RELEASE_LOG_DIR")
    local max_retries=3
    
    for dir in "${dirs[@]}"; do
        local retry_count=0
        while [[ $retry_count -lt $max_retries ]]; do
            if mkdir -p "$dir" 2>/dev/null; then
                break
            else
                ((retry_count++))
                log_warning "Failed to create directory $dir (attempt $retry_count/$max_retries)"
                sleep 1
            fi
        done
        
        if [[ $retry_count -eq $max_retries ]]; then
            log_error "Failed to create directory $dir after $max_retries attempts"
            return 1
        fi
    done
}

# Load configuration with defaults
load_configuration() {
    if [[ \! -f "$RELEASE_CONFIG" ]]; then
        log_info "Creating default release configuration"
        create_default_configuration
    fi
    
    # Source configuration safely
    if [[ -r "$RELEASE_CONFIG" ]]; then
        source "$RELEASE_CONFIG"
        log_info "Configuration loaded from $RELEASE_CONFIG"
    else
        log_warning "Configuration file not readable, using defaults"
    fi
}

# Create default configuration
create_default_configuration() {
    cat > "$RELEASE_CONFIG" << 'CONFIGEOF'
# Professional Release Management Framework Configuration v2.0

# General Settings
VERBOSE_MODE=false
DRY_RUN_MODE=false
AUTO_TAG=true
AUTO_PUSH=true

# Repository Settings
DEFAULT_BRANCH=main
RELEASE_BRANCH_PREFIX=release/v
KEEP_RELEASE_BRANCHES=10

# Release Settings
CREATE_GITHUB_RELEASE=false
GENERATE_CHANGELOG=false
GENERATE_ARTIFACTS=true

# Git Settings
GIT_TIMEOUT=60
MAX_RETRY_ATTEMPTS=3
PUSH_TIMEOUT=120

# Notification Settings
ENABLE_NOTIFICATIONS=false
SLACK_WEBHOOK=""
EMAIL_RECIPIENTS=""

# Maintenance Settings
LOG_RETENTION_DAYS=30
CACHE_CLEANUP_DAYS=7
CONFIGEOF
    
    log_info "Default configuration created: $RELEASE_CONFIG"
}

# Validate environment
validate_environment() {
    log_info "Validating environment..."
    
    # Check required commands
    local required_commands=("git" "curl" "jq")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if \! command -v "$cmd" &>/dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        return 1
    fi
    
    # Check git repository
    if \! git rev-parse --git-dir &>/dev/null; then
        log_error "Not in a git repository"
        return 1
    fi
    
    # Check GitHub token
    if [[ -z "${GH_TOKEN:-}" ]] && [[ -f "$HOME/.github_pat" ]]; then
        GH_TOKEN="$(cat "$HOME/.github_pat" 2>/dev/null || echo "")"
    fi
    
    if [[ -z "${GH_TOKEN:-}" ]]; then
        log_warning "GitHub token not found, some operations may fail"
    fi
    
    log_info "Environment validation completed"
}

# Acquire lock with timeout
acquire_lock() {
    local timeout=30
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        if (set -C; echo $$ > "$LOCK_FILE") 2>/dev/null; then
            echo $$ > "$PID_FILE"
            log_info "Lock acquired successfully"
            return 0
        fi
        
        if [[ -f "$LOCK_FILE" ]]; then
            local lock_pid
            lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
            if [[ -n "$lock_pid" ]] && \! kill -0 "$lock_pid" 2>/dev/null; then
                log_info "Removing stale lock file"
                rm -f "$LOCK_FILE"
                continue
            fi
        fi
        
        sleep 1
        ((elapsed++))
    done
    
    log_error "Failed to acquire lock after ${timeout}s"
    return 1
}

# Validate version string
validate_version() {
    local version="$1"
    
    log_info "Validating version: $version"
    
    # Check semantic versioning format
    if [[ \! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9._-]+)?(\+[a-zA-Z0-9._-]+)?$ ]]; then
        log_error "Invalid version format: $version (expected: MAJOR.MINOR.PATCH)"
        return 1
    fi
    
    # Check if version already exists
    if git tag --list | grep -q "^v${version}$"; then
        log_error "Version $version already exists as a tag"
        return 1
    fi
    
    log_info "Version validation passed: $version"
    return 0
}

# Update version in files
update_version_files() {
    local version="$1"
    
    log_info "Updating version files to $version"
    log_audit "UPDATE_VERSION" "version_files" "STARTED"
    
    # Update VERSION file
    if echo "$version" > VERSION; then
        log_info "Updated VERSION file"
        git add VERSION || log_warning "Failed to stage VERSION file"
    else
        log_error "Failed to update VERSION file"
        return 1
    fi
    
    # Update package.json if it exists
    if [[ -f "package.json" ]]; then
        if jq --arg v "$version" '.version = $v' package.json > package.json.tmp && 
           mv package.json.tmp package.json; then
            log_info "Updated package.json"
            git add package.json || log_warning "Failed to stage package.json"
        else
            log_warning "Failed to update package.json"
        fi
    fi
    
    # Update other version files if they exist
    local version_files=("version.txt" "VERSION.txt" "version.py")
    for file in "${version_files[@]}"; do
        if [[ -f "$file" ]]; then
            if echo "$version" > "$file"; then
                log_info "Updated $file"
                git add "$file" || log_warning "Failed to stage $file"
            fi
        fi
    done
    
    log_audit "UPDATE_VERSION" "version_files" "COMPLETED"
    return 0
}

# Create release branch
create_release_branch() {
    local version="$1"
    local branch_name="${RELEASE_BRANCH_PREFIX:-release/v}${version}"
    
    log_info "Creating release branch: $branch_name"
    log_audit "CREATE_BRANCH" "$branch_name" "STARTED"
    
    # Ensure we're on the main branch
    local current_branch
    current_branch=$(git branch --show-current)
    
    if [[ "$current_branch" \!= "${DEFAULT_BRANCH:-main}" ]]; then
        log_info "Switching to ${DEFAULT_BRANCH:-main} branch"
        if \! git checkout "${DEFAULT_BRANCH:-main}"; then
            log_error "Failed to switch to ${DEFAULT_BRANCH:-main} branch"
            return 1
        fi
    fi
    
    # Pull latest changes
    if \! git pull origin "${DEFAULT_BRANCH:-main}"; then
        log_warning "Failed to pull latest changes, continuing anyway"
    fi
    
    # Create and switch to release branch
    if git checkout -b "$branch_name"; then
        log_info "Created and switched to release branch: $branch_name"
        log_audit "CREATE_BRANCH" "$branch_name" "COMPLETED"
        return 0
    else
        log_error "Failed to create release branch: $branch_name"
        log_audit "CREATE_BRANCH" "$branch_name" "FAILED"
        return 1
    fi
}

# Commit changes
commit_changes() {
    local version="$1"
    local commit_message="feat: bump to v${version}

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
    
    log_info "Committing changes for version $version"
    log_audit "COMMIT" "v$version" "STARTED"
    
    # Check if there are changes to commit
    if git diff --cached --quiet; then
        log_warning "No staged changes to commit"
        return 0
    fi
    
    # Create commit
    if git commit -m "$commit_message"; then
        log_info "Successfully committed changes"
        log_audit "COMMIT" "v$version" "COMPLETED"
        return 0
    else
        log_error "Failed to commit changes"
        log_audit "COMMIT" "v$version" "FAILED"
        return 1
    fi
}

# Create git tag
create_tag() {
    local version="$1"
    local tag_name="v${version}"
    local tag_message="Release version ${version}

Generated on $(date)
🤖 Generated with [Claude Code](https://claude.ai/code)"
    
    log_info "Creating git tag: $tag_name"
    log_audit "CREATE_TAG" "$tag_name" "STARTED"
    
    if git tag -a "$tag_name" -m "$tag_message"; then
        log_info "Successfully created tag: $tag_name"
        log_audit "CREATE_TAG" "$tag_name" "COMPLETED"
        return 0
    else
        log_error "Failed to create tag: $tag_name"
        log_audit "CREATE_TAG" "$tag_name" "FAILED"
        return 1
    fi
}

# Push changes to remote
push_changes() {
    local version="$1"
    local branch_name="${RELEASE_BRANCH_PREFIX:-release/v}${version}"
    local tag_name="v${version}"
    
    log_info "Pushing changes to remote"
    log_audit "PUSH" "$branch_name" "STARTED"
    
    if [[ "$DRY_RUN_MODE" == "true" ]]; then
        log_info "DRY RUN: Would push branch $branch_name and tag $tag_name"
        return 0
    fi
    
    # Push branch with retry logic
    local max_retries="${MAX_RETRY_ATTEMPTS:-3}"
    local retry_count=0
    
    while [[ $retry_count -lt $max_retries ]]; do
        if timeout "${PUSH_TIMEOUT:-120}" git push -u origin "$branch_name"; then
            log_info "Successfully pushed branch: $branch_name"
            break
        else
            ((retry_count++))
            if [[ $retry_count -lt $max_retries ]]; then
                log_warning "Push failed, retrying (attempt $retry_count/$max_retries)"
                sleep 5
            else
                log_error "Failed to push branch after $max_retries attempts"
                log_audit "PUSH" "$branch_name" "FAILED"
                return 1
            fi
        fi
    done
    
    # Push tag
    retry_count=0
    while [[ $retry_count -lt $max_retries ]]; do
        if timeout "${PUSH_TIMEOUT:-120}" git push origin "$tag_name"; then
            log_info "Successfully pushed tag: $tag_name"
            log_audit "PUSH" "$branch_name" "COMPLETED"
            return 0
        else
            ((retry_count++))
            if [[ $retry_count -lt $max_retries ]]; then
                log_warning "Tag push failed, retrying (attempt $retry_count/$max_retries)"
                sleep 5
            else
                log_error "Failed to push tag after $max_retries attempts"
                log_audit "PUSH" "$branch_name" "FAILED"
                return 1
            fi
        fi
    done
}

# Merge to main branch
merge_to_main() {
    local version="$1"
    local branch_name="${RELEASE_BRANCH_PREFIX:-release/v}${version}"
    
    log_info "Merging release branch to main"
    log_audit "MERGE" "$branch_name" "STARTED"
    
    # Switch to main branch
    if \! git checkout "${DEFAULT_BRANCH:-main}"; then
        log_error "Failed to switch to main branch"
        return 1
    fi
    
    # Pull latest changes
    if \! git pull origin "${DEFAULT_BRANCH:-main}"; then
        log_warning "Failed to pull latest main branch changes"
    fi
    
    # Merge release branch
    if git merge --no-ff "$branch_name" -m "chore: merge release branch v${version}"; then
        log_info "Successfully merged release branch"
        
        # Push merged changes
        if git push origin "${DEFAULT_BRANCH:-main}"; then
            log_info "Successfully pushed merged changes to main"
            log_audit "MERGE" "$branch_name" "COMPLETED"
            return 0
        else
            log_error "Failed to push merged changes"
            return 1
        fi
    else
        log_error "Failed to merge release branch"
        log_audit "MERGE" "$branch_name" "FAILED"
        return 1
    fi
}

# Cleanup release branch
cleanup_release_branch() {
    local version="$1"
    local branch_name="${RELEASE_BRANCH_PREFIX:-release/v}${version}"
    
    log_info "Cleaning up release branch: $branch_name"
    log_audit "CLEANUP" "$branch_name" "STARTED"
    
    # Delete local branch
    if git branch -d "$branch_name"; then
        log_info "Deleted local release branch: $branch_name"
    else
        log_warning "Failed to delete local release branch: $branch_name"
    fi
    
    # Delete remote branch
    if git push origin --delete "$branch_name"; then
        log_info "Deleted remote release branch: $branch_name"
        log_audit "CLEANUP" "$branch_name" "COMPLETED"
    else
        log_warning "Failed to delete remote release branch: $branch_name"
        log_audit "CLEANUP" "$branch_name" "PARTIAL"
    fi
}

# Generate release artifacts
generate_artifacts() {
    local version="$1"
    
    log_info "Generating release artifacts for version $version"
    log_audit "ARTIFACTS" "v$version" "STARTED"
    
    local artifacts_dir="${RELEASE_CACHE_DIR}/artifacts/v${version}"
    mkdir -p "$artifacts_dir"
    
    # Create version info file
    cat > "${artifacts_dir}/version_info.json" << EOF
{
    "version": "$version",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "git_commit": "$(git rev-parse HEAD)",
    "git_branch": "$(git branch --show-current)",
    "build_system": "Professional Release Management Framework v$VERSION"
}
