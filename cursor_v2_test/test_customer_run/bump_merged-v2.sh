#!/usr/bin/env bash
#
# PROFESSIONAL RELEASE MANAGEMENT FRAMEWORK v2.0
# Enterprise-Grade Version Bumping and GitHub Integration
#
# Enhanced Features:
# - Robust error handling and self-correction
# - Automated version management
# - GitHub integration with retry logic
# - Professional logging and auditing
# - Branch protection handling
# - Artifact generation
#

set -euo pipefail
IFS=$'\n\t'

# === CONFIGURATION ===
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="$(basename "${0}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Version Configuration
readonly VERSION_FILE="${SCRIPT_DIR}/VERSION"
readonly CHANGELOG_FILE="${SCRIPT_DIR}/CHANGELOG.md"
readonly DEFAULT_BRANCH="master"

# Directory Structure
readonly LOG_DIR="${HOME}/.cache/cursor/release/logs"
readonly BACKUP_DIR="${HOME}/.cache/cursor/release/backup"
readonly ARTIFACTS_DIR="${HOME}/.cache/cursor/release/artifacts"

# Log Files
readonly MAIN_LOG="${LOG_DIR}/release_${TIMESTAMP}.log"
readonly ERROR_LOG="${LOG_DIR}/release_errors_${TIMESTAMP}.log"
readonly AUDIT_LOG="${LOG_DIR}/release_audit_${TIMESTAMP}.log"

# Configuration
declare -g DRY_RUN=false
declare -g QUIET_MODE=false
declare -g AUTO_COMMIT=true
declare -g AUTO_PUSH=true
declare -g CREATE_TAG=true
declare -g GENERATE_ARTIFACTS=true

# === UTILITY FUNCTIONS ===

# Enhanced logging
log() {
    local level="$1"
    local message="$2"
    local timestamp="$(date -Iseconds)"
    
    echo "[${timestamp}] ${level}: ${message}" >> "$MAIN_LOG"
    
    case "$level" in
        ERROR) 
            echo "[${timestamp}] ${level}: ${message}" >> "$ERROR_LOG"
            echo -e "\033[0;31m[ERROR]\033[0m ${message}" >&2
            ;;
        WARN) 
            echo -e "\033[1;33m[WARN]\033[0m ${message}"
            ;;
        PASS) 
            echo -e "\033[0;32m[✓]\033[0m ${message}"
            ;;
        INFO) 
            [[ "$QUIET_MODE" != "true" ]] && echo -e "\033[0;34m[INFO]\033[0m ${message}"
            ;;
        DEBUG) 
            [[ "${DEBUG:-false}" == "true" ]] && echo -e "\033[0;36m[DEBUG]\033[0m ${message}"
            ;;
    esac
}

# Audit logging
audit_log() {
    local action="$1"
    local status="$2"
    local details="${3:-}"
    local user="${USER:-unknown}"
    local timestamp="$(date -Iseconds)"
    
    echo "[${timestamp}] USER=${user} ACTION=${action} STATUS=${status} DETAILS=${details}" >> "$AUDIT_LOG"
}

# Ensure directory with error handling
ensure_directory() {
    local dir="$1"
    local max_attempts=3
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if [[ -d "$dir" ]]; then
            return 0
        elif mkdir -p "$dir" 2>/dev/null; then
            log "DEBUG" "Created directory: $dir"
            return 0
        fi
        
        ((attempt++))
        [[ $attempt -lt $max_attempts ]] && sleep 0.5
    done
    
    log "ERROR" "Failed to create directory: $dir"
    return 1
}

# Initialize directories
initialize_directories() {
    local dirs=("$LOG_DIR" "$BACKUP_DIR" "$ARTIFACTS_DIR")
    
    for dir in "${dirs[@]}"; do
        if ! ensure_directory "$dir"; then
            echo "Failed to initialize directories"
            return 1
        fi
    done
    
    # Log rotation
    find "$LOG_DIR" -name "release_*.log" -mtime +7 -delete 2>/dev/null || true
    find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +30 -delete 2>/dev/null || true
    
    return 0
}

# Retry mechanism
retry_operation() {
    local operation="$1"
    local max_attempts="${2:-3}"
    local delay="${3:-2}"
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if eval "$operation"; then
            return 0
        fi
        
        ((attempt++))
        if [[ $attempt -lt $max_attempts ]]; then
            log "WARN" "Operation failed, retrying (attempt $((attempt + 1))/$max_attempts)"
            sleep "$delay"
        fi
    done
    
    log "ERROR" "Operation failed after $max_attempts attempts: $operation"
    return 1
}

# === GIT OPERATIONS ===

# Check Git repository
check_git_repo() {
    log "INFO" "Checking Git repository status"
    
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log "ERROR" "Not in a Git repository"
        return 1
    fi
    
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    local remote_url=$(git remote get-url origin 2>/dev/null || echo "none")
    
    log "PASS" "Git repository validated"
    log "DEBUG" "Current branch: $current_branch"
    log "DEBUG" "Remote URL: $remote_url"
    
    return 0
}

# Update branches
update_branches() {
    log "INFO" "Updating branches from remote"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would fetch and update branches"
        return 0
    fi
    
    # Fetch latest changes
    if ! retry_operation "git fetch origin --tags" 3 5; then
        log "ERROR" "Failed to fetch from remote"
        return 1
    fi
    
    # Update current branch
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    if ! git pull origin "$current_branch" --rebase; then
        log "WARN" "Pull failed, attempting to resolve"
        if ! git rebase --abort 2>/dev/null; then
            log "ERROR" "Failed to update branch"
            return 1
        fi
    fi
    
    log "PASS" "Branches updated successfully"
    return 0
}

# === VERSION MANAGEMENT ===

# Get current version
get_current_version() {
    if [[ -f "$VERSION_FILE" ]]; then
        cat "$VERSION_FILE" | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+' | head -1
    else
        echo "v0.0.0"
    fi
}

# Bump version
bump_version() {
    local current_version=$(get_current_version)
    local bump_type="${1:-patch}"
    
    # Remove 'v' prefix if present
    current_version=${current_version#v}
    
    # Parse version components
    local major=$(echo "$current_version" | cut -d. -f1)
    local minor=$(echo "$current_version" | cut -d. -f2)
    local patch=$(echo "$current_version" | cut -d. -f3)
    
    # Bump appropriate component
    case "$bump_type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            log "ERROR" "Invalid bump type: $bump_type"
            return 1
            ;;
    esac
    
    local new_version="v${major}.${minor}.${patch}"
    log "INFO" "Version bumped from $current_version to $new_version"
    
    echo "$new_version"
}

# Update version file
update_version_file() {
    local new_version="$1"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would update VERSION file to $new_version"
        return 0
    fi
    
    # Backup current version file
    if [[ -f "$VERSION_FILE" ]]; then
        cp "$VERSION_FILE" "$BACKUP_DIR/VERSION_${TIMESTAMP}.bak"
    fi
    
    # Update version file
    echo "$new_version" > "$VERSION_FILE"
    echo "Updated: $(date -Iseconds)" >> "$VERSION_FILE"
    
    log "PASS" "Version file updated to $new_version"
    audit_log "VERSION_UPDATED" "SUCCESS" "Version: $new_version"
    
    return 0
}

# Update changelog
update_changelog() {
    local new_version="$1"
    local changes="${2:-Automated version bump}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would update CHANGELOG.md"
        return 0
    fi
    
    # Create changelog if it doesn't exist
    if [[ ! -f "$CHANGELOG_FILE" ]]; then
        cat > "$CHANGELOG_FILE" << 'EOF'
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

EOF
    fi
    
    # Backup changelog
    cp "$CHANGELOG_FILE" "$BACKUP_DIR/CHANGELOG_${TIMESTAMP}.bak"
    
    # Create temporary file with new entry
    local temp_file=$(mktemp)
    
    # Add new version entry
    {
        head -5 "$CHANGELOG_FILE"
        echo
        echo "## [$new_version] - $(date +%Y-%m-%d)"
        echo
        echo "### Changed"
        echo "- $changes"
        echo
        tail -n +6 "$CHANGELOG_FILE"
    } > "$temp_file"
    
    mv "$temp_file" "$CHANGELOG_FILE"
    
    log "PASS" "Changelog updated for version $new_version"
    return 0
}

# === GIT OPERATIONS ===

# Commit changes
commit_changes() {
    local version="$1"
    local message="${2:-Bump version to $version}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would commit changes with message: $message"
        return 0
    fi
    
    if [[ "$AUTO_COMMIT" != "true" ]]; then
        log "INFO" "Auto-commit disabled, skipping commit"
        return 0
    fi
    
    # Stage changes
    git add "$VERSION_FILE"
    [[ -f "$CHANGELOG_FILE" ]] && git add "$CHANGELOG_FILE"
    
    # Check if there are changes to commit
    if git diff --cached --quiet; then
        log "WARN" "No changes to commit"
        return 0
    fi
    
    # Commit changes
    if git commit -m "$message" -m "Automated release by $SCRIPT_NAME v$SCRIPT_VERSION"; then
        log "PASS" "Changes committed successfully"
        audit_log "COMMIT_CREATED" "SUCCESS" "Version: $version"
    else
        log "ERROR" "Failed to commit changes"
        return 1
    fi
    
    return 0
}

# Create tag
create_git_tag() {
    local version="$1"
    local message="${2:-Release $version}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would create tag $version"
        return 0
    fi
    
    if [[ "$CREATE_TAG" != "true" ]]; then
        log "INFO" "Tag creation disabled, skipping"
        return 0
    fi
    
    # Check if tag already exists
    if git tag -l | grep -q "^${version}$"; then
        log "WARN" "Tag $version already exists"
        return 0
    fi
    
    # Create annotated tag
    if git tag -a "$version" -m "$message"; then
        log "PASS" "Tag $version created successfully"
        audit_log "TAG_CREATED" "SUCCESS" "Tag: $version"
    else
        log "ERROR" "Failed to create tag"
        return 1
    fi
    
    return 0
}

# Push to remote
push_to_remote() {
    local version="$1"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would push changes and tags to remote"
        return 0
    fi
    
    if [[ "$AUTO_PUSH" != "true" ]]; then
        log "INFO" "Auto-push disabled, skipping push"
        return 0
    fi
    
    local current_branch=$(git rev-parse --abbrev-ref HEAD)
    
    # Push commits
    if ! retry_operation "git push origin $current_branch" 3 5; then
        log "ERROR" "Failed to push commits"
        return 1
    fi
    
    # Push tags
    if [[ "$CREATE_TAG" == "true" ]]; then
        if ! retry_operation "git push origin $version" 3 5; then
            log "ERROR" "Failed to push tag"
            return 1
        fi
    fi
    
    log "PASS" "Changes pushed to remote successfully"
    audit_log "PUSHED_TO_REMOTE" "SUCCESS" "Branch: $current_branch, Tag: $version"
    
    return 0
}

# === ARTIFACT GENERATION ===

# Generate release artifacts
generate_artifacts() {
    local version="$1"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would generate release artifacts"
        return 0
    fi
    
    if [[ "$GENERATE_ARTIFACTS" != "true" ]]; then
        log "INFO" "Artifact generation disabled, skipping"
        return 0
    fi
    
    local artifact_dir="$ARTIFACTS_DIR/release_${version}_${TIMESTAMP}"
    ensure_directory "$artifact_dir"
    
    # Generate release notes
    generate_release_notes "$version" > "$artifact_dir/RELEASE_NOTES.md"
    
    # Create source archive
    local archive_name="cursor-bundle-${version}.tar.gz"
    if tar -czf "$artifact_dir/$archive_name" \
        --exclude='.git' \
        --exclude='*.log' \
        --exclude='.cache' \
        -C "$SCRIPT_DIR" .; then
        log "PASS" "Source archive created: $archive_name"
    else
        log "ERROR" "Failed to create source archive"
    fi
    
    # Generate checksums
    if command -v sha256sum >/dev/null 2>&1; then
        (cd "$artifact_dir" && sha256sum * > SHA256SUMS)
        log "PASS" "Checksums generated"
    fi
    
    log "PASS" "Release artifacts generated in: $artifact_dir"
    audit_log "ARTIFACTS_GENERATED" "SUCCESS" "Version: $version"
    
    return 0
}

# Generate release notes
generate_release_notes() {
    local version="$1"
    local previous_tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    
    cat << EOF
# Release Notes - $version

Release Date: $(date -Iseconds)
Generated by: $SCRIPT_NAME v$SCRIPT_VERSION

## What's Changed

$(if [[ -n "$previous_tag" ]]; then
    git log --pretty=format:"- %s" "$previous_tag"..HEAD
else
    echo "- Initial release"
fi)

## Contributors

$(git log --pretty=format:"- %an" "$previous_tag"..HEAD 2>/dev/null | sort -u)

## Full Changelog

$(if [[ -n "$previous_tag" ]]; then
    echo "https://github.com/USER/REPO/compare/$previous_tag...$version"
else
    echo "This is the first release"
fi)
EOF
}

# === MAIN EXECUTION ===

# Show usage
show_usage() {
    cat << EOF
Professional Release Management Framework v$SCRIPT_VERSION

USAGE:
    $SCRIPT_NAME [OPTIONS] [BUMP_TYPE]

BUMP_TYPE:
    major           Bump major version (X.0.0)
    minor           Bump minor version (0.X.0)
    patch           Bump patch version (0.0.X) [default]

OPTIONS:
    -h, --help      Show this help message
    -n, --dry-run   Perform dry run without changes
    -q, --quiet     Quiet mode (minimal output)
    --no-commit     Skip auto-commit
    --no-push       Skip auto-push
    --no-tag        Skip tag creation
    --no-artifacts  Skip artifact generation

EXAMPLES:
    $SCRIPT_NAME                    # Bump patch version
    $SCRIPT_NAME minor              # Bump minor version
    $SCRIPT_NAME major --dry-run    # Test major version bump

EOF
}

# Parse arguments
parse_arguments() {
    local bump_type="patch"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -n|--dry-run)
                DRY_RUN=true
                ;;
            -q|--quiet)
                QUIET_MODE=true
                ;;
            --no-commit)
                AUTO_COMMIT=false
                ;;
            --no-push)
                AUTO_PUSH=false
                ;;
            --no-tag)
                CREATE_TAG=false
                ;;
            --no-artifacts)
                GENERATE_ARTIFACTS=false
                ;;
            major|minor|patch)
                bump_type="$1"
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
        shift
    done
    
    echo "$bump_type"
}

# Main function
main() {
    local bump_type=$(parse_arguments "$@")
    
    log "INFO" "Starting Professional Release Management v$SCRIPT_VERSION"
    log "INFO" "Bump type: $bump_type"
    audit_log "RELEASE_STARTED" "SUCCESS" "Type: $bump_type"
    
    # Initialize
    if ! initialize_directories; then
        log "ERROR" "Failed to initialize directories"
        exit 1
    fi
    
    # Validate Git repository
    if ! check_git_repo; then
        exit 1
    fi
    
    # Update from remote
    if ! update_branches; then
        log "WARN" "Failed to update branches, continuing anyway"
    fi
    
    # Get new version
    local current_version=$(get_current_version)
    local new_version=$(bump_version "$bump_type")
    
    if [[ -z "$new_version" ]]; then
        log "ERROR" "Failed to determine new version"
        exit 1
    fi
    
    log "INFO" "Bumping version from $current_version to $new_version"
    
    # Update files
    update_version_file "$new_version"
    update_changelog "$new_version"
    
    # Git operations
    commit_changes "$new_version"
    create_git_tag "$new_version"
    push_to_remote "$new_version"
    
    # Generate artifacts
    generate_artifacts "$new_version"
    
    # Summary
    log "PASS" "Release process completed successfully!"
    log "INFO" "New version: $new_version"
    log "INFO" "Logs available at: $LOG_DIR"
    
    audit_log "RELEASE_COMPLETED" "SUCCESS" "Version: $new_version"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi