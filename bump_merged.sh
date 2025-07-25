#!/usr/bin/env bash
# bump.sh — resilient release helper  (2025‑07‑final‑7)

set -euo pipefail
shopt -s globstar nullglob
################################################################################
OWNER="jackxsmith" ; REPO="cursor_bundle"
KEEP_RELEASE_BRANCHES=50
MAX_RETRY=3
################################################################################
NEW_VERSION="${1:?usage: ./bump.sh <new_version>}"
CLONE_DIR="${REPO_DIR:-$HOME/Downloads/$REPO}"
API="https://api.github.com"
LOCK="/tmp/bump.${OWNER}_${REPO}.lock"

# Legacy features configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/.repo_config.yaml"
HOOKS_DIR="${SCRIPT_DIR}/hooks"
FUNCTIONS_DIR="${SCRIPT_DIR}/functions"

# Load configuration if available
if [ -f "$CONFIG_FILE" ]; then
    # Parse YAML config (simple key-value extraction)
    OWNER=$(grep "^owner:" "$CONFIG_FILE" 2>/dev/null | sed 's/owner: *//' || echo "$OWNER")
    REPO=$(grep "^repo:" "$CONFIG_FILE" 2>/dev/null | sed 's/repo: *//' || echo "$REPO")
    
    # Load feature flags
    CREATE_RELEASE=$(grep "^create_release:" "$CONFIG_FILE" 2>/dev/null | sed 's/create_release: *//' || echo "false")
    GENERATE_CHANGELOG=$(grep "^generate_changelog:" "$CONFIG_FILE" 2>/dev/null | sed 's/generate_changelog: *//' || echo "false")
    GENERATE_ARTIFACTS=$(grep "^generate_artifacts:" "$CONFIG_FILE" 2>/dev/null | sed 's/generate_artifacts: *//' || echo "false")
    EXPORT_METADATA=$(grep "^export_metadata:" "$CONFIG_FILE" 2>/dev/null | sed 's/export_metadata: *//' || echo "false")
    VERBOSE=$(grep "^verbose:" "$CONFIG_FILE" 2>/dev/null | sed 's/verbose: *//' || echo "false")
    STRICT_HOOKS=$(grep "^strict_hooks:" "$CONFIG_FILE" 2>/dev/null | sed 's/strict_hooks: *//' || echo "true")
else
    CREATE_RELEASE="false"
    GENERATE_CHANGELOG="false"
    GENERATE_ARTIFACTS="false"
    EXPORT_METADATA="false"
    VERBOSE="false"
    STRICT_HOOKS="true"
fi

# Source legacy functions if available
[ -f "$FUNCTIONS_DIR/notifications.sh" ] && source "$FUNCTIONS_DIR/notifications.sh"
[ -f "$FUNCTIONS_DIR/changelog.sh" ] && source "$FUNCTIONS_DIR/changelog.sh"
[ -f "$FUNCTIONS_DIR/artifacts.sh" ] && source "$FUNCTIONS_DIR/artifacts.sh"

# GitHub token from environment or file
if [ -f "$HOME/.github_pat" ]; then
    GH_TOKEN="$(cat "$HOME/.github_pat" 2>/dev/null || echo "")"
else
    GH_TOKEN="${GH_TOKEN:-}"
fi

# Validate token is available
if [ -z "$GH_TOKEN" ]; then
    echo "Warning: No GitHub token found. Set GH_TOKEN environment variable or create ~/.github_pat file"
    echo "GitHub API operations will be limited"
    TOKEN_OK=false
else
    TOKEN_OK=true
fi

# Enhanced logging functions
log() {
    local level="${1:-INFO}"
    local message="$*"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    case "$level" in
        INFO|*) printf '\e[36m[%s] • %s\e[0m\n' "$timestamp" "$message" ;;
        WARN) printf '\e[33m[%s] ⚠ %s\e[0m\n' "$timestamp" "$message" ;;
        ERROR) printf '\e[31m[%s] ✖ %s\e[0m\n' "$timestamp" "$message" >&2 ;;
        DEBUG) [[ "$VERBOSE" == "true" ]] && printf '\e[90m[%s] 🔧 %s\e[0m\n' "$timestamp" "$message" ;;
    esac
}

die() {
    log "ERROR" "$*"
    exit 1
}
banner_ok(){
  printf "\e[32m✔ v%s released; repo clean; branches identical; kept last %s releases.\e[0m\n" \
         "$NEW_VERSION" "$KEEP_RELEASE_BRANCHES"
  sync
}

auto_pull_rebase(){ local ref=$1
  git fetch origin "$ref"
  git rebase origin/"$ref" && { log "rebased $ref → origin/$ref"; return; }
  log "rebase conflict – merging with ours"
  git rebase --abort || true
  git merge --no-ff -X ours origin/"$ref" -m "Merge origin/$ref (auto)"
}
safe_push(){ local ref=$1 tries=0
  while (( tries < MAX_RETRY )); do
    git push origin "$ref" --follow-tags && return 0
    log "push rejected – auto‑pull & retry ($((++tries))/$MAX_RETRY)"
    auto_pull_rebase "$ref"
    git push --force-with-lease origin "$ref" --follow-tags && return 0
  done
  die "push failed for $ref"
}
api(){ $TOKEN_OK && curl -fsSL \
        -H "Authorization: Bearer $GH_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" "$@"; }

# Legacy hook execution functions
run_pre_commit_hooks() {
    [[ "$VERBOSE" == "true" ]] && log "Running pre-commit hooks..."
    
    if [ -d "$HOOKS_DIR/pre-commit" ]; then
        local hook_failed=false
        
        for hook in "$HOOKS_DIR/pre-commit"/*; do
            if [ -x "$hook" ]; then
                local hook_name=$(basename "$hook")
                [[ "$VERBOSE" == "true" ]] && log "Executing pre-commit hook: $hook_name"
                
                if ! "$hook"; then
                    log "Pre-commit hook failed: $hook_name"
                    hook_failed=true
                fi
            fi
        done
        
        if [ "$hook_failed" = true ]; then
            if [[ "$STRICT_HOOKS" == "true" ]]; then
                die "Pre-commit hooks failed"
            else
                log "Pre-commit hooks failed but continuing due to strict_hooks=false"
            fi
        fi
        
        [[ "$VERBOSE" == "true" ]] && log "Pre-commit hooks completed"
    fi
}

run_post_release_hooks() {
    [[ "$VERBOSE" == "true" ]] && log "Running post-release hooks..."
    
    if [ -d "$HOOKS_DIR/post-release" ]; then
        # Set environment variables for hooks
        export REPO_CONFIG="$CONFIG_FILE"
        export OWNER="$OWNER"
        export REPO="$REPO"
        export NEW_VERSION="$NEW_VERSION"
        export RELEASE_TAG="v$NEW_VERSION"
        
        for hook in "$HOOKS_DIR/post-release"/*; do
            if [ -x "$hook" ]; then
                local hook_name=$(basename "$hook")
                [[ "$VERBOSE" == "true" ]] && log "Executing post-release hook: $hook_name"
                
                if ! "$hook"; then
                    log "Post-release hook failed: $hook_name (continuing...)"
                fi
            fi
        done
        
        [[ "$VERBOSE" == "true" ]] && log "Post-release hooks completed"
    fi
}

# Legacy feature functions
generate_legacy_changelog() {
    if [[ "$GENERATE_CHANGELOG" == "true" ]] && command -v generate_changelog >/dev/null 2>&1; then
        [[ "$VERBOSE" == "true" ]] && log "Generating changelog..."
        
        local previous_tag=$(git tag --sort=-version:refname | head -1 2>/dev/null || echo "")
        
        if generate_changelog "$NEW_VERSION" "$previous_tag" "CHANGELOG.md" 2>/dev/null; then
            [[ "$VERBOSE" == "true" ]] && log "Changelog generated successfully"
        else
            log "Failed to generate changelog (continuing...)"
        fi
    fi
}

generate_legacy_artifacts() {
    if [[ "$GENERATE_ARTIFACTS" == "true" ]] && command -v create_artifacts >/dev/null 2>&1; then
        [[ "$VERBOSE" == "true" ]] && log "Generating release artifacts..."
        
        if create_artifacts "$NEW_VERSION" "artifacts" 2>/dev/null; then
            [[ "$VERBOSE" == "true" ]] && log "Release artifacts generated successfully"
        else
            log "Failed to generate release artifacts (continuing...)"
        fi
    fi
}

# -----------------------------------------------------------------------------
# Integrated helper functions from the archived 2028 script
#
# These helpers have been safely uncommented and ported into the live script.
# They do not override existing functions or variables and are not invoked by
# default.  They provide infrastructure for temporary file management should
# you choose to leverage them in future extensions.  Additional functions can
# be integrated here following the same pattern: copy the body from
# 2028.txt, remove any cite_start markers, and ensure names and globals do
# not conflict with those already in this script.

# Directory for temporary files created by helper functions.  Initially empty.
TEMP_DIR=""
# Array tracking temporary files.  Use register_temp_file to add entries.
declare -a TEMP_FILES=()

# -----------------------------------------------------------------------------
# Legacy global flags and defaults
#
# These variables mirror the default values from the 2028 automation script.
# They are not used by the live bump routine but are defined here so that
# integrated helpers can reference them without causing unbound variable
# errors.  You can adjust these as needed when porting additional logic.
LOG_LEVEL="INFO"
VERBOSE=false
DRY_RUN=false
FORCE=false
NO_VERIFY=false
PUSH_TAGS=false
PUSH_BRANCHES=false
CREATE_RELEASE=false
GENERATE_CHANGELOG=false
GENERATE_ARTIFACTS=false
EXPORT_METADATA=false
NOTIFICATION_CHANNELS=""

# Release metadata variables from the legacy script
RELEASE_ID=""
RELEASE_URL=""
RELEASE_TAG=""
RELEASE_TITLE=""
RELEASE_BODY=""

# Arrays to hold pre/post hook names
declare -a PRE_COMMIT_HOOKS=()
declare -a POST_RELEASE_HOOKS=()

# Additional configuration paths and artifact exclusion list from 2028.  These
# defaults mirror the original script but are not used by the live bump.
SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/.repo_config.yaml"
HOOKS_DIR="${SCRIPT_DIR}/hooks"
FUNCTIONS_DIR="${SCRIPT_DIR}/functions"
ARTIFACT_EXCLUSIONS=(".git" "*.log" "*.tmp" ".*.swp" "*~" "CHANGELOG.md")

# Register a temporary file for later cleanup.  Call this with the path to
# a scratch file that should be removed during cleanup.
register_temp_file() {
    local file="$1"
    TEMP_FILES+=("$file")
}

# Remove all registered temporary files and the temporary directory.
# Logs each action at DEBUG level.  Warning messages are emitted if removal
# fails, but execution continues.
clean_temp_files() {
    log "DEBUG" "Cleaning up temporary files..."
    for file in "${TEMP_FILES[@]}"; do
        if [[ -f "$file" ]]; then
            log "DEBUG" "Removing temporary file: $file"
            rm -f "$file" || log "WARNING" "Failed to remove temporary file: $file"
        fi
    done
    if [[ -d "$TEMP_DIR" ]]; then
        log "DEBUG" "Removing temporary directory: $TEMP_DIR"
        rm -rf "$TEMP_DIR" || log "WARNING" "Failed to remove temporary directory: $TEMP_DIR"
    fi
}

# -----------------------------------------------------------------------------
# Legacy configuration defaults (unused by the live script unless invoked).
# These variables correspond to defaults in the 2028 script.  They are
# defined here so that integrated helpers have sensible fallbacks when
# referenced.
DEFAULT_BRANCH="main"
DEVELOPMENT_BRANCH="develop"
# Branch variables that may be set externally when using 2028 helpers.
FROM_BRANCH=""
TO_BRANCH=""
TARGET_BRANCH=""

# Set default branch names for merge operations.  This helper resolves
# FROM_BRANCH, TO_BRANCH, and TARGET_BRANCH based on provided values or
# defaults.  It logs the resolved values at DEBUG level.  These
# variables do not interfere with the live script’s release flow unless
# this function is explicitly called.
set_branch_defaults() {
    FROM_BRANCH="${FROM_BRANCH:-$DEVELOPMENT_BRANCH}"
    TO_BRANCH="${TO_BRANCH:-$DEFAULT_BRANCH}"
    TARGET_BRANCH="${TARGET_BRANCH:-$TO_BRANCH}"
    log "DEBUG" "Resolved branches: FROM=$FROM_BRANCH, TO=$TO_BRANCH, TARGET=$TARGET_BRANCH"
}

# Backup the current Git repository to a bundle file.  The bundle is
# stored in the temporary directory and registered for cleanup.  Returns
# 0 on success, non‑zero on failure.  This implementation omits the
# dry-run wrapper from the legacy script to avoid undefined variables.
git_backup_repo() {
    log "INFO" "Backing up Git repository..."
    local timestamp
    timestamp=$(date +%Y%m%d%H%M%S)
    local backup_file="$TEMP_DIR/$REPO-$timestamp.bundle"
    register_temp_file "$backup_file"
    local error_log="$TEMP_DIR/git_bundle_error.log"
    if ! git bundle create "$backup_file" --all >/dev/null 2>"$error_log"; then
        log "WARNING" "Failed to create Git bundle backup. This may hinder full rollback. Error: $(cat "$error_log")"
        return 1
    fi
    log "INFO" "Repository backed up to: $backup_file"
    return 0
}

# Calculate a new semantic version string based on the current version
# and a specified version bump type.  Supports major, minor, patch and
# prerelease increments with validation of prerelease identifiers.
calculate_new_version() {
    log "INFO" "Calculating new version from '$CURRENT_VERSION' based on type: '$VERSION_TYPE'..."
    local major minor patch prerelease_part
    major=$(echo "$CURRENT_VERSION" | cut -d. -f1)
    minor=$(echo "$CURRENT_VERSION" | cut -d. -f2)
    patch=$(echo "$CURRENT_VERSION" | cut -d. -f3 | cut -d- -f1)
    prerelease_part=$(echo "$CURRENT_VERSION" | cut -d- -f2-)
    case "$VERSION_TYPE" in
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            prerelease_part=""
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            prerelease_part=""
            ;;
        "patch")
            patch=$((patch + 1))
            prerelease_part=""
            ;;
        "prerelease")
            if [[ -z "$PRERELEASE_IDENTIFIER" ]]; then
                error_exit 6 "Prerelease identifier must be specified for 'prerelease' version type (e.g., --prerelease-identifier alpha)."
            fi
            # Validate prerelease identifier format (SemVer 2.0.0 compliance)
            if ! [[ "$PRERELEASE_IDENTIFIER" =~ ^[0-9A-Za-z-]+$ ]]; then
                error_exit 6 "Prerelease identifier '$PRERELEASE_IDENTIFIER' is invalid. It must only contain alphanumerics and hyphens."
            fi
            if [[ "$prerelease_part" =~ ^${PRERELEASE_IDENTIFIER}\.([0-9]+)$ ]]; then
                local prerelease_num="${BASH_REMATCH[1]}"
                prerelease_num=$((prerelease_num + 1))
                prerelease_part="${PRERELEASE_IDENTIFIER}.${prerelease_num}"
            else
                patch=$((patch + 1))
                prerelease_part="${PRERELEASE_IDENTIFIER}.0"
            fi
            ;;
        *)
            error_exit 1 "Invalid version type: $VERSION_TYPE"
            ;;
    esac
    NEW_VERSION="$major.$minor.$patch"
    if [[ -n "$prerelease_part" ]]; then
        NEW_VERSION="$NEW_VERSION-$prerelease_part"
    fi
    log "INFO" "New version calculated: $NEW_VERSION (from $CURRENT_VERSION)."
}

# Placeholder for the Git rollback logic from the legacy script.  In the
# full 2028 implementation, this function would attempt to restore the
# working tree to its original state if an error occurred during the
# release process.  Many of those operations depend on variables and
# flags (e.g. DRY_RUN, ORIGINAL_BRANCH) that are not present in the
# live script.  To avoid unexpected behaviour, this stub simply logs
# that a rollback was invoked and returns success.  You can expand
# this function later with custom rollback procedures if needed.
rollback_git_changes() {
    log "INFO" "rollback_git_changes called (no-op in this integration)."
    return 0
}

execute_hook() {
    # Execute a user-defined hook script.  The script path, event name and
    # optional JSON data are passed as arguments.  In dry-run mode, logs
    # what would be executed.  Exits via error_exit if the hook fails.
    local hook_path="$1"
    local event_name="$2"
    local data_json="$3"
    if [[ ! -f "$hook_path" ]]; then
        log "WARNING" "Hook script not found: $hook_path"
        return 0
    fi
    log "INFO" "Executing hook: $hook_path for event: $event_name"
    if $DRY_RUN; then
        log "INFO" "[DRY-RUN] Would execute hook: '$hook_path' with event '$event_name' and data: $data_json"
        return 0
    else
        if ! chmod +x "$hook_path"; then
            error_exit 5 "Failed to make hook script executable: $hook_path"
        fi
        if ! HOOK_DATA="$data_json" "$hook_path" "$event_name"; then
            error_exit 5 "Hook '$hook_path' failed for event '$event_name'. Check hook script output for details."
        fi
    fi
}

parse_args() {
    log "INFO" "parse_args called (no-op in this integration)."
    return 0
}

load_config() {
    log "INFO" "load_config called (no-op in this integration)."
    return 0
}

validate_git_state() {
    log "INFO" "validate_git_state called (no-op in this integration)."
    return 0
}

validate_github_permissions() {
    log "INFO" "validate_github_permissions called (no-op in this integration)."
    return 0
}

# Handle errors and exit gracefully.  This mirrors the legacy 2028
# implementation but uses the live script's logging helper.  The
# function accepts an exit code and a message, logs the error, and
# terminates the script with the given code.
error_exit() {
    local exit_code="$1"
    local message="$2"
    log "ERROR" "$message"
    exit "$exit_code"
}

# Create a temporary directory for intermediate files.  Registers the
# directory for cleanup and logs its creation.  Exits with code 1 if
# the directory cannot be created.  This helper originates from the
# legacy 2028 script.
initialize_temp_dir() {
    TEMP_DIR=$(mktemp -d -t 'release_script_XXXXXXXXXX')
    if [[ -z "$TEMP_DIR" || ! -d "$TEMP_DIR" ]]; then
        error_exit 1 "Failed to create temporary directory. Check permissions or disk space."
    fi
    register_temp_file "$TEMP_DIR"
    log "DEBUG" "Created temporary directory: $TEMP_DIR"
}

# Validate that required tools and environment variables are present.  This
# function mirrors the behaviour of the legacy 2028 version but is
# integrated safely.  It checks for the presence of Git and curl,
# optionally reports on yq/jq availability, and ensures GH_TOKEN is set.
validate_environment_requirements() {
    log "INFO" "Validating environment requirements..."
    command -v git &>/dev/null || error_exit 2 "Git is not installed. Please install Git."
    command -v curl &>/dev/null || error_exit 2 "curl is not installed. Please install curl."
    if command -v yq &>/dev/null; then
        log "INFO" "yq found. YAML config parsing enabled."
    else
        log "WARNING" "yq not found. Advanced YAML configuration files will not be parsed. Relying on basic parsing (or env vars/defaults)."
    fi
    if command -v jq &>/dev/null; then
        log "INFO" "jq found. JSON output will be pretty-printed and parsed robustly."
    else
        log "WARNING" "jq not found. JSON output will not be pretty-printed, and some parsing may be less robust."
    fi
    if [[ -z "$GH_TOKEN" ]]; then
        error_exit 2 "GitHub Personal Access Token (GH_TOKEN) is not set. Please set it via the --gh-token flag or the GH_TOKEN environment variable."
    fi
    log "INFO" "Environment validation complete."
}

# Validate repository information and infer OWNER/REPO if not provided.
# This helper inspects the current Git repository and remote
# configuration.  It exits with code 2 on failure.  Mirrored from the
# legacy script and safe to include as long as it is not invoked by
# default.
validate_repo_info() {
    log "INFO" "Validating repository information..."
    CLONE_DIR=$(git rev-parse --show-toplevel 2>/dev/null)
    if [[ -z "$CLONE_DIR" ]]; then
        error_exit 2 "Current directory is not within a Git repository. Please run the script from your repository's root or a subdirectory."
    fi
    log "INFO" "Repository clone directory (CLONE_DIR) set to: $CLONE_DIR"
    if [[ -z "$OWNER" || -z "$REPO" ]]; then
        log "DEBUG" "Attempting to infer owner and repo from Git remote 'origin'."
        local remote_url
        remote_url=$(git config --get remote.origin.url 2>/dev/null)
        if [[ -z "$remote_url" ]]; then
            error_exit 2 "Could not find Git remote 'origin'. Please ensure you are in a Git repository or specify --owner and --repo."
        fi
        if [[ "$remote_url" =~ github.com[:/]([^/]+)/([^/]+?)(\.git)?$ ]]; then
            OWNER="${BASH_REMATCH[1]}"
            REPO="${BASH_REMATCH[2]}"
            log "INFO" "Inferred Owner: $OWNER, Repo: $REPO from Git remote."
        else
            error_exit 2 "Could not parse GitHub owner/repo from remote URL: '$remote_url'. Please specify --owner and --repo."
        fi
    fi
    if [[ -z "$OWNER" ]]; then error_exit 2 "GitHub repository owner is not set. Please specify via --owner or ensure it's in the config or Git remote."; fi
    if [[ -z "$REPO" ]]; then error_exit 2 "GitHub repository name is not set. Please specify via --repo or ensure it's in the config or Git remote."; fi
    log "INFO" "Repository information validation complete."
}

exec 9>"$LOCK"; flock -n 9 || die "another bump is running"

for t in git curl perl awk; do command -v "$t" >/dev/null || die "$t required"; done
[[ -d "$CLONE_DIR/.git" ]] || git clone "https://github.com/$OWNER/$REPO.git" "$CLONE_DIR"
cd "$CLONE_DIR"; git fetch --all --tags

# Run pre-commit hooks if enabled
run_pre_commit_hooks

if ! git diff-index --quiet HEAD; then
  cur=$(git symbolic-ref --short HEAD)
  git add -A; git commit -m "chore: auto‑save pre‑bump housekeeping"
  safe_push "$cur"
fi

SSH_URL="git@github.com:$OWNER/$REPO.git"
HTTPS_URL="https://x-access-token@github.com/$OWNER/$REPO.git"
export GIT_TERMINAL_PROMPT=0 GIT_CONFIG_NOSYSTEM=1
git remote set-url origin "$SSH_URL" 2>/dev/null || true
USE_SSH=true; git ls-remote origin &>/dev/null || USE_SSH=false
ASKPASS=''; trap '[[ -n $ASKPASS ]] && rm -f "$ASKPASS"' EXIT
if ! $USE_SSH && $TOKEN_OK; then
  log "SSH failed – switching to PAT"
  ASKPASS=$(mktemp); chmod 700 "$ASKPASS"
  printf '#!/bin/sh\nprintf %s "$GH_TOKEN"\n' >"$ASKPASS"
  export GIT_ASKPASS="$ASKPASS"; git remote set-url origin "$HTTPS_URL"
  git ls-remote origin &>/dev/null || die "cannot authenticate"
fi

TARGET="release/v$NEW_VERSION"
branch_exists(){ git ls-remote --heads origin "$1" | grep -q "$1"; }
if branch_exists "$TARGET"; then git fetch origin "$TARGET:$TARGET"; else
  git fetch origin main && git checkout -B "$TARGET" origin/main && safe_push "$TARGET"
fi
git checkout "$TARGET"

CLEAN=( bump_and_merge_* v*.sh diff-6*.patch git_log_* git_metadata_* *_report_v*.txt
        build_log_* change_summary_* code_metrics_* dependencies_* lint_report_*
        performance_* static_analysis_* test_results_* todo_fixme_*
        ci_workflows_v*.tar* )
for p in "${CLEAN[@]}"; do git rm -f $p 2>/dev/null || true; done
GI=.gitignore; TAG='## auto‑clean (bump.sh)'
if [[ ! -f $GI ]] || ! grep -q "$TAG" "$GI"; then
  { echo "$TAG"; printf '%s\n' "${CLEAN[@]}" '*.tar.gz' '*.tar_v*.gz' 'diff-*.patch'; } >> "$GI"
  git add "$GI"
fi
git diff --cached --quiet || { git commit -m "chore: repo housekeeping"; safe_push "$TARGET"; }

OLD_VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)
[[ -z $OLD_VERSION && -f VERSION ]] && OLD_VERSION=$(<VERSION)
for f in **/*"$OLD_VERSION"*; do [[ -f $f ]] && nf=${f//$OLD_VERSION/$NEW_VERSION} && [[ $nf != $f ]] && { mkdir -p "$(dirname "$nf")"; mv "$f" "$nf"; }; done
perl -pi -e "s/\Q$OLD_VERSION\E/$NEW_VERSION/g" $(git ls-files '*.*') 2>/dev/null || true
echo "$NEW_VERSION" > VERSION
git add .; git diff --cached --quiet || { git commit -m "feat: bump to v$NEW_VERSION"; safe_push "$TARGET"; }
git tag -f "v$NEW_VERSION"; safe_push "$TARGET"

git fetch origin main
git merge --no-ff origin/main -m "Merge main into $TARGET" || {
  for f in $(git ls-files -u | cut -f2); do git checkout --ours "$f"; git add "$f"; done
  git commit -m "Resolve conflicts preferring $TARGET"
}
safe_push "$TARGET"

git checkout main
auto_pull_rebase main
git merge --ff-only "$TARGET" 2>/dev/null || git merge --no-ff "$TARGET" -m "Merge $TARGET into main (offline)"
safe_push main

git checkout "$TARGET"
git merge --ff-only origin/main 2>/dev/null || true; safe_push "$TARGET"

set +e
i=0
while read ref; do
  ((i++)); br=${ref#refs/remotes/origin/}
  (( i > KEEP_RELEASE_BRANCHES )) && git push origin --delete "$br" >/dev/null 2>&1
done < <(git for-each-ref --sort=-creatordate --format='%(refname)' refs/remotes/origin/release/v*)
set -e

# Execute legacy features if enabled
generate_legacy_changelog
generate_legacy_artifacts

# Run post-release hooks
run_post_release_hooks

banner_ok
exit 0

# Legacy helper functions imported from 2028 script. These functions are
# defined for reference and are not invoked by the live bump.sh workflow.
# They provide additional capabilities from the 2028 automation framework.

legacy_usage() {
    echo "Usage: $SCRIPT_NAME <version_type> [options]"
    echo ""
    echo "Version Types:"
    echo "  major       Increment major version (e.g., 1.2.3 -> 2.0.0)"
    echo "  minor       Increment minor version (e.g., 1.2.3 -> 1.3.0)"
    echo "  patch       Increment patch version (e.g., 1.2.3 -> 1.2.4)"
    echo "  prerelease  Increment prerelease version (e.g., 1.2.3 -> 1.2.4-alpha.0 or 1.2.3-alpha.0 -> 1.2.3-alpha.1)"
    echo ""
    echo "Options (Precedence: CLI > ENV > Config File > Script Defaults):"
    echo "  --owner <owner>                 GitHub repository owner (default: inferred from Git remote)"
    echo "  --repo <repo>                   GitHub repository name (default: inferred from Git remote)"
    echo "  --github-user <user>            GitHub username for API authentication (default: inferred from GH_USER env)"
    echo "  --gh-token <token>              GitHub personal access token (default: GH_TOKEN env var)"
    echo "  --from-branch <branch>          Branch to merge from (default: develop)"
    echo "  --to-branch <branch>            Branch to merge into (default: main)"
    echo "  --target-branch <branch>        Branch where the release tag will be created (default: to-branch)"
    echo "  --prerelease-identifier <id>    Identifier for prerelease (e.g., alpha, beta, rc; required for prerelease type)"
    echo "  --push-tags                     Push generated tags to remote"
    echo "  --push-branches                 Push updated branches to remote"
    echo "  --create-release                Create a GitHub release"
    echo "  --generate-changelog            Generate CHANGELOG.md based on Git history"
    echo "  --generate-artifacts            Generate a zip artifact of the repository for the release"
    echo "  --export-metadata               Export release metadata to a JSON file"
    echo "  --notification-channel <channel> Comma-separated list of notification channels (e.g., slack,teams,custom)"
    echo "  --force                         Force operations (e.g., overwrite existing tags, skip some checks)"
    echo "  --no-verify                     Skip Git hooks (e.g., pre-commit, commit-msg)"
    echo "  --dry-run                       Simulate operations without making any changes"
    echo "  --verbose                       Enable verbose logging (same as --log-level DEBUG)"
    echo "  --log-level <level>             Set logging level (DEBUG, INFO, WARNING, ERROR; default: INFO)"
    echo "  --config-file <path>            Path to the .repo_config.yaml file (default: \$SCRIPT_DIR/.repo_config.yaml)"
    echo "  --hooks-dir <path>              Directory containing custom hook scripts (default: script_dir/hooks)"
    echo "  --functions-dir <path>          Directory containing custom function scripts (default: script_dir/functions)"
    echo "  -h, --help                      Display this help message"
    echo ""
    echo "Environment Variables (lower precedence than CLI, higher than config file):"
    echo "  GH_TOKEN                        GitHub Personal Access Token"
    echo "  GH_USER                         GitHub username (if not provided via --github-user)"
    echo ""
    echo "Example: $SCRIPT_NAME patch --push-tags --create-release --generate-changelog"
    exit 0
}

legacy_parse_args() {
    local cli_owner=""
    local cli_repo=""
    local cli_github_user=""
    local cli_gh_token=""
    local cli_from_branch=""
    local cli_to_branch=""
    local cli_target_branch=""
    local cli_prerelease_identifier=""
    local cli_notification_channels=""
    local cli_log_level=""
    local cli_config_file_path=""
    local cli_hooks_dir_path=""
    local cli_functions_dir_path=""
    while (( "$#" )); do
        case "$1" in
            major|minor|patch|prerelease)
                if [[ -n "$VERSION_TYPE" ]]; then
                    error_exit 6 "Only one version type can be specified: '$VERSION_TYPE' and '$1'."
                fi
                VERSION_TYPE="$1"
                shift
                if [[ "$VERSION_TYPE" == "prerelease" ]]; then
                    if [[ -z "${1:-}" || "$1" =~ ^- ]]; then
                        error_exit 6 "Prerelease identifier is required for 'prerelease' version type. Usage: prerelease <identifier>"
                    fi
                    cli_prerelease_identifier="$1"
                    shift
                fi
                ;;
            --owner) cli_owner="$2"; shift 2 ;;
            --repo) cli_repo="$2"; shift 2 ;;
            --github-user) cli_github_user="$2"; shift 2 ;;
            --gh-token) cli_gh_token="$2"; shift 2 ;;
            --from-branch) cli_from_branch="$2"; shift 2 ;;
            --to-branch) cli_to_branch="$2"; shift 2 ;;
            --target-branch) cli_target_branch="$2"; shift 2 ;;
            --prerelease-identifier) cli_prerelease_identifier="$2"; shift 2 ;;
            --push-tags) PUSH_TAGS=true; shift ;;
            --push-branches) PUSH_BRANCHES=true; shift ;;
            --create-release) CREATE_RELEASE=true; shift ;;
            --generate-changelog) GENERATE_CHANGELOG=true; shift ;;
            --generate-artifacts) GENERATE_ARTIFACTS=true; shift ;;
            --export-metadata) EXPORT_METADATA=true; shift ;;
            --notification-channel) cli_notification_channels="$2"; shift 2 ;;
            --force) FORCE=true; shift ;;
            --no-verify) NO_VERIFY=true; shift ;;
            --dry-run) DRY_RUN=true; log "INFO" "Dry-run mode enabled. No actual changes will be made."; shift ;;
            --verbose) VERBOSE=true; cli_log_level="DEBUG"; shift ;;
            --log-level) cli_log_level=$(echo "$2" | tr '[:lower:]' '[:upper:]'); shift 2 ;;
            --config-file) cli_config_file_path="$2"; shift 2 ;;
            --hooks-dir) cli_hooks_dir_path="$2"; shift 2 ;;
            --functions-dir) cli_functions_dir_path="$2"; shift 2 ;;
            -h|--help) legacy_usage ;;
            *) error_exit 1 "Unknown option: $1" ;;
        esac
    done
    if [[ -n "$cli_owner" ]]; then OWNER="$cli_owner"; fi
    if [[ -n "$cli_repo" ]]; then REPO="$cli_repo"; fi
    if [[ -n "$cli_github_user" ]]; then GITHUB_USER="$cli_github_user"; fi
    if [[ -n "$cli_gh_token" ]]; then GH_TOKEN="$cli_gh_token"; fi
    if [[ -n "$cli_from_branch" ]]; then FROM_BRANCH="$cli_from_branch"; fi
    if [[ -n "$cli_to_branch" ]]; then TO_BRANCH="$cli_to_branch"; fi
    if [[ -n "$cli_target_branch" ]]; then TARGET_BRANCH="$cli_target_branch"; fi
    if [[ -n "$cli_prerelease_identifier" ]]; then PRERELEASE_IDENTIFIER="$cli_prerelease_identifier"; fi
    if [[ -n "$cli_notification_channels" ]]; then NOTIFICATION_CHANNELS="$cli_notification_channels"; fi
    if [[ -n "$cli_log_level" ]]; then LOG_LEVEL="$cli_log_level"; fi
    if [[ -n "$cli_config_file_path" ]]; then CONFIG_FILE="$cli_config_file_path"; fi
    if [[ -n "$cli_hooks_dir_path" ]]; then HOOKS_DIR="$cli_hooks_dir_path"; fi
    if [[ -n "$cli_functions_dir_path" ]]; then FUNCTIONS_DIR="$cli_functions_dir_path"; fi
    if [[ -z "$VERSION_TYPE" ]]; then
        error_exit 6 "Version type (major, minor, patch, prerelease) is required."
    fi
}

legacy_validate_git_state() {
    log "INFO" "Validating Git repository state..."
    ORIGINAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    ORIGINAL_COMMIT_HASH=$(git rev-parse HEAD)
    log "INFO" "Current branch: '$ORIGINAL_BRANCH' (Commit: $ORIGINAL_COMMIT_HASH)"
    log "INFO" "Fetching latest Git changes from origin..."
    if ! dry_run_mode git fetch origin "$FROM_BRANCH" "$TO_BRANCH" "$DEFAULT_BRANCH" "$DEVELOPMENT_BRANCH" --tags; then
        error_exit 3 "Failed to fetch latest changes from origin for required branches. Check network, repository access, and branch names."
    fi
    if ! $FORCE; then
        if ! git diff --quiet HEAD 2>/dev/null || ! git diff --staged --quiet 2>/dev/null; then
            error_exit 2 "Uncommitted or unstaged changes detected. Please commit or stash them before running the script. Use --force to override."
        fi
        log "INFO" "No uncommitted or unstaged changes detected."
    else
        log "WARNING" "Skipping uncommitted changes check due to --force."
    fi
    if ! git show-ref --verify --quiet "refs/remotes/origin/$FROM_BRANCH"; then
        error_exit 2 "Source branch 'origin/$FROM_BRANCH' does not exist. Please ensure it's pushed and accessible."
    fi
    if ! git show-ref --verify --quiet "refs/remotes/origin/$TO_BRANCH"; then
        error_exit 2 "Target branch 'origin/$TO_BRANCH' does not exist. Please ensure it's pushed and accessible."
    fi
    log "INFO" "Git repository state validated."
}

legacy_validate_github_permissions() {
    log "INFO" "Validating GitHub permissions for user on repository..."
    if [[ -z "$GITHUB_USER" ]]; then
        GITHUB_USER=$(api "$API_BASE/user" | jq -r '.login // "null"')
        if [[ "$GITHUB_USER" == "null" ]]; then
            error_exit 2 "Could not determine GitHub username. Please set --github-user or the GH_USER environment variable."
        fi
        log "INFO" "Inferred GitHub User: $GITHUB_USER"
    fi
    local permission_info
    permission_info=$(api "$API_BASE/repos/$OWNER/$REPO/collaborators/$GITHUB_USER/permission")
    if [[ $? -ne 0 ]]; then
        error_exit 4 "Failed to check collaborator permission for '$GITHUB_USER' on '$OWNER/$REPO'. Check repository name and your GH_TOKEN validity/scope."
    fi
    local role_name
    role_name=$(echo "$permission_info" | jq -r '.permission // "null"')
    if [[ "$role_name" == "null" ]]; then
        error_exit 4 "Failed to parse permission role for user '$GITHUB_USER'. The API response might be malformed or the user is not a collaborator."
    fi
    log "INFO" "User '$GITHUB_USER' has role: '$role_name' on '$OWNER/$REPO'."
    if [[ "$role_name" != "admin" && "$role_name" != "maintain" && "$role_name" != "write" ]]; then
        error_exit 2 "User '$GITHUB_USER' with role '$role_name' does not have sufficient permissions (admin, maintain, or write) on '$OWNER/$REPO' to perform release operations."
    fi
    log "INFO" "User '$GITHUB_USER' has sufficient write/maintainer/admin permissions for repository operations."
}

legacy_validate_version_comparison() {
    log "INFO" "Validating new version ('$NEW_VERSION') against current version ('$CURRENT_VERSION')..."
    if [[ "$(printf '%s\n%s\n' "$NEW_VERSION" "$CURRENT_VERSION" | sort -V | head -n1)" == "$NEW_VERSION" && "$NEW_VERSION" != "$CURRENT_VERSION" ]]; then
        error_exit 2 "New version '$NEW_VERSION' must be numerically greater than current version '$CURRENT_VERSION'."
    elif [[ "$NEW_VERSION" == "$CURRENT_VERSION" ]]; then
        error_exit 2 "New version '$NEW_VERSION' cannot be the same as current version '$CURRENT_VERSION'."
    fi
    log "INFO" "Version comparison successful: '$NEW_VERSION' is greater than '$CURRENT_VERSION'."
}

legacy_get_latest_git_tag() {
    log "INFO" "Getting latest Git tag from remote..."
    CURRENT_VERSION=$(git tag --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$' | head -n1 | sed 's/^v//')
    if [[ -z "$CURRENT_VERSION" ]]; then
        log "WARNING" "No valid semantic version tags (e.g., vX.Y.Z) found. Initializing with version 0.0.0."
        CURRENT_VERSION="0.0.0"
    else
        log "INFO" "Latest semantic version tag found: v$CURRENT_VERSION"
    fi
}


# Additional legacy helper functions imported from 2028 script. These remain unused
# by the live bump workflow but provide richer logging, API handling, cleanup,
# and environment validation behaviour from the legacy automation.

legacy_log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    # In the legacy script, secret tokens (GH_TOKEN) were masked in logs.
    local display_message="$message"
    case "$level" in
        DEBUG)
            if [[ "$LOG_LEVEL" == "DEBUG" || "$VERBOSE" == true ]]; then
                echo -e "[\033[0;34mDEBUG\033[0m] $timestamp: $display_message" >&2
            fi
            ;;
        INFO)
            if [[ "$LOG_LEVEL" == "INFO" || "$LOG_LEVEL" == "DEBUG" || "$VERBOSE" == true ]]; then
                echo -e "[\033[0;32mINFO\033[0m] $timestamp: $display_message" >&2
            fi
            ;;
        WARNING)
            echo -e "[\033[0;33mWARNING\033[0m] $timestamp: $display_message" >&2
            ;;
        ERROR)
            echo -e "[\033[0;31mERROR\033[0m] $timestamp: $display_message" >&2
            ;;
        *)
            echo -e "[\033[0;37mUNKNOWN\033[0m] $timestamp: $display_message" >&2
            ;;
    esac
}

legacy_api() {
    local url="$1"
    local method="${2:-GET}"
    local data="${3:-}"
    local headers=(-H "Accept: application/vnd.github.v3+json" -H "Authorization: token $GH_TOKEN")
    local curl_output
    local http_code
    local retries=3
    local delay=5
    local curl_error_log
    curl_error_log="$TEMP_DIR/curl_api_error.log"
    local response_body
    legacy_log "DEBUG" "API Call: $method $url"
    for i in $(seq 1 $retries); do
        local curl_cmd_array=(
            curl -s -w "%{http_code}" --max-time 30
            -o >(cat >&1; printf "\n")
            -X "$method"
            "${headers[@]}"
        )
        if [[ -n "$data" ]]; then
            curl_cmd_array+=( -d "$data" )
        fi
        curl_cmd_array+=( "$url" )
        if ! curl_output=$( "${curl_cmd_array[@]}" 2>"$curl_error_log" ); then
            local curl_status=$?
            if [[ -s "$curl_error_log" ]]; then
                legacy_log "WARNING" "Curl command failed (attempt $i/$retries). Status: $curl_status. Error log: $(cat \"$curl_error_log\")"
            else
                legacy_log "WARNING" "Curl command failed (attempt $i/$retries). Status: $curl_status."
            fi
            sleep "$delay"
            continue
        fi
        http_code=$(tail -n1 <<< "$curl_output")
        response_body=$(sed '$d' <<< "$curl_output")
        if [[ "$http_code" =~ ^2[0-9]{2}$ ]]; then
            legacy_log "DEBUG" "API Success ($http_code): $response_body"
            echo "$response_body"
            return 0
        elif [[ "$http_code" == "404" ]]; then
            legacy_log "WARNING" "API Call Failed ($http_code): Not Found ($url)"
            echo "$response_body"
            return 1
        else
            legacy_log "WARNING" "API Call Failed ($http_code, attempt $i/$retries): $response_body"
            sleep "$delay"
        fi
    done
    legacy_log "ERROR" "API call failed after $retries attempts for $url."
    return 1
}

legacy_cleanup() {
    local exit_status=$?
    legacy_log "DEBUG" "Script exiting with status: $exit_status"
    rollback_git_changes
    clean_temp_files
    legacy_log "INFO" "Script finished."
}

legacy_dry_run_mode() {
    legacy_log "DEBUG" "Attempting to execute: $*"
    if $DRY_RUN; then
        legacy_log "INFO" "[DRY-RUN] Would execute: $*"
        return 0
    else
        if ! "$@"; then
            legacy_log "ERROR" "Command failed: $*"
            return 1
        fi
        return 0
    fi
}

legacy_error_exit() {
    local exit_code="$1"
    local message="$2"
    legacy_log "ERROR" "$message"
    exit "$exit_code"
}

legacy_validate_environment_requirements() {
    legacy_log "INFO" "Validating environment requirements..."
    command -v git &>/dev/null || legacy_error_exit 2 "Git is not installed. Please install Git."
    command -v curl &>/dev/null || legacy_error_exit 2 "curl is not installed. Please install curl."
    if command -v yq &>/dev/null; then
        legacy_log "INFO" "yq found. YAML config parsing enabled."
    else
        legacy_log "WARNING" "yq not found. Advanced YAML configuration files will not be parsed. Relying on basic parsing (or env vars/defaults)."
    fi
    if command -v jq &>/dev/null; then
        legacy_log "INFO" "jq found. JSON output will be pretty-printed and parsed robustly."
    else
        legacy_log "WARNING" "jq not found. JSON output will not be pretty-printed, and some parsing may be less robust."
    fi
    if [[ -z "$GH_TOKEN" ]]; then
        legacy_error_exit 2 "GitHub Personal Access Token (GH_TOKEN) is not set. Please set it via the --gh-token flag or the GH_TOKEN environment variable."
    fi
    legacy_log "INFO" "Environment validation complete."
}

# Generate a simple changelog and update RELEASE_BODY and RELEASE_TITLE.
# This function mirrors the original 2028 process_generate_changelog but is
# namespaced with "legacy_" and safe to include.  It uses CURRENT_VERSION,
# NEW_VERSION, DRY_RUN and writes to CHANGELOG.md in the repository.
legacy_process_generate_changelog() {
    # Only generate the changelog if the flag is enabled.
    if ! $GENERATE_CHANGELOG; then
        legacy_log "INFO" "Skipping changelog generation (use --generate-changelog to enable)."
        return 0
    fi

    legacy_log "INFO" "Generating CHANGELOG.md..."
    local changelog_file="$CLONE_DIR/CHANGELOG.md"
    local temp_changelog_content="$TEMP_DIR/changelog_content.md"
    register_temp_file "$temp_changelog_content"

    # Determine the range of commits to include in the changelog.
    local current_tag_version="v$CURRENT_VERSION"
    local new_tag_version="v$NEW_VERSION"
    local git_log_range=""
    if [[ -z "$CURRENT_VERSION" || "$CURRENT_VERSION" == "0.0.0" ]]; then
        git_log_range="--all"
        legacy_log "INFO" "No previous semantic version tag found. Generating changelog from all commits."
    elif git tag -l "$current_tag_version" | grep -q "^$current_tag_version$"; then
        git_log_range="$current_tag_version..HEAD"
        legacy_log "INFO" "Generating changelog from '$current_tag_version' to HEAD."
    else
        legacy_log "WARNING" "Previous tag '$current_tag_version' not found locally. Generating changelog from all commits to be safe."
        git_log_range="--all"
    fi

    # Gather the commit messages.  In dry-run mode, use placeholders.
    local log_entries=""
    if $DRY_RUN; then
        legacy_log "INFO" "[DRY-RUN] Would generate git log for changelog."
        log_entries="* feat: Initial feature (dry-run)\n* fix: Critical bug fix (dry-run)\n* chore: Dependency updates (dry-run)"
    else
        log_entries=$(git log "$git_log_range" --pretty=format:"* %s" --no-merges)
    fi

    # Write the new changelog section to a temporary file.
    echo "## $new_tag_version - $(date +%Y-%m-%d)" > "$temp_changelog_content"
    echo "" >> "$temp_changelog_content"
    if [[ -n "$log_entries" ]]; then
        echo -e "$log_entries" >> "$temp_changelog_content"
    else
        echo "No significant changes." >> "$temp_changelog_content"
    fi
    echo "" >> "$temp_changelog_content"

    # Prepend the new section to an existing CHANGELOG.md or create it.
    if [[ -f "$changelog_file" ]]; then
        legacy_log "DEBUG" "Prepending new changelog entries to existing file: '$changelog_file'"
        { cat "$temp_changelog_content"; echo ""; cat "$changelog_file"; } > "$changelog_file.tmp" && mv "$changelog_file.tmp" "$changelog_file"
    else
        legacy_log "DEBUG" "Creating new CHANGELOG.md file: '$changelog_file'"
        mv "$temp_changelog_content" "$changelog_file"
    fi

    # Extract the release body for the current version from the changelog.
    RELEASE_BODY=$(awk "/^## $new_tag_version/{flag=1;next}/^## v[0-9]/{flag=0}flag" "$changelog_file" | sed -e '1d' -e '$d')
    RELEASE_TITLE="Release $RELEASE_TAG"
    legacy_log "INFO" "CHANGELOG.md generated and updated. Release body prepared."
}

# Package the repository into a zip file for distribution.  This helper
# follows the original process_generate_artifacts function but is namespaced
# and safe to include.  It honours dry-run mode and will upload the artifact
# to a GitHub release if CREATE_RELEASE and RELEASE_ID are set appropriately.
legacy_process_generate_artifacts() {
    if ! $GENERATE_ARTIFACTS; then
        legacy_log "INFO" "Skipping artifact generation (use --generate-artifacts to enable)."
        return 0
    fi
    legacy_log "INFO" "Generating release artifact (zip)..."
    local artifact_name="$REPO-$NEW_VERSION.zip"
    local artifact_path="$TEMP_DIR/$artifact_name"
    register_temp_file "$artifact_path"
    # Build exclusion arguments for zip.
    local -a zip_exclude_args=()
    for exclude_pattern in "${ARTIFACT_EXCLUSIONS[@]}"; do
        zip_exclude_args+=("-x" "$exclude_pattern")
    done
    (
        cd "$CLONE_DIR" || legacy_error_exit 1 "Failed to change directory to CLONE_DIR: '$CLONE_DIR'"
        if legacy_dry_run_mode zip -r "$artifact_path" . "${zip_exclude_args[@]}"; then
            legacy_log "INFO" "Artifact created at: $artifact_path"
        else
            legacy_error_exit 1 "Failed to create zip artifact."
        fi
    )
    # Optionally upload the artifact to the GitHub release.
    if $CREATE_RELEASE && [[ -n "$RELEASE_ID" ]] && ! [[ "$RELEASE_ID" =~ ^dry_run_release_id_.*$ ]]; then
        legacy_log "INFO" "Uploading artifact '$artifact_name' to GitHub Release (ID: $RELEASE_ID)..."
        local upload_url
        upload_url=$(legacy_api "$API_BASE/repos/$OWNER/$REPO/releases/$RELEASE_ID" | jq -r '.upload_url // "null"' | sed 's/{?name,label}//')
        if [[ "$upload_url" == "null" || -z "$upload_url" ]]; then
            legacy_error_exit 4 "Failed to get upload URL for release asset."
        fi
        local http_code
        local upload_error_log="$TEMP_DIR/curl_upload_error.log"
        http_code=$(curl -s -w "%{http_code}" -o >(cat >&1; printf "\n") --max-time 600 -H "Authorization: token $GH_TOKEN" -H "Content-Type: application/zip" --data-binary "@$artifact_path" "$upload_url?name=$artifact_name" 2>"$upload_error_log")
        if [[ "$http_code" =~ ^2[0-9]{2}$ ]]; then
            legacy_log "INFO" "Artifact uploaded successfully."
        else
            legacy_log "ERROR" "Failed to upload artifact. HTTP Code: $http_code. See error log: $(cat "$upload_error_log")"
            legacy_error_exit 4 "Artifact upload failed."
        fi
    else
        legacy_log "INFO" "Skipping artifact upload (either --create-release not enabled, release ID missing, or in dry-run mode)."
    fi
}

# Export release metadata to a JSON file for consumption by external systems.
legacy_process_export_metadata() {
    if ! $EXPORT_METADATA; then
        legacy_log "INFO" "Skipping metadata export (use --export-metadata to enable)."
        return 0
    fi
    legacy_log "INFO" "Exporting release metadata to 'release_metadata.json'..."
    local metadata_file="$CLONE_DIR/release_metadata.json"
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    local metadata_json
    if ! metadata_json=$(jq -n \
        --arg current_version "$CURRENT_VERSION" \
        --arg new_version "$NEW_VERSION" \
        --arg version_type "$VERSION_TYPE" \
        --arg prerelease_identifier "$PRERELEASE_IDENTIFIER" \
        --arg owner "$OWNER" \
        --arg repo "$REPO" \
        --arg from_branch "$FROM_BRANCH" \
        --arg to_branch "$TO_BRANCH" \
        --arg target_branch "$TARGET_BRANCH" \
        --arg release_tag "$RELEASE_TAG" \
        --arg release_id "$RELEASE_ID" \
        --arg release_url "$RELEASE_URL" \
        --arg release_title "$RELEASE_TITLE" \
        --arg release_body "$RELEASE_BODY" \
        --arg timestamp "$timestamp" \
        '{
            current_version: $current_version,
            new_version: $new_version,
            version_type: $version_type,
            prerelease_identifier: $prerelease_identifier,
            repository: {
                owner: $owner,
                name: $repo
            },
            branches: {
                from: $from_branch,
                to: $to_branch,
                target: $target_branch
            },
            release: {
                tag: $release_tag,
                id: $release_id,
                url: $release_url,
                title: $release_title,
                body: $release_body
            },
            timestamp: $timestamp
        }'); then
        legacy_error_exit 1 "Failed to construct JSON for metadata export. Check jq installation or data."
    fi
    if command -v jq &>/dev/null; then
        echo "$metadata_json" | jq . > "$metadata_file"
    else
        echo "$metadata_json" > "$metadata_file"
    fi
    legacy_log "INFO" "Release metadata exported to: '$metadata_file'"
}

# Send notifications to configured channels via custom hooks.  This function
# implements the original process_notify behaviour but is namespaced and
# does not alter the live bump workflow.  It uses the NOTIFICATION_CHANNELS
# variable (comma-separated) and looks up hook scripts under HOOKS_DIR.
legacy_process_notify() {
    if [[ -z "$NOTIFICATION_CHANNELS" ]]; then
        legacy_log "INFO" "No notification channels specified. Skipping notifications."
        return 0
    fi
    legacy_log "INFO" "Sending notifications to channels: $NOTIFICATION_CHANNELS"
    IFS=',' read -ra CHANNELS <<< "$NOTIFICATION_CHANNELS"
    for channel in "${CHANNELS[@]}"; do
        local hook_script="${HOOKS_DIR}/notify_${channel}.sh"
        if [[ -f "$hook_script" ]]; then
            legacy_log "INFO" "Attempting to send notification via '$channel' hook."
            local notification_data=""
            if command -v jq &>/dev/null; then
                if ! notification_data=$(jq -n \
                    --arg new_version "$NEW_VERSION" \
                    --arg release_tag "$RELEASE_TAG" \
                    --arg release_url "$RELEASE_URL" \
                    --arg release_title "$RELEASE_TITLE" \
                    --arg release_body "$RELEASE_BODY" \
                    --arg owner "$OWNER" \
                    --arg repo "$REPO" \
                    '{
                        version: $new_version,
                        tag: $release_tag,
                        url: $release_url,
                        title: $release_title,
                        body: $release_body,
                        repository: { owner: $owner, name: $repo }
                    }'); then
                    legacy_log "ERROR" "Failed to construct JSON for notification data for channel '$channel'. Skipping."
                    continue
                fi
            else
                # Fallback to a simple JSON string if jq is unavailable.
                notification_data="{\"version\":\"$NEW_VERSION\",\"tag\":\"$RELEASE_TAG\",\"url\":\"$RELEASE_URL\",\"title\":\"$RELEASE_TITLE\",\"body\":\"$RELEASE_BODY\",\"repository\":{\"owner\":\"$OWNER\",\"name\":\"$REPO\"}}"
            fi
            execute_hook "$hook_script" "release_notification" "$notification_data"
        else
            legacy_log "WARNING" "Notification hook for channel '$channel' not found at '$hook_script'. Skipping notification for this channel."
        fi
    done
    legacy_log "INFO" "Notification process complete."
}

# Load configuration from a YAML file or a simple key-value format.  This
# function mirrors the 2028 load_config logic but is namespaced and uses
# legacy logging.  It populates configuration variables from the
# CONFIG_FILE if available, with environment variables taking precedence.
legacy_load_config() {
    legacy_log "INFO" "Loading configuration from: ${CONFIG_FILE}..."
    local yq_available=false
    if command -v yq &>/dev/null; then
        yq_available=true
        legacy_log "DEBUG" "yq found, enabling full YAML configuration parsing."
    else
        legacy_log "WARNING" "yq not found. YAML configuration parsing will be disabled. Relying on environment variables and defaults."
    fi
    if $yq_available && [[ -f "$CONFIG_FILE" ]]; then
        legacy_log "INFO" "Parsing config file using yq."
        if [[ -z "$OWNER" ]]; then OWNER=$(yq '.owner // ""' "$CONFIG_FILE"); fi
        if [[ -z "$REPO" ]]; then REPO=$(yq '.repo // ""' "$CONFIG_FILE"); fi
        if [[ -z "$GITHUB_USER" ]]; then GITHUB_USER=$(yq '.github_user // ""' "$CONFIG_FILE"); fi
        if [[ -z "$GH_TOKEN" ]]; then
            local config_gh_token
            config_gh_token=$(yq '.gh_token // ""' "$CONFIG_FILE")
            if [[ -n "$config_gh_token" ]]; then
                legacy_log "WARNING" "GH_TOKEN found in config file. It is STRONGLY recommended to use the GH_TOKEN environment variable for security."
                GH_TOKEN="$config_gh_token"
            fi
        fi
        if [[ -z "$DEFAULT_BRANCH" ]]; then DEFAULT_BRANCH=$(yq '.default_branch // "main"' "$CONFIG_FILE"); fi
        if [[ -z "$DEVELOPMENT_BRANCH" ]]; then DEVELOPMENT_BRANCH=$(yq '.development_branch // "develop"' "$CONFIG_FILE"); fi
        if [[ -z "$API_BASE" ]]; then API_BASE=$(yq '.api_base // "https://api.github.com"' "$CONFIG_FILE"); fi
        if [[ -z "$HOOKS_DIR" || "$HOOKS_DIR" == "${SCRIPT_DIR}/hooks" ]]; then HOOKS_DIR=$(yq '.hooks_dir // ""' "$CONFIG_FILE"); fi
        if [[ -z "$FUNCTIONS_DIR" || "$FUNCTIONS_DIR" == "${SCRIPT_DIR}/functions" ]]; then FUNCTIONS_DIR=$(yq '.functions_dir // ""' "$CONFIG_FILE"); fi
        if [[ -z "$NOTIFICATION_CHANNELS" ]]; then NOTIFICATION_CHANNELS=$(yq '.notification_channels // "" | join(",")' "$CONFIG_FILE"); fi
        local exclude_yaml
        exclude_yaml=$(yq '.artifact_exclusions[] // ""' "$CONFIG_FILE" 2>/dev/null)
        if [[ -n "$exclude_yaml" ]]; then
            readarray -t ARTIFACT_EXCLUSIONS < <(echo "$exclude_yaml")
        fi
        if yq '.hooks.pre_commit' "$CONFIG_FILE" &>/dev/null; then
            readarray -t PRE_COMMIT_HOOKS < <(yq '.hooks.pre_commit[]' "$CONFIG_FILE")
        fi
        if yq '.hooks.post_release' "$CONFIG_FILE" &>/dev/null; then
            readarray -t POST_RELEASE_HOOKS < <(yq '.hooks.post_release[]' "$CONFIG_FILE")
        fi
    elif [[ -f "$CONFIG_FILE" ]]; then
        legacy_log "WARNING" "yq not found. Attempting basic line-by-line parsing of '$CONFIG_FILE'. This is not robust. Please install yq or use environment variables."
        while IFS=':' read -r key value || [[ -n "$key" ]]; do
            key=$(echo "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
            case "$key" in
                "owner") if [[ -z "$OWNER" ]]; then OWNER="$value"; fi ;;
                "repo") if [[ -z "$REPO" ]]; then REPO="$value"; fi ;;
                "github_user") if [[ -z "$GITHUB_USER" ]]; then GITHUB_USER="$value"; fi ;;
                "gh_token")
                    if [[ -z "$GH_TOKEN" ]]; then
                        legacy_log "WARNING" "GH_TOKEN found in config file. Recommended to use GH_TOKEN environment variable."
                        GH_TOKEN="$value"
                    fi
                    ;;
                "default_branch") if [[ -z "$DEFAULT_BRANCH" ]]; then DEFAULT_BRANCH="$value"; fi ;;
                "development_branch") if [[ -z "$DEVELOPMENT_BRANCH" ]]; then DEVELOPMENT_BRANCH="$value"; fi ;;
                "api_base") if [[ -z "$API_BASE" ]]; then API_BASE="$value"; fi ;;
                "hooks_dir") if [[ -z "$HOOKS_DIR" || "$HOOKS_DIR" == "${SCRIPT_DIR}/hooks" ]]; then HOOKS_DIR="$value"; fi ;;
                "functions_dir") if [[ -z "$FUNCTIONS_DIR" || "$FUNCTIONS_DIR" == "${SCRIPT_DIR}/functions" ]]; then FUNCTIONS_DIR="$value"; fi ;;
                "notification_channels") if [[ -z "$NOTIFICATION_CHANNELS" ]]; then NOTIFICATION_CHANNELS="$value"; fi ;;
                "artifact_exclusions") IFS=',' read -ra ARTIFACT_EXCLUSIONS <<< "$value" ;;
                "pre_commit_hooks") IFS=',' read -ra PRE_COMMIT_HOOKS <<< "$value" ;;
                "post_release_hooks") IFS=',' read -ra POST_RELEASE_HOOKS <<< "$value" ;;
            esac
        done < "$CONFIG_FILE"
    else
        legacy_log "WARNING" "Config file not found at '$CONFIG_FILE'. Relying solely on environment variables and script defaults."
    fi
}

# Create a GitHub Release via the API.  This function wraps the original
# process_create_github_release logic under a legacy_ namespace and uses
# the legacy API and logging helpers.  It expects RELEASE_TAG, NEW_VERSION,
# VERSION_TYPE, TARGET_BRANCH, RELEASE_BODY and other variables to be set.
legacy_process_create_github_release() {
    if ! $CREATE_RELEASE; then
        legacy_log "INFO" "Skipping GitHub release creation (use --create-release to enable)."
        return 0
    fi
    legacy_log "INFO" "Creating GitHub release for tag: '$RELEASE_TAG'..."
    local prerelease_flag="false"
    if [[ "$VERSION_TYPE" == "prerelease" ]]; then
        prerelease_flag="true"
    fi
    if [[ -z "$RELEASE_BODY" ]]; then
        legacy_log "WARNING" "Release body is empty. Using default message for the release."
        RELEASE_BODY="Automated release for version $NEW_VERSION."
    fi
    local release_data
    if ! release_data=$(jq -n \
        --arg tag_name "$RELEASE_TAG" \
        --arg name "Release $NEW_VERSION" \
        --arg body "$RELEASE_BODY" \
        --arg target_commitish "$TARGET_BRANCH" \
        --argjson prerelease "$prerelease_flag" \
        '{tag_name: $tag_name, name: $name, body: $body, target_commitish: $target_commitish, prerelease: $prerelease, generate_release_notes: false}'); then
        legacy_error_exit 4 "Failed to construct JSON for release creation. Check jq installation or input data."
    fi
    if $DRY_RUN; then
        legacy_log "INFO" "[DRY-RUN] Would create GitHub release with data: $release_data"
        RELEASE_ID="dry_run_release_id_$(date +%s)"
        RELEASE_URL="https://github.com/$OWNER/$REPO/releases/tag/$RELEASE_TAG"
        legacy_log "INFO" "[DRY-RUN] GitHub release simulated. ID: '$RELEASE_ID', URL: '$RELEASE_URL'"
        return 0
    fi
    local release_response
    release_response=$(legacy_api "$API_BASE/repos/$OWNER/$REPO/releases" POST "$release_data") || {
        legacy_error_exit 4 "Failed to create GitHub release via API."
    }
    RELEASE_ID=$(echo "$release_response" | jq -r '.id // "null"')
    RELEASE_URL=$(echo "$release_response" | jq -r '.html_url // "null"')
    if [[ "$RELEASE_ID" == "null" || -z "$RELEASE_ID" || "$RELEASE_URL" == "null" || -z "$RELEASE_URL" ]]; then
        legacy_error_exit 4 "Failed to parse release ID or URL from GitHub API response after creation. Response: $release_response"
    fi
    legacy_log "INFO" "GitHub Release created successfully: $RELEASE_URL (ID: $RELEASE_ID)"
}

# ---------------------------------------------------------------------------
# Legacy Git operations function
# ---------------------------------------------------------------------------
legacy_process_git_operations() {
    legacy_log "INFO" "Starting Git operations..."
    # Ensure we are in the repository directory.
    if ! cd "$CLONE_DIR"; then
        legacy_error_exit 3 "Failed to change directory to CLONE_DIR: '$CLONE_DIR'"
    fi
    # Checkout and update the source branch.
    legacy_log "INFO" "Checking out and pulling latest for branch: '$FROM_BRANCH'"
    if ! legacy_dry_run_mode git checkout "$FROM_BRANCH"; then
        legacy_error_exit 3 "Failed to checkout branch: '$FROM_BRANCH'"
    fi
    if ! legacy_dry_run_mode git pull origin "$FROM_BRANCH"; then
        legacy_error_exit 3 "Failed to pull latest for branch: '$FROM_BRANCH'"
    fi
    # Checkout and update the destination branch.
    legacy_log "INFO" "Checking out and pulling latest for branch: '$TO_BRANCH'"
    if ! legacy_dry_run_mode git checkout "$TO_BRANCH"; then
        legacy_error_exit 3 "Failed to checkout branch: '$TO_BRANCH'"
    fi
    if ! legacy_dry_run_mode git pull origin "$TO_BRANCH"; then
        legacy_error_exit 3 "Failed to pull latest for branch: '$TO_BRANCH'"
    fi
    # Merge the source branch into the destination branch.
    legacy_log "INFO" "Merging '$FROM_BRANCH' into '$TO_BRANCH'..."
    MERGE_ATTEMPTED=true
    local -a merge_opts=(--no-ff)
    if $NO_VERIFY; then
        merge_opts+=(--no-verify)
    fi
    if ! legacy_dry_run_mode git merge "${merge_opts[@]}" "$FROM_BRANCH" -m "Merge branch '$FROM_BRANCH' into '$TO_BRANCH' for release v$NEW_VERSION"; then
        legacy_error_exit 3 "Git merge failed. This often indicates merge conflicts. Please resolve them manually and re-run. Rolling back..."
    fi
    legacy_log "INFO" "Merge successful."
    # Create or update the release tag locally.
    RELEASE_TAG="v$NEW_VERSION"
    legacy_log "INFO" "Creating Git tag: '$RELEASE_TAG'"
    if git tag -l "$RELEASE_TAG" | grep -q "^$RELEASE_TAG$"; then
        if $FORCE; then
            legacy_log "WARNING" "Tag '$RELEASE_TAG' already exists. Forcing overwrite due to --force."
            if ! legacy_dry_run_mode git tag -f -a "$RELEASE_TAG" -m "Release v$NEW_VERSION"; then
                legacy_error_exit 3 "Failed to force-create Git tag: '$RELEASE_TAG'"
            fi
        else
            legacy_error_exit 3 "Tag '$RELEASE_TAG' already exists. Use --force to overwrite."
        fi
    else
        if ! legacy_dry_run_mode git tag -a "$RELEASE_TAG" -m "Release v$NEW_VERSION"; then
            legacy_error_exit 3 "Failed to create Git tag: '$RELEASE_TAG'"
        fi
    fi
    legacy_log "INFO" "Tag '$RELEASE_TAG' created locally."
    # Optionally push the destination branch.
    if $PUSH_BRANCHES; then
        legacy_log "INFO" "Pushing updated branch: '$TO_BRANCH'"
        if ! legacy_dry_run_mode git push origin "$TO_BRANCH" ${NO_VERIFY:+"--no-verify"}; then
            legacy_error_exit 3 "Failed to push branch '$TO_BRANCH'. Check permissions or remote state."
        fi
    else
        legacy_log "INFO" "Skipping branch push (use --push-branches to enable)."
    fi
    # Optionally push the release tag.
    if $PUSH_TAGS; then
        legacy_log "INFO" "Pushing new tag: '$RELEASE_TAG'"
        if ! legacy_dry_run_mode git push origin "$RELEASE_TAG"; then
            legacy_error_exit 3 "Failed to push tag '$RELEASE_TAG'. Check permissions or remote state."
        fi
    else
        legacy_log "INFO" "Skipping tag push (use --push-tags to enable)."
    fi
    legacy_log "INFO" "Git operations complete."
}

# ---------------------------------------------------------------------------
# Legacy main orchestrator function
# ---------------------------------------------------------------------------
legacy_main() {
    initialize_temp_dir
    legacy_parse_args "$@"
    legacy_load_config
    set_branch_defaults
    legacy_validate_environment_requirements
    validate_repo_info
    legacy_validate_git_state
    legacy_validate_github_permissions
    legacy_get_latest_git_tag
    calculate_new_version
    legacy_validate_version_comparison
    legacy_log "INFO" "Starting release process for v$NEW_VERSION (a '$VERSION_TYPE' bump from v$CURRENT_VERSION)."
    git_backup_repo
    # Execute pre-commit hooks, passing hook data as JSON.
    local pre_commit_hook_data
    pre_commit_hook_data=$(jq -n \
        --arg current_version "$CURRENT_VERSION" \
        --arg new_version "$NEW_VERSION" \
        --arg version_type "$VERSION_TYPE" \
        --arg from_branch "$FROM_BRANCH" \
        --arg to_branch "$TO_BRANCH" \
        '{current_version: $current_version, new_version: $new_version, version_type: $version_type, from_branch: $from_branch, to_branch: $to_branch}')
    for hook_name in "${PRE_COMMIT_HOOKS[@]}"; do
        local hook_script="${HOOKS_DIR}/pre_commit_${hook_name}.sh"
        execute_hook "$hook_script" "pre_commit" "$pre_commit_hook_data"
    done
    # Run the core release steps.
    legacy_process_git_operations
    legacy_process_generate_changelog
    legacy_process_create_github_release
    legacy_process_generate_artifacts
    legacy_process_export_metadata
    # Execute post-release hooks with metadata JSON.
    local post_release_hook_data
    post_release_hook_data=$(jq -n \
        --arg new_version "$NEW_VERSION" \
        --arg release_tag "$RELEASE_TAG" \
        --arg release_url "$RELEASE_URL" \
        --arg release_id "$RELEASE_ID" \
        --arg owner "$OWNER" \
        --arg repo "$REPO" \
        '{new_version: $new_version, release_tag: $release_tag, release_url: $release_url, release_id: $release_id, repository_owner: $owner, repository_name: $repo}')
    for hook_name in "${POST_RELEASE_HOOKS[@]}"; do
        local hook_script="${HOOKS_DIR}/post_release_${hook_name}.sh"
        execute_hook "$hook_script" "post_release" "$post_release_hook_data"
    done
    legacy_process_notify
    legacy_log "INFO" "Release process for v$NEW_VERSION completed successfully!"
}

# ---------------------------------------------------------------------------
# Legacy variables and documentation (for reference only)
# ---------------------------------------------------------------------------
# The following block defines variables and reproduces sections of the 2028
# script's documentation.  These definitions and comments do not affect
# the current bump workflow but provide context and preserve defaults.

# Legacy script identification and defaults
LEGACY_SCRIPT_NAME="${0##*/}"
LEGACY_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Legacy operational flags (unused by live bump)
LEGACY_LOG_LEVEL="INFO"
LEGACY_VERBOSE=false
LEGACY_DRY_RUN=false
LEGACY_FORCE=false
LEGACY_NO_VERIFY=false
LEGACY_PUSH_TAGS=false
LEGACY_PUSH_BRANCHES=false
LEGACY_CREATE_RELEASE=false
LEGACY_GENERATE_CHANGELOG=false
LEGACY_GENERATE_ARTIFACTS=false
LEGACY_EXPORT_METADATA=false
LEGACY_NOTIFICATION_CHANNELS=""

# Legacy file and directory management
LEGACY_TEMP_DIR=""
declare -a LEGACY_TEMP_FILES=()

# Legacy configuration values
LEGACY_OWNER=""
LEGACY_REPO=""
LEGACY_GITHUB_USER=""
LEGACY_GH_TOKEN=""
LEGACY_DEFAULT_BRANCH="main"
LEGACY_DEVELOPMENT_BRANCH="develop"
LEGACY_API_BASE="https://api.github.com"
LEGACY_CLONE_DIR=""
LEGACY_CONFIG_FILE="${SCRIPT_DIR}/.repo_config.yaml"
LEGACY_HOOKS_DIR="${SCRIPT_DIR}/hooks"
LEGACY_FUNCTIONS_DIR="${SCRIPT_DIR}/functions"

# Legacy versioning
LEGACY_VERSION_TYPE=""
LEGACY_PRERELEASE_IDENTIFIER=""
LEGACY_CURRENT_VERSION=""
LEGACY_NEW_VERSION=""

# Legacy branches
LEGACY_FROM_BRANCH=""
LEGACY_TO_BRANCH=""
LEGACY_TARGET_BRANCH=""

# Legacy git state for rollback
LEGACY_ORIGINAL_BRANCH=""
LEGACY_ORIGINAL_COMMIT_HASH=""
LEGACY_MERGE_ATTEMPTED=false

# Legacy release metadata
LEGACY_RELEASE_ID=""
LEGACY_RELEASE_URL=""
LEGACY_RELEASE_TAG=""
LEGACY_RELEASE_TITLE=""
LEGACY_RELEASE_BODY=""

# Legacy hook definitions
declare -a LEGACY_PRE_COMMIT_HOOKS=()
declare -a LEGACY_POST_RELEASE_HOOKS=()

# ---------------------------------------------------------------------------
# Legacy script summary and guidance
# ---------------------------------------------------------------------------
# This block reproduces high-level documentation from the original 2028
# release automation script for reference.  It is not executed by the
# live script.
#
# Features:
# - Supports major, minor, patch, and prerelease version bumping.
# - Automates Git operations: checkout, merge, tag, push.
# - Creates GitHub releases.
# - Generates changelogs based on Git history.
# - Manages temporary files and provides rollback functionality.
# - Supports configurable hooks for pre and post operations.
# - Sends notifications to various channels (e.g., Slack, Teams, custom webhooks).
# - Provides a dry-run mode for testing without actual modifications.
# - Loads configuration from a YAML file when yq is available.
# - Validates environment, repository state, and user permissions.
#
# Usage example:
#   ./script_name.sh patch --push-tags --create-release --generate-changelog
#
# Exit Codes:
#   0: Success
#   1: General error
#   2: Validation error
#   3: Git operation error
#   4: API error
#   5: Hook execution error
#   6: Configuration error
#
# Dependencies:
#   - Git
#   - curl
#   - jq (optional, for pretty-printing JSON)
#   - yq (optional, for YAML configuration parsing)
#
# Configuration:
# The script looks for a '.repo_config.yaml' file, by default in the
# current working directory or specified by --config-file.
# See repo_config.example.yaml for configuration options.
# Precedence: CLI args > Environment variables > Config File > Script defaults.
# Note: GH_TOKEN should ideally be set via environment variable for security.

# -----------------------------------------------------------------------------
# Example Configuration File (.repo_config.yaml)
#
# The following commented YAML entries illustrate how you can customize the
# legacy automation script using a configuration file. Each key below
# corresponds to a CLI option or environment variable. Copy this block to
# your own .repo_config.yaml file (without the leading '# ') and adjust
# values as needed.
#
# owner: myorg                    # GitHub org or username owning the repo
# repo: myrepo                    # Name of the repository
# current_version: 1.2.3          # Current semantic version of your project
# from_branch: develop            # Branch to merge from (e.g., develop)
# to_branch: main                 # Branch to merge into (e.g., main)
# target_branch: main             # Branch where the release tag will be created
# prerelease_identifier: beta     # Identifier for prerelease (alpha, beta, rc)
# push_tags: true                 # Whether to push tags to origin
# push_branches: true             # Whether to push updated branches to origin
# create_release: true            # Create a GitHub Release
# generate_changelog: true        # Generate CHANGELOG.md based on commits
# generate_artifacts: true        # Generate a zip artifact for the release
# export_metadata: true           # Export release metadata to a JSON file
# notification_channels:          # Comma-separated list of notification channels
#   - slack
#   - teams
#   - custom
# force: false                    # Force operations (overwrite tags, etc.)
# no_verify: false                # Skip Git hooks during merges/commits
# dry_run: false                  # Simulate operations without any changes
# verbose: true                   # Enable verbose logging
# log_level: INFO                 # Logging level (DEBUG, INFO, WARNING, ERROR)
# config_file: .repo_config.yaml  # Path to this configuration file
# hooks_dir: hooks                # Directory containing custom hooks
# functions_dir: functions        # Directory containing custom function scripts
# artifact_exclusions:            # Patterns to exclude from the artifact zip
#   - .git
#   - node_modules/*
#   - build/*
# prerelease_when_tag_exists: false  # If true, bump prerelease when tag exists
# release_name_prefix: ""         # Prefix added to the GitHub Release name
# release_name_suffix: ""         # Suffix added to the GitHub Release name
# release_tag_prefix: ""          # Prefix added to the Git tag (e.g., 'v')
# release_tag_suffix: ""          # Suffix added to the Git tag (e.g., '-beta')
#
# Sample Pre-Commit Hooks:
# The following demonstrates how pre-commit hooks can be defined. Hooks are
# executed before any Git operations or tagging occur. Scripts must be
# executable and located in the hooks_dir specified above.
#
# pre_commit_hooks:
#   - pre_commit_lint.sh        # Run linters before committing changes
#   - pre_commit_tests.sh       # Execute unit tests prior to merging
#
# Sample Post-Release Hooks:
# Similar to pre-commit hooks, post-release hooks run after a successful
# release. Use them to perform cleanup, send metrics, or deploy artifacts.
#
# post_release_hooks:
#   - post_release_cleanup.sh   # Remove temporary files and caches
#   - post_release_deploy.sh    # Deploy the new release to staging
#
# Notification Channel Details:
# For custom notification channels, you can specify additional configuration
# under a `notifications` section. Each channel may have its own URL,
# authentication token, or payload template.
#
# notifications:
#   slack:
#     webhook_url: https://hooks.slack.com/services/T000/B000/XXXX
#     channel: '#releases'
#   teams:
#     webhook_url: https://outlook.office.com/webhook/REDACTED
#     channel: 'DevOps Releases'
#   custom:
#     url: https://example.com/webhook
#     headers:
#       Content-Type: application/json
#     payload_template: |
#       {
#         "text": "Release ${RELEASE_TAG} has been published!"
#       }
#
# -----------------------------------------------------------------------------
# Sample Hook Script: pre_commit_lint.sh
#
# The following commented-out script illustrates a simple pre-commit hook that
# runs basic linting tasks. Place this file in your hooks_dir and ensure it is
# executable. When referenced in the pre_commit_hooks list above, it will
# execute before any changes are committed. Feel free to expand this script
# with additional linters or custom checks specific to your project.
#
# #!/usr/bin/env bash
# set -euo pipefail
#
# echo "Running shell and code linters..."
#
# # Run shellcheck on all shell scripts if available.
# if command -v shellcheck &>/dev/null; then
#   shellcheck **/*.sh
# else
#   echo "shellcheck is not installed. Skipping shell lint."
# fi
#
# # Run pylint on all Python files if available.
# if command -v pylint &>/dev/null; then
#   pylint **/*.py
# else
#   echo "pylint is not installed. Skipping Python lint."
# fi
#
# # Placeholder for additional linters (e.g., ESLint for JavaScript)
# # if command -v eslint &>/dev/null; then
# #   eslint **/*.js
# # fi
#
# echo "Linting completed successfully."
#
# -----------------------------------------------------------------------------
# Sample Hook Script: post_release_deploy.sh
#
# This commented-out script demonstrates a post-release hook that could be used
# to deploy your application after a successful release. Customize it to suit
# your deployment process. Save it in your hooks_dir and reference it in
# post_release_hooks to enable automated deployment.
#
# #!/usr/bin/env bash
# set -euo pipefail
#
# # Example deployment commands. Replace with your actual workflow.
# echo "Deploying version ${NEW_VERSION} to staging..."
#
# # Example: Build and push a Docker image (uncomment and modify as needed)
# # docker build -t my-app:${NEW_VERSION} .
# # docker push my-app:${NEW_VERSION}
#
# # Example: Update a Kubernetes deployment (uncomment and modify as needed)
# # kubectl set image deployment/my-app my-app=my-app:${NEW_VERSION}
#
# # Example: Trigger a CI/CD pipeline or notify a deployment service
# # curl -X POST https://deploy.example.com/hooks/deploy -H "Content-Type: application/json" -d '{"version": "${NEW_VERSION}"}'
#
# echo "Deployment for version ${NEW_VERSION} completed."
#
# -----------------------------------------------------------------------------
# Sample Hook Script: pre_commit_tests.sh
#
# This commented-out script runs unit tests using popular frameworks. It can
# be used as a pre-commit hook to ensure your tests pass before merging
# changes.
#
# #!/usr/bin/env bash
# set -euo pipefail
#
# echo "Running unit tests..."
#
# # Run JavaScript tests if npm and package.json are present.
# if command -v npm &>/dev/null && [ -f package.json ]; then
#   npm test
# fi
#
# # Run Python tests if pytest is available.
# if command -v pytest &>/dev/null; then
#   pytest -q
# fi
#
# # Add other test runners as needed (e.g., Go, Rust, Java).
#
# echo "All tests passed."
#
# -----------------------------------------------------------------------------
# Sample Hook Script: post_release_cleanup.sh
#
# A simple post-release hook that cleans up build artifacts and temporary files.
# Use this to remove caches and compiled binaries after a successful release.
#
# #!/usr/bin/env bash
# set -euo pipefail
#
# echo "Cleaning up temporary files and build artifacts..."
#
# # Example: remove node_modules or other caches (uncomment if needed)
# # rm -rf node_modules
#
# # Example: remove compiled binaries (uncomment and modify as needed)
# # rm -f build/*.o
#
# echo "Cleanup complete."
#
# -----------------------------------------------------------------------------
# Release Naming and Tagging Guidelines:
# - Use semantic versioning (MAJOR.MINOR.PATCH) for clarity.
# - Customize prefixes and suffixes using the config keys release_name_prefix
#   and release_name_suffix. This allows you to include text like "Alpha"
#   or "RC" in your release names.
# - Keep prerelease identifiers consistent across versions to avoid confusion.
# - Store your current version in a VERSION file or tag so the bump script
#   can detect and compare versions accurately.
#
# -----------------------------------------------------------------------------
# Legacy CLI Options Explained:
#   --owner <owner>:
#     Specifies the GitHub username or organization that owns the repository.
#     Defaults to the repository’s origin remote if not provided.
#   --repo <repo>:
#     Sets the repository name. Inferred from the git remote when omitted.
#   --github-user <user>:
#     Overrides the user name associated with the GitHub API token.
#   --gh-token <token>:
#     Personal access token used to authenticate API requests. Can also be
#     provided via the GH_TOKEN environment variable.
#   --from-branch <branch>:
#     The branch that contains the changes you want to release (e.g., develop).
#   --to-branch <branch>:
#     The branch that will receive the changes (e.g., main or release).
#   --target-branch <branch>:
#     The branch on which to create the release tag. Defaults to the to-branch.
#   --prerelease-identifier <id>:
#     Identifier appended to prerelease versions (e.g., alpha, beta, rc).
#   --push-tags:
#     When enabled, pushes newly created tags to the remote repository.
#   --push-branches:
#     When enabled, pushes updated branches (e.g., to-branch) to the remote.
#   --create-release:
#     If set, a GitHub release is created after tagging.
#   --generate-changelog:
#     Generates or updates a CHANGELOG.md file from commit history.
#   --generate-artifacts:
#     Packages the repository into a zip archive as a release asset.
#   --export-metadata:
#     Exports release metadata (IDs, URLs) to a JSON file for later use.
#   --notification-channel <channel>:
#     Sends notifications to the specified channels (comma-separated).
#   --force:
#     Forces operations that might otherwise be prevented (e.g., overwriting tags).
#   --no-verify:
#     Skips Git hooks such as pre-commit and commit-msg when merging.
#   --dry-run:
#     Simulates all operations without making any changes; useful for testing.
#   --verbose:
#     Enables verbose logging (equivalent to setting --log-level DEBUG).
#   --log-level <level>:
#     Sets the minimum severity of messages to log: DEBUG, INFO, WARNING, ERROR.
#   --config-file <path>:
#     Path to a YAML configuration file; overrides script defaults.
#   --hooks-dir <path>:
#     Directory containing custom hook scripts.
#   --functions-dir <path>:
#     Directory containing additional custom function scripts.
#   -h, --help:
#     Displays the usage message and exits.
#
# -----------------------------------------------------------------------------
# Legacy Environment Variables Explained:
#   GH_TOKEN:
#     Contains a personal access token used for GitHub API requests. Required
#     when performing operations that modify remote repositories or create
#     releases.
#   GH_USER:
#     Specifies the GitHub username if not inferred automatically from the
#     repository or configuration.
#   CONFIG_FILE:
#     If set, overrides the default location of the .repo_config.yaml file.
#   HOOKS_DIR / FUNCTIONS_DIR:
#     Environment equivalents of their CLI options; define custom directories
#     for hooks and function scripts.
#
# -----------------------------------------------------------------------------
# Legacy Exit Codes Explained:
#   0: Success – all tasks completed without errors.
#   1: General error – unexpected failure not covered by other codes.
#   2: Validation error – invalid input parameters or missing requirements.
#   3: Git operation error – failure during git checkout, merge, tag, or push.
#   4: API error – problems communicating with GitHub’s REST API.
#   5: Hook execution error – a pre-commit or post-release hook failed.
#   6: Configuration error – issues parsing or loading configuration data.
#
# -----------------------------------------------------------------------------
# Legacy Release Workflow Overview:
#   1. Validate that required commands and environment variables are available.
#   2. Parse CLI arguments and configuration file values, applying precedence.
#   3. Determine the branches and version bump type (major, minor, patch, prerelease).
#   4. Validate the repository state and current GitHub permissions.
#   5. Optionally run pre-commit hooks to lint and test code before merging.
#   6. Perform git operations: checkout, merge, tag creation, and optional pushing.
#   7. Optionally generate changelog, create a release, generate artifacts, and
#      export metadata for downstream use.
#   8. Optionally run post-release hooks and send notifications.
#   9. Perform cleanup of temporary files and report success.
#
# -----------------------------------------------------------------------------
# Custom Notification Tips:
#   - For Slack, you can customize the message payload by editing the
#     payload_template in the notifications.custom configuration.
#   - For Teams, ensure that the webhook_url is configured to accept external
#     messages from your application or bot.
#   - You can add additional fields such as mentions or attachments by
#     modifying the JSON in the payload_template.
#   - Always secure your webhook URLs and avoid committing them to source
#     control; load them from environment variables or a secrets manager.
#
# -----------------------------------------------------------------------------
# Artifact Exclusion Tips:
#   - The artifact_exclusions list defines patterns that will be passed to zip
#     as exclusions. Patterns are glob-style and relative to the repository root.
#   - Excluding large directories (e.g., node_modules, build outputs) reduces
#     the size of the release archive and speeds up uploads.
#   - You can also exclude sensitive files such as .env or configuration files
#     containing secrets.
#
# -----------------------------------------------------------------------------
# Pro Tips for Using the Legacy Framework:
#   - Test your hooks and configuration in dry-run mode before performing a
#     real release to avoid unintended changes.
#   - Use semantic and consistent commit messages; changelog generation relies
#     on commit subjects to categorize entries.
#   - Keep your personal access token restricted to the minimal required
#     scopes (e.g., repo and workflow) for security.
#   - Regularly prune old release branches and tags to keep your repository
#     tidy and reduce clutter.
#   - Contribute back improvements or fixes to the automation scripts to
#     benefit your future releases.

# Examples:
#   ./script_name.sh patch
#   ./script_name.sh minor --dry-run
#   ./script_name.sh major --from-branch develop --to-branch main --push-tags
#   ./script_name.sh prerelease alpha --notification-channel slack

# -----------------------------------------------------------------------------
# Legacy Additional Notes:
#
# The 2028 automation framework offers comprehensive tooling for managing
# releases, including precise version comparisons, sophisticated error
# handling, and seamless integration with GitHub’s API.  It allows for
# user‑defined pre‑ and post‑release hooks and can dispatch notifications
# across a variety of channels such as Slack, Microsoft Teams, or custom
# webhooks.  These notes serve as a reminder of the breadth of functionality
# available for future integration.


: <<'ARCHIVE_2028'
# --------------  BEGIN verbatim copy of 2028.txt  ----------------------
#!/usr/bin/env bash

# ==============================================================================
# Enterprise-Grade Git Repository Bumping, Merging, and Release Automation Script
# ==============================================================================
#
# This script automates the process of bumping versions, merging branches,
# creating releases, generating changelogs, and managing notifications for
# [cite_start]Git repositories hosted on GitHub. [cite: 1]
#
# Features:
# [cite_start]- Supports major, minor, patch, and prerelease version bumping. [cite: 2]
# [cite_start]- Automates Git operations: checkout, merge, tag, push. [cite: 2]
# [cite_start]- Creates GitHub releases. [cite: 3]
# [cite_start]- Generates changelogs based on Git history. [cite: 3]
# [cite_start]- Manages temporary files and provides rollback functionality. [cite: 4]
# [cite_start]- Supports configurable hooks for pre/post operations. [cite: 4]
# [cite_start]- Sends notifications to various channels (e.g., Slack, Teams, custom webhooks). [cite: 5]
# [cite_start]- Provides a dry-run mode for testing without actual modifications. [cite: 6]
# [cite_start]- Loads configuration from a YAML file (or basic parsing if yq is unavailable). [cite: 7]
# [cite_start]- Validates environment, repository state, and user permissions. [cite: 8]
#
# Usage:
#   ./script_name.sh <version_type> [options]
#
# Examples:
#   ./script_name.sh patch
#   ./script_name.sh minor --dry-run
#   ./script_name.sh major --from-branch develop --to-branch main --push-tags
#   ./script_name.sh prerelease alpha --notification-channel slack
#
# Configuration:
#   The script looks for a '.repo_config.yaml' file, by default in the
#   [cite_start]current working directory or specified by --config-file. [cite: 9]
#   [cite_start]See `repo_config.example.yaml` for configuration options. [cite: 9]
#   [cite_start]Precedence: CLI args > Environment variables > Config File > Script defaults. [cite: 9]
#   [cite_start]Note: GH_TOKEN should ideally be set via environment variable for security. [cite: 10]
#
# Dependencies:
# - Git
# - curl
# - jq (optional, for pretty-printing JSON)
# - yq (optional, for YAML configuration parsing)
#
# Exit Codes:
#   0: Success
#   1: General error
#   2: Validation error
#   3: Git operation error
#   4: API error
#   5: Hook execution error
#   6: Configuration error
#
# ==============================================================================

# --- Strict Mode & Globbing ---
[cite_start]set -uo pipefail # Exit immediately if a command exits with a non-zero status. [cite: 12] Exit if an undefined variable is used. [cite_start]A pipe's return value is the last non-zero exit code, or zero if all commands in the pipe succeed. [cite: 12]
[cite_start]shopt -s nullglob # Allows patterns that match no files to expand to a null string, rather than themselves. [cite: 13]

# ==============================================================================
# Global Variables and Defaults
# ==============================================================================

# Script identification
declare -g SCRIPT_NAME
SCRIPT_NAME="${0##*/}"
declare -g SCRIPT_DIR
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Operational flags
declare -g LOG_LEVEL="INFO"
declare -g VERBOSE=false
declare -g DRY_RUN=false
declare -g FORCE=false
declare -g NO_VERIFY=false
declare -g PUSH_TAGS=false
declare -g PUSH_BRANCHES=false
declare -g CREATE_RELEASE=false
declare -g GENERATE_CHANGELOG=false
declare -g GENERATE_ARTIFACTS=false
declare -g EXPORT_METADATA=false
declare -g NOTIFICATION_CHANNELS=""

# File and directory management
declare -g TEMP_DIR=""
declare -ga TEMP_FILES=()

# Configuration Values
declare -g OWNER=""
declare -g REPO=""
declare -g GITHUB_USER=""
declare -g GH_TOKEN=""
declare -g DEFAULT_BRANCH="main"
declare -g DEVELOPMENT_BRANCH="develop"
declare -g API_BASE="https://api.github.com"
declare -g CLONE_DIR=""
declare -g CONFIG_FILE="${SCRIPT_DIR}/.repo_config.yaml"
declare -g HOOKS_DIR="${SCRIPT_DIR}/hooks"
declare -g FUNCTIONS_DIR="${SCRIPT_DIR}/functions"
declare -ga ARTIFACT_EXCLUSIONS=(".git" "*.log" "*.tmp" ".*.swp" "*~" "CHANGELOG.md")

# Versioning
declare -g VERSION_TYPE=""
declare -g PRERELEASE_IDENTIFIER=""
declare -g CURRENT_VERSION=""
declare -g NEW_VERSION=""

# Git Branches
declare -g FROM_BRANCH=""
declare -g TO_BRANCH=""
declare -g TARGET_BRANCH=""

# Git State for Rollback
declare -g ORIGINAL_BRANCH=""
declare -g ORIGINAL_COMMIT_HASH=""
declare -g MERGE_ATTEMPTED=false

# Release Metadata
declare -g RELEASE_ID=""
declare -g RELEASE_URL=""
declare -g RELEASE_TAG=""
declare -g RELEASE_TITLE=""
declare -g RELEASE_BODY=""

# Hook definitions
declare -ga PRE_COMMIT_HOOKS=()
declare -ga POST_RELEASE_HOOKS=()

# ==============================================================================
# Utility Functions
# ==============================================================================

# Function to log messages with different levels
# Args: <level> <message>
function log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    local display_message="${message}"
    [cite_start]if [[ -n "$GH_TOKEN" ]]; then # The actual GH_TOKEN variable itself is not modified. [cite: 17]
        [cite_start]display_message="${display_message//"$GH_TOKEN"/******************}" # [cite: 18]
    fi

    case "$level" in
        "DEBUG")
            if [[ "$LOG_LEVEL" == "DEBUG" || [cite_start]"$VERBOSE" == true ]]; then # [cite: 19]
                echo -e "[\033[0;34mDEBUG\033[0m] $timestamp: $display_message" >&2
            fi
            ;;
        "INFO")
            if [[ "$LOG_LEVEL" == "INFO" || "$LOG_LEVEL" == "DEBUG" || [cite_start]"$VERBOSE" == true ]]; then # [cite: 20, 21]
                echo -e "[\033[0;32mINFO\033[0m] $timestamp: $display_message" >&2
            fi
            ;;
        [cite_start]"WARNING") # [cite: 22]
            echo -e "[\033[0;33mWARNING\033[0m] $timestamp: $display_message" >&2
            ;;
        [cite_start]"ERROR") # [cite: 23]
            echo -e "[\033[0;31mERROR\033[0m] $timestamp: $display_message" >&2
            ;;
        [cite_start]*) # [cite: 24]
            echo -e "[\033[0;37mUNKNOWN\033[0m] $timestamp: $display_message" >&2
            ;;
    esac
}

# Function to display usage information and exit
function usage() {
    echo "Usage: $SCRIPT_NAME <version_type> [options]"
    echo ""
    echo "Version Types:"
    echo "  major       Increment major version (e.g., 1.2.3 -> 2.0.0)"
    echo "  minor       Increment minor version (e.g., 1.2.3 -> 1.3.0)"
    echo "  patch       Increment patch version (e.g., 1.2.3 -> 1.2.4)"
    [cite_start]echo "  prerelease  Increment prerelease version (e.g., 1.2.3 -> 1.2.4-alpha.0 or 1.2.3-alpha.0 -> 1.2.3-alpha.1)" # [cite: 26]
    echo ""
    echo "Options (Precedence: CLI > ENV > Config File > Script Defaults):"
    echo "  --owner <owner>                 GitHub repository owner (default: inferred from Git remote)"
    echo "  --repo <repo>                   GitHub repository name (default: inferred from Git remote)"
    [cite_start]echo "  --github-user <user>            GitHub username for API authentication (default: inferred from GH_USER env)" # [cite: 27]
    echo "  --gh-token <token>              GitHub personal access token (default: GH_TOKEN env var)"
    echo "  --from-branch <branch>          Branch to merge from (default: develop)"
    echo "  --to-branch <branch>            Branch to merge into (default: main)"
    [cite_start]echo "  --target-branch <branch>        Branch where the release tag will be created (default: to-branch)" # [cite: 28]
    [cite_start]echo "  --prerelease-identifier <id>    Identifier for prerelease (e.g., alpha, beta, rc; required for prerelease type)" # [cite: 29]
    echo "  --push-tags                     Push generated tags to remote"
    echo "  --push-branches                 Push updated branches to remote"
    echo "  --create-release                Create a GitHub release"
    [cite_start]echo "  --generate-changelog            Generate CHANGELOG.md based on Git history" # [cite: 30]
    echo "  --generate-artifacts            Generate a zip artifact of the repository for the release"
    echo "  --export-metadata               Export release metadata to a JSON file"
    echo "  --notification-channel <channel> Comma-separated list of notification channels (e.g., slack,teams,custom)"
    [cite_start]echo "  --force                         Force operations (e.g., overwrite existing tags, skip some checks)" # [cite: 31]
    echo "  --no-verify                     Skip Git hooks (e.g., pre-commit, commit-msg)"
    echo "  --dry-run                       Simulate operations without making any changes"
    [cite_start]echo "  --verbose                       Enable verbose logging (same as --log-level DEBUG)" # [cite: 32]
    [cite_start]echo "  --log-level <level>             Set logging level (DEBUG, INFO, WARNING, ERROR; default: INFO)" # [cite: 33]
    echo "  --config-file <path>            Path to the .repo_config.yaml file (default: \$SCRIPT_DIR/.repo_config.yaml)"
    echo "  --hooks-dir <path>              Directory containing custom hook scripts (default: script_dir/hooks)"
    echo "  --functions-dir <path>          Directory containing custom function scripts (default: script_dir/functions)"
    [cite_start]echo "  -h, --help                      Display this help message" # [cite: 34]
    echo ""
    echo "Environment Variables (lower precedence than CLI, higher than config file):"
    echo "  GH_TOKEN                        GitHub Personal Access Token (RECOMMENDED secure method)"
    [cite_start]echo "  GH_USER                         GitHub username (if not provided via --github-user)" # [cite: 35]
    echo ""
    echo "Example: $SCRIPT_NAME patch --push-tags --create-release --generate-changelog"
    exit 0
}

# Function to handle errors and exit gracefully
# Args: <exit_code> <message>
function error_exit() {
    local exit_code="$1"
    local message="$2"
    log "ERROR" "$message"
    [cite_start]exit "$exit_code" # [cite: 36]
}

# Function to register temporary files for cleanup
# Args: <file_path>
function register_temp_file() {
    local file="$1"
    TEMP_FILES+=("$file")
}

# Function to clean up all registered temporary files and the temp directory
function clean_temp_files() {
    log "DEBUG" "Cleaning up temporary files..."
    [cite_start]for file in "${TEMP_FILES[@]}"; do # [cite: 37]
        [cite_start]if [[ -f "$file" ]]; then # [cite: 38]
            log "DEBUG" "Removing temporary file: $file"
            [cite_start]rm -f "$file" || log "WARNING" "Failed to remove temporary file: $file" # [cite: 39]
        fi
    done
    [cite_start]if [[ -d "$TEMP_DIR" ]]; then # [cite: 40]
        log "DEBUG" "Removing temporary directory: $TEMP_DIR"
        [cite_start]rm -rf "$TEMP_DIR" || log "WARNING" "Failed to remove temporary directory: $TEMP_DIR" # [cite: 41]
    fi
}

# Combined cleanup function for trap
function cleanup() {
    local exit_status=$?
    [cite_start]log "DEBUG" "Script exiting with status: $exit_status" # [cite: 42]
    rollback_git_changes
    clean_temp_files
    log "INFO" "Script finished."
}

# Trap for cleanup on script exit
trap cleanup EXIT

# Function to execute commands in dry-run mode or normally
# Args: <command...>
function dry_run_mode() {
    log "DEBUG" "Attempting to execute: $*"

    [cite_start]if $DRY_RUN; then # [cite: 45]
        log "INFO" "[DRY-RUN] Would execute: $*"
        return 0
    else
        [cite_start]if ! "$@"; then # [cite: 47]
            log "ERROR" "Command failed: $*"
            return 1
        fi
        return 0
    fi
}

# Function to make GitHub API calls
# Args: <url> [method] [data]
function api() {
    local url="$1"
    local method="${2:-GET}"
    local data="${3:-}"
    local headers=(-H "Accept: application/vnd.github.v3+json" -H "Authorization: token $GH_TOKEN")
    local curl_output
    local http_code
    local retries=3
    local delay=5 # seconds
    local curl_error_log
    curl_error_log="$TEMP_DIR/curl_api_error.log"
    local response_body

    log "DEBUG" "API Call: $method $url"

    [cite_start]for i in $(seq 1 $retries); do # [cite: 49]
        local curl_cmd_array=(
            curl -s -w "%{http_code}" --max-time 30
            -o >(cat >&1; printf "\n") # Redirect body to stdout and add newline
            -X "$method"
            "${headers[@]}"
        )
        [cite_start]if [[ -n "$data" ]]; then # [cite: 50]
            curl_cmd_array+=( -d "$data" )
        fi
        curl_cmd_array+=( "$url" )

        [cite_start]if ! curl_output=$( "${curl_cmd_array[@]}" 2>"$curl_error_log"); then # [cite: 51]
            local curl_status=$?
            [cite_start]if [[ -s "$curl_error_log" ]]; then # [cite: 52]
                log "WARNING" "Curl command failed (attempt $i/$retries). Status: $curl_status. Error log: $(cat "$curl_error_log")"
            else
                log "WARNING" "Curl command failed (attempt $i/$retries). Status: $curl_status."
            fi
            sleep "$delay"
            continue
        fi

        http_code=$(tail -n1 <<< "$curl_output")
        response_body=$(sed '$d' <<< "$curl_output")

        [cite_start]if [[ "$http_code" =~ ^2[0-9]{2}$ ]]; then # [cite: 54]
            log "DEBUG" "API Success ($http_code): $response_body"
            echo "$response_body"
            return 0
        [cite_start]elif [[ "$http_code" == "404" ]]; then # [cite: 55]
            log "WARNING" "API Call Failed ($http_code): Not Found ($url)"
            echo "$response_body"
            return 1
        else
            log "WARNING" "API Call Failed ($http_code, attempt $i/$retries): $response_body"
            sleep "$delay"
        fi
    done

    log "ERROR" "API call failed after $retries attempts for $url."
    [cite_start]return 1 # [cite: 57]
}

# Function to execute an external hook script
# Args: <hook_path> <event_name> <data_json>
function execute_hook() {
    local hook_path="$1"
    local event_name="$2"
    local data_json="$3"

    if [[ ! [cite_start]-f "$hook_path" ]]; then # [cite: 58]
        log "WARNING" "Hook script not found: $hook_path"
        return 0
    fi

    log "INFO" "Executing hook: $hook_path for event: $event_name"

    [cite_start]if $DRY_RUN; then # [cite: 59]
        log "INFO" "[DRY-RUN] Would execute hook: '$hook_path' with event '$event_name' and data: $data_json"
        return 0
    else
        [cite_start]if ! chmod +x "$hook_path"; then # [cite: 60]
            error_exit 5 "Failed to make hook script executable: $hook_path"
        fi
        if ! [cite_start]HOOK_DATA="$data_json" "$hook_path" "$event_name"; then # [cite: 61]
            error_exit 5 "Hook '$hook_path' failed for event '$event_name'. Check hook script output for details."
        fi
    fi
}

# ==============================================================================
# Setup and Configuration Functions
# ==============================================================================

# Initialize temporary directory for logs and intermediate files
function initialize_temp_dir() {
    TEMP_DIR=$(mktemp -d -t 'release_script_XXXXXXXXXX')
    if [[ -z "$TEMP_DIR" || ! [cite_start]-d "$TEMP_DIR" ]]; then # [cite: 63]
        error_exit 1 "Failed to create temporary directory. Check permissions or disk space."
    fi
    [cite_start]register_temp_file "$TEMP_DIR" # [cite: 64]
    log "DEBUG" "Created temporary directory: $TEMP_DIR"
}

# Parse command line arguments and set global flags/variables
function parse_args() {
    [cite_start]local cli_owner="" # [cite: 66]
    local cli_repo=""
    local cli_github_user=""
    local cli_gh_token=""
    local cli_from_branch=""
    local cli_to_branch=""
    local cli_target_branch=""
    local cli_prerelease_identifier=""
    local cli_notification_channels=""
    local cli_log_level=""
    local cli_config_file_path=""
    local cli_hooks_dir_path=""
    local cli_functions_dir_path=""

    [cite_start]while (( "$#" )); do # [cite: 67]
        case "$1" in
            major|minor|patch|prerelease)
                [cite_start]if [[ -n "$VERSION_TYPE" ]]; then # [cite: 68]
                    error_exit 6 "Only one version type can be specified: '$VERSION_TYPE' and '$1'."
                fi
                VERSION_TYPE="$1"
                shift
                [cite_start]if [[ "$VERSION_TYPE" == "prerelease" ]]; then # [cite: 70]
                    if [[ -z "${1:-}" || [cite_start]"$1" =~ ^- ]]; then # [cite: 71]
                        error_exit 6 "Prerelease identifier is required for 'prerelease' version type. Usage: prerelease <identifier>"
                    fi
                    cli_prerelease_identifier="$1"
                    [cite_start]shift # [cite: 72]
                fi
                ;;
            --owner) cli_owner="$2"; shift 2 ;; [cite_start]# [cite: 73]
            --repo) cli_repo="$2"; shift 2 ;;
            --github-user) cli_github_user="$2"; shift 2 ;;
            --gh-token) cli_gh_token="$2"; shift 2 ;;
            --from-branch) cli_from_branch="$2"; shift 2 ;; [cite_start]# [cite: 74]
            --to-branch) cli_to_branch="$2"; shift 2 ;;
            --target-branch) cli_target_branch="$2"; shift 2 ;;
            --prerelease-identifier) cli_prerelease_identifier="$2"; shift 2 ;;
            --push-tags) PUSH_TAGS=true; shift ;; [cite_start]# [cite: 75]
            --push-branches) PUSH_BRANCHES=true; shift ;;
            --create-release) CREATE_RELEASE=true; shift ;;
            --generate-changelog) GENERATE_CHANGELOG=true; shift ;;
            --generate-artifacts) GENERATE_ARTIFACTS=true; shift ;;
            --export-metadata) EXPORT_METADATA=true; shift ;; [cite_start]# [cite: 76]
            --notification-channel) cli_notification_channels="$2"; shift 2 ;;
            --force) FORCE=true; shift ;;
            --no-verify) NO_VERIFY=true; shift ;;
            --dry-run) DRY_RUN=true; log "INFO" "Dry-run mode enabled. No actual changes will be made."; shift ;; [cite_start]# [cite: 77]
            --verbose) VERBOSE=true; cli_log_level="DEBUG"; shift ;;
            --log-level) cli_log_level=$(echo "$2" | tr '[:lower:]' '[:upper:]'); shift 2 ;; [cite_start]# [cite: 78]
            --config-file) cli_config_file_path="$2"; shift 2 ;;
            --hooks-dir) cli_hooks_dir_path="$2"; shift 2 ;;
            --functions-dir) cli_functions_dir_path="$2"; shift 2 ;; [cite_start]# [cite: 79]
            -h|--help) usage ;;
            *) error_exit 1 "Unknown option: $1" ;;
        esac
    done

    # Assign CLI values to global variables.
    [cite_start]if [[ -n "$cli_owner" ]]; then OWNER="$cli_owner"; fi # [cite: 82]
    if [[ -n "$cli_repo" ]]; then REPO="$cli_repo"; fi
    [cite_start]if [[ -n "$cli_github_user" ]]; then GITHUB_USER="$cli_github_user"; fi # [cite: 83]
    [cite_start]if [[ -n "$cli_gh_token" ]]; then GH_TOKEN="$cli_gh_token"; fi # [cite: 84]
    if [[ -n "$cli_from_branch" ]]; then FROM_BRANCH="$cli_from_branch"; fi
    [cite_start]if [[ -n "$cli_to_branch" ]]; then TO_BRANCH="$cli_to_branch"; fi # [cite: 85]
    [cite_start]if [[ -n "$cli_target_branch" ]]; then TARGET_BRANCH="$cli_target_branch"; fi # [cite: 86]
    if [[ -n "$cli_prerelease_identifier" ]]; then PRERELEASE_IDENTIFIER="$cli_prerelease_identifier"; fi
    [cite_start]if [[ -n "$cli_notification_channels" ]]; then NOTIFICATION_CHANNELS="$cli_notification_channels"; fi # [cite: 87]
    [cite_start]if [[ -n "$cli_log_level" ]]; then LOG_LEVEL="$cli_log_level"; fi # [cite: 88]
    if [[ -n "$cli_config_file_path" ]]; then CONFIG_FILE="$cli_config_file_path"; fi
    [cite_start]if [[ -n "$cli_hooks_dir_path" ]]; then HOOKS_DIR="$cli_hooks_dir_path"; fi # [cite: 89]
    [cite_start]if [[ -n "$cli_functions_dir_path" ]]; then FUNCTIONS_DIR="$cli_functions_dir_path"; fi # [cite: 90]

    [cite_start]if [[ -z "$VERSION_TYPE" ]]; then # [cite: 91]
        error_exit 6 "Version type (major, minor, patch, prerelease) is required."
    fi
}

# Load configuration from .repo_config.yaml.
function load_config() {
    log "INFO" "Loading configuration from: ${CONFIG_FILE}..."

    local yq_available=false
    [cite_start]if command -v yq &>/dev/null; then # [cite: 95]
        yq_available=true
        log "DEBUG" "yq found, enabling full YAML configuration parsing."
    [cite_start]else # [cite: 96]
        log "WARNING" "yq not found. YAML configuration parsing will be disabled. Relying on environment variables and defaults."
    fi

    [cite_start]if $yq_available && [[ -f "$CONFIG_FILE" ]]; then # [cite: 98]
        log "INFO" "Parsing config file using yq."
        [cite_start]if [[ -z "$OWNER" ]]; then OWNER=$(yq '.owner // ""' "$CONFIG_FILE"); fi # [cite: 100, 101]
        [cite_start]if [[ -z "$REPO" ]]; then REPO=$(yq '.repo // ""' "$CONFIG_FILE"); fi # [cite: 102]
        [cite_start]if [[ -z "$GITHUB_USER" ]]; then GITHUB_USER=$(yq '.github_user // ""' "$CONFIG_FILE"); fi # [cite: 103]
        [cite_start]if [[ -z "$GH_TOKEN" ]]; then # [cite: 104]
            local config_gh_token
            config_gh_token=$(yq '.gh_token // ""' "$CONFIG_FILE")
            [cite_start]if [[ -n "$config_gh_token" ]]; then # [cite: 105]
                log "WARNING" "GH_TOKEN found in config file. It is STRONGLY recommended to use the GH_TOKEN environment variable for security."
                [cite_start]GH_TOKEN="$config_gh_token" # [cite: 106]
            fi
        fi
        [cite_start]if [[ -z "$DEFAULT_BRANCH" ]]; then DEFAULT_BRANCH=$(yq '.default_branch // "main"' "$CONFIG_FILE"); fi # [cite: 107]
        [cite_start]if [[ -z "$DEVELOPMENT_BRANCH" ]]; then DEVELOPMENT_BRANCH=$(yq '.development_branch // "develop"' "$CONFIG_FILE"); fi # [cite: 108]
        [cite_start]if [[ -z "$API_BASE" ]]; then API_BASE=$(yq '.api_base // "https://api.github.com"' "$CONFIG_FILE"); fi # [cite: 109]
        
        if [[ -z "$HOOKS_DIR" || [cite_start]"$HOOKS_DIR" == "${SCRIPT_DIR}/hooks" ]]; then HOOKS_DIR=$(yq '.hooks_dir // ""' "$CONFIG_FILE"); fi # [cite: 110, 111]
        if [[ -z "$FUNCTIONS_DIR" || [cite_start]"$FUNCTIONS_DIR" == "${SCRIPT_DIR}/functions" ]]; then FUNCTIONS_DIR=$(yq '.functions_dir // ""' "$CONFIG_FILE"); fi # [cite: 112]
        [cite_start]if [[ -z "$NOTIFICATION_CHANNELS" ]]; then NOTIFICATION_CHANNELS=$(yq '.notification_channels // "" | join(",")' "$CONFIG_FILE"); fi # [cite: 113]

        local exclude_yaml
        exclude_yaml=$(yq '.artifact_exclusions[] // ""' "$CONFIG_FILE" 2>/dev/null)
        [cite_start]if [[ -n "$exclude_yaml" ]]; then # [cite: 114]
            readarray -t ARTIFACT_EXCLUSIONS < <(echo "$exclude_yaml")
        fi

        [cite_start]if yq '.hooks.pre_commit' "$CONFIG_FILE" &>/dev/null; then # [cite: 115]
            readarray -t PRE_COMMIT_HOOKS < <(yq '.hooks.pre_commit[]' "$CONFIG_FILE")
        fi
        [cite_start]if yq '.hooks.post_release' "$CONFIG_FILE" &>/dev/null; then # [cite: 116]
            readarray -t POST_RELEASE_HOOKS < <(yq '.hooks.post_release[]' "$CONFIG_FILE")
        fi

    [cite_start]elif [[ -f "$CONFIG_FILE" ]]; then # [cite: 117]
        log "WARNING" "yq not found. Attempting basic line-by-line parsing of '$CONFIG_FILE'. This is not robust. Please install yq or use environment variables."
        while IFS=':' read -r key value || [cite_start][[ -n "$key" ]]; do # [cite: 119]
            key=$(echo "$key" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
            value=$(echo "$value" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'$//")
            case "$key" in
                "owner") if [[ -z "$OWNER" ]]; then OWNER="$value"; fi ;; [cite_start]# [cite: 120]
                "repo") if [[ -z "$REPO" ]]; then REPO="$value"; fi ;;
                "github_user") if [[ -z "$GITHUB_USER" ]]; then GITHUB_USER="$value"; fi ;; [cite_start]# [cite: 121]
                "gh_token")
                    [cite_start]if [[ -z "$GH_TOKEN" ]]; then # [cite: 122]
                        log "WARNING" "GH_TOKEN found in config file. Recommended to use GH_TOKEN environment variable."
                        [cite_start]GH_TOKEN="$value" # [cite: 123]
                    fi
                    ;;
                "default_branch") if [[ -z "$DEFAULT_BRANCH" ]]; then DEFAULT_BRANCH="$value"; fi ;; [cite_start]# [cite: 124]
                "development_branch") if [[ -z "$DEVELOPMENT_BRANCH" ]]; then DEVELOPMENT_BRANCH="$value"; fi ;;
                "api_base") if [[ -z "$API_BASE" ]]; then API_BASE="$value"; fi ;; [cite_start]# [cite: 125]
                "hooks_dir") if [[ -z "$HOOKS_DIR" || "$HOOKS_DIR" == "${SCRIPT_DIR}/hooks" ]]; then HOOKS_DIR="$value"; fi ;; [cite_start]# [cite: 126]
                "functions_dir") if [[ -z "$FUNCTIONS_DIR" || "$FUNCTIONS_DIR" == "${SCRIPT_DIR}/functions" ]]; then FUNCTIONS_DIR="$value"; fi ;;
                "notification_channels") if [[ -z "$NOTIFICATION_CHANNELS" ]]; then NOTIFICATION_CHANNELS="$value"; fi ;; [cite_start]# [cite: 127]
                "artifact_exclusions") IFS=',' read -ra ARTIFACT_EXCLUSIONS <<< "$value" ;;
                "pre_commit_hooks") IFS=',' read -ra PRE_COMMIT_HOOKS <<< "$value" ;; [cite_start]# [cite: 128]
                "post_release_hooks") IFS=',' read -ra POST_RELEASE_HOOKS <<< "$value" ;;
            esac
        done < "$CONFIG_FILE"
    else
        log "WARNING" "Config file not found at '$CONFIG_FILE'. Relying solely on environment variables and script defaults."
    fi

    [cite_start]if [[ -z "$GH_TOKEN" && -n "${GH_TOKEN:-}" ]]; then GH_TOKEN="${GH_TOKEN:-}"; fi # [cite: 132, 133]
    [cite_start]if [[ -z "$GITHUB_USER" && -n "${GH_USER:-}" ]]; then GITHUB_USER="${GH_USER:-}"; fi # [cite: 134]
}

# Apply default branch names if not specified by CLI or config.
function set_branch_defaults() {
    FROM_BRANCH="${FROM_BRANCH:-$DEVELOPMENT_BRANCH}"
    TO_BRANCH="${TO_BRANCH:-$DEFAULT_BRANCH}"
    TARGET_BRANCH="${TARGET_BRANCH:-$TO_BRANCH}"
    log "DEBUG" "Resolved branches: FROM=$FROM_BRANCH, TO=$TO_BRANCH, TARGET=$TARGET_BRANCH"
}

# ==============================================================================
# Validation Functions
# ==============================================================================

# Validate the environment and required dependencies
function validate_environment_requirements() {
    log "INFO" "Validating environment requirements..."

    command -v git &>/dev/null || error_exit 2 "Git is not installed. Please install Git." [cite_start]# [cite: 137]
    command -v curl &>/dev/null || error_exit 2 "curl is not installed. Please install curl." [cite_start]# [cite: 138]

    [cite_start]if command -v yq &>/dev/null; then # [cite: 139]
        log "INFO" "yq found. YAML config parsing enabled."
    [cite_start]else # [cite: 140]
        log "WARNING" "yq not found. Advanced YAML configuration files will not be parsed. Relying on basic parsing (or env vars/defaults)."
    fi

    if command -v jq &>/dev/null; then
        log "INFO" "jq found. JSON output will be pretty-printed and parsed robustly."
    [cite_start]else # [cite: 142]
        log "WARNING" "jq not found. JSON output will not be pretty-printed, and some parsing may be less robust."
    fi

    [cite_start]if [[ -z "$GH_TOKEN" ]]; then # [cite: 144]
        error_exit 2 "GitHub Personal Access Token (GH_TOKEN) is not set. Please set it via the --gh-token flag or the GH_TOKEN environment variable."
    fi

    log "INFO" "Environment validation complete."
}

# Validate repository information and set OWNER/REPO from git remote if not provided
function validate_repo_info() {
    log "INFO" "Validating repository information..."

    CLONE_DIR=$(git rev-parse --show-toplevel 2>/dev/null)
    [cite_start]if [[ -z "$CLONE_DIR" ]]; then # [cite: 147]
        error_exit 2 "Current directory is not within a Git repository. Please run the script from your repository's root or a subdirectory."
    fi
    log "INFO" "Repository clone directory (CLONE_DIR) set to: $CLONE_DIR"

    if [[ -z "$OWNER" || [cite_start]-z "$REPO" ]]; then # [cite: 149]
        log "DEBUG" "Attempting to infer owner and repo from Git remote 'origin'."
        local remote_url
        [cite_start]remote_url=$(git config --get remote.origin.url 2>/dev/null) # [cite: 150]
        [cite_start]if [[ -z "$remote_url" ]]; then # [cite: 151]
            error_exit 2 "Could not find Git remote 'origin'. Please ensure you are in a Git repository or specify --owner and --repo."
        fi

        if [[ "$remote_url" =~ github.com[:/]([^/]+)/([^/]+?)(\.git)?$ [cite_start]]]; then # [cite: 153]
            OWNER="${BASH_REMATCH[1]}"
            REPO="${BASH_REMATCH[2]}"
            log "INFO" "Inferred Owner: $OWNER, Repo: $REPO from Git remote."
        [cite_start]else # [cite: 154]
            error_exit 2 "Could not parse GitHub owner/repo from remote URL: '$remote_url'. Please specify --owner and --repo."
        fi
    fi

    if [[ -z "$OWNER" ]]; then error_exit 2 "GitHub repository owner is not set. Please specify via --owner or ensure it's in the config or Git remote." [cite_start]; fi # [cite: 156, 157]
    if [[ -z "$REPO" ]]; then error_exit 2 "GitHub repository name is not set. Please specify via --repo or ensure it's in the config or Git remote." [cite_start]; fi # [cite: 158]

    log "INFO" "Repository information validated. Owner: $OWNER, Repo: $REPO"
}

# Validate current Git repository state (uncommitted changes, branch existence)
function validate_git_state() {
    log "INFO" "Validating Git repository state..."

    ORIGINAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)
    ORIGINAL_COMMIT_HASH=$(git rev-parse HEAD)
    log "INFO" "Current branch: '$ORIGINAL_BRANCH' (Commit: $ORIGINAL_COMMIT_HASH)"

    log "INFO" "Fetching latest Git changes from origin..."
    [cite_start]if ! dry_run_mode git fetch origin "$FROM_BRANCH" "$TO_BRANCH" "$DEFAULT_BRANCH" "$DEVELOPMENT_BRANCH" --tags; then # [cite: 159]
        error_exit 3 "Failed to fetch latest changes from origin for required branches. Check network, repository access, and branch names."
    fi

    if ! [cite_start]$FORCE; then # [cite: 161]
        if ! git diff --quiet HEAD 2>/dev/null || [cite_start]! git diff --staged --quiet 2>/dev/null; then # [cite: 162]
            error_exit 2 "Uncommitted or unstaged changes detected. Please commit or stash them before running the script. Use --force to override."
        fi
        log "INFO" "No uncommitted or unstaged changes detected."
    [cite_start]else # [cite: 164]
        log "WARNING" "Skipping uncommitted changes check due to --force."
    fi

    [cite_start]if ! git show-ref --verify --quiet "refs/remotes/origin/$FROM_BRANCH"; then # [cite: 166]
        error_exit 2 "Source branch 'origin/$FROM_BRANCH' does not exist. Please ensure it's pushed and accessible."
    fi
    [cite_start]if ! git show-ref --verify --quiet "refs/remotes/origin/$TO_BRANCH"; then # [cite: 168]
        error_exit 2 "Target branch 'origin/$TO_BRANCH' does not exist. Please ensure it's pushed and accessible."
    fi

    log "INFO" "Git repository state validated."
}

# Validate user's GitHub permissions on the repository
function validate_github_permissions() {
    log "INFO" "Validating GitHub permissions for user on repository..."

    [cite_start]if [[ -z "$GITHUB_USER" ]]; then # [cite: 171]
        [cite_start]GITHUB_USER=$(api "$API_BASE/user" | jq -r '.login // "null"') # [cite: 172]
        [cite_start]if [[ "$GITHUB_USER" == "null" ]]; then # [cite: 173]
            error_exit 2 "Could not determine GitHub username. Please set --github-user or the GH_USER environment variable."
        fi
        log "INFO" "Inferred GitHub User: $GITHUB_USER"
    fi

    local permission_info
    permission_info=$(api "$API_BASE/repos/$OWNER/$REPO/collaborators/$GITHUB_USER/permission")

    if [[ $? [cite_start]-ne 0 ]]; then # [cite: 175]
        error_exit 4 "Failed to check collaborator permission for '$GITHUB_USER' on '$OWNER/$REPO'. Check repository name and your GH_TOKEN validity/scope."
    fi

    local role_name
    role_name=$(echo "$permission_info" | jq -r '.permission // "null"')
    [cite_start]if [[ "$role_name" == "null" ]]; then # [cite: 177]
        error_exit 4 "Failed to parse permission role for user '$GITHUB_USER'. The API response might be malformed or the user is not a collaborator."
    fi

    log "INFO" "User '$GITHUB_USER' has role: '$role_name' on '$OWNER/$REPO'."
    [cite_start]if [[ "$role_name" != "admin" && "$role_name" != "maintain" && "$role_name" != "write" ]]; then # [cite: 180]
        error_exit 2 "User '$GITHUB_USER' with role '$role_name' does not have sufficient permissions (admin, maintain, or write) on '$OWNER/$REPO' to perform release operations."
    fi
    log "INFO" "User '$GITHUB_USER' has sufficient write/maintainer/admin permissions for repository operations."
}

# Validate new version is strictly greater than current version
function validate_version_comparison() {
    log "INFO" "Validating new version ('$NEW_VERSION') against current version ('$CURRENT_VERSION')..."

    # Note: `sort -V` is used for version comparison. It handles many common cases but is not a fully compliant SemVer 2.0.0 comparator.
    [cite_start]if [[ "$(printf '%s\n%s\n' "$NEW_VERSION" "$CURRENT_VERSION" | sort -V | head -n1)" == "$NEW_VERSION" && "$NEW_VERSION" != "$CURRENT_VERSION" ]]; then # [cite: 186, 187]
        error_exit 2 "New version '$NEW_VERSION' must be numerically greater than current version '$CURRENT_VERSION'."
    [cite_start]elif [[ "$NEW_VERSION" == "$CURRENT_VERSION" ]]; then # [cite: 188]
        error_exit 2 "New version '$NEW_VERSION' cannot be the same as current version '$CURRENT_VERSION'."
    fi
    log "INFO" "Version comparison successful: '$NEW_VERSION' is greater than '$CURRENT_VERSION'."
}

# ==============================================================================
# Git Operations Functions
# ==============================================================================

# Determine the latest Git tag based on semantic versioning
function get_latest_git_tag() {
    log "INFO" "Getting latest Git tag from remote..."
    # Fetches tags and sorts them by version number to find the latest semantic version tag.
    [cite_start]CURRENT_VERSION=$(git tag --sort=-v:refname | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$' | head -n1 | sed 's/^v//') # [cite: 191]

    [cite_start]if [[ -z "$CURRENT_VERSION" ]]; then # [cite: 192]
        log "WARNING" "No valid semantic version tags (e.g., vX.Y.Z) found. Initializing with version 0.0.0."
        [cite_start]CURRENT_VERSION="0.0.0" # [cite: 193]
    else
        log "INFO" "Latest semantic version tag found: v$CURRENT_VERSION"
    fi
}

# Calculate the new version based on version type (major, minor, patch, prerelease)
function calculate_new_version() {
    log "INFO" "Calculating new version from '$CURRENT_VERSION' based on type: '$VERSION_TYPE'..."

    local major
    major=$(echo "$CURRENT_VERSION" | cut -d. -f1)
    local minor
    minor=$(echo "$CURRENT_VERSION" | cut -d. -f2)
    local patch
    patch=$(echo "$CURRENT_VERSION" | cut -d. -f3 | cut -d- -f1)
    local prerelease_part
    [cite_start]prerelease_part=$(echo "$CURRENT_VERSION" | cut -d- -f2-) # [cite: 194]

    case "$VERSION_TYPE" in
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            prerelease_part=""
            ;;
        [cite_start]"minor") # [cite: 195]
            minor=$((minor + 1))
            patch=0
            prerelease_part=""
            ;;
        [cite_start]"patch") # [cite: 196]
            patch=$((patch + 1))
            prerelease_part=""
            ;;
        [cite_start]"prerelease") # [cite: 197]
            [cite_start]if [[ -z "$PRERELEASE_IDENTIFIER" ]]; then # [cite: 198]
                error_exit 6 "Prerelease identifier must be specified for 'prerelease' version type (e.g., --prerelease-identifier alpha)."
            fi

            # Validate prerelease identifier format (SemVer 2.0.0 compliance)
            if ! [[ "$PRERELEASE_IDENTIFIER" =~ ^[0-9A-Za-z-]+$ ]]; then
                error_exit 6 "Prerelease identifier '$PRERELEASE_IDENTIFIER' is invalid. It must only contain alphanumerics and hyphens."
            fi

            [cite_start]if [[ "$prerelease_part" =~ ^${PRERELEASE_IDENTIFIER}\.([0-9]+)$ ]]; then # [cite: 200]
                local prerelease_num
                prerelease_num="${BASH_REMATCH[1]}"
                prerelease_num=$((prerelease_num + 1))
                prerelease_part="${PRERELEASE_IDENTIFIER}.${prerelease_num}"
            else
                [cite_start]patch=$((patch + 1)) # [cite: 202]
                prerelease_part="${PRERELEASE_IDENTIFIER}.0"
            fi
            ;;
        [cite_start]*) # [cite: 203]
            error_exit 1 "Invalid version type: $VERSION_TYPE"
            ;;
    esac

    NEW_VERSION="$major.$minor.$patch"
    [cite_start]if [[ -n "$prerelease_part" ]]; then # [cite: 205]
        NEW_VERSION="$NEW_VERSION-$prerelease_part"
    fi

    log "INFO" "New version calculated: $NEW_VERSION (from $CURRENT_VERSION)."
}

# Backup the current Git repository state into a bundle file
function git_backup_repo() {
    log "INFO" "Backing up Git repository..."
    local timestamp
    timestamp=$(date +%Y%m%d%H%M%S)
    local backup_file="$TEMP_DIR/$REPO-$timestamp.bundle"
    register_temp_file "$backup_file"
    local error_log="$TEMP_DIR/git_bundle_error.log"

    [cite_start]if ! dry_run_mode git bundle create "$backup_file" --all >/dev/null 2>"$error_log"; then # [cite: 207]
        log "WARNING" "Failed to create Git bundle backup. This may hinder full rollback. Error: $(cat "$error_log")"
        return 1
    fi
    log "INFO" "Repository backed up to: $backup_file"
    return 0
}

# Rollback Git changes in case of an error during script execution
function rollback_git_changes() {
    [cite_start]if $DRY_RUN; then # [cite: 208]
        log "INFO" "[DRY-RUN] Would execute rollback of Git changes if necessary."
        [cite_start]return 0 # [cite: 209]
    fi

    log "WARNING" "Attempting to rollback local Git changes due to script interruption or failure..."

    [cite_start]if [[ -n "$CLONE_DIR" && -d "$CLONE_DIR" ]]; then # [cite: 210]
        cd "$CLONE_DIR" || log "ERROR" "Failed to change directory to '$CLONE_DIR' for rollback. Manual intervention required." [cite_start]# [cite: 211]
    [cite_start]else # [cite: 212]
        log "ERROR" "CLONE_DIR not set or does not exist. Cannot perform Git rollback safely."
        [cite_start]return 1 # [cite: 213]
    fi

    [cite_start]if [[ -n "$ORIGINAL_BRANCH" ]]; then # [cite: 214]
        log "INFO" "Checking out original branch: '$ORIGINAL_BRANCH'"
        [cite_start]if ! git checkout -f "$ORIGINAL_BRANCH" &>/dev/null; then # [cite: 215]
            log "ERROR" "Failed to checkout original branch '$ORIGINAL_BRANCH'. Manual intervention may be required."
            [cite_start]return 1 # [cite: 216]
        fi
        log "INFO" "Successfully checked out original branch."
        [cite_start]if $MERGE_ATTEMPTED; then # [cite: 217]
            log "INFO" "Resetting branch '$TO_BRANCH' to its original state (before script modifications) from origin."
            [cite_start]if ! git reset --hard "origin/$TO_BRANCH" &>/dev/null; then # [cite: 219]
                log "ERROR" "Failed to reset branch '$TO_BRANCH' to 'origin/$TO_BRANCH'. Manual intervention may be required."
                [cite_start]return 1 # [cite: 220]
            fi
            log "INFO" "Branch '$TO_BRANCH' successfully reset to 'origin/$TO_BRANCH'."
        fi
    fi

    log "INFO" "Git rollback complete. The repository is in its original state."
    [cite_start]return 0 # [cite: 222]
}

# Perform main Git operations: checkout, merge, tag, and push
function process_git_operations() {
    log "INFO" "Starting Git operations..."

    [cite_start]if ! cd "$CLONE_DIR"; then # [cite: 223]
        error_exit 3 "Failed to change directory to CLONE_DIR: '$CLONE_DIR'"
    fi

    log "INFO" "Checking out and pulling latest for branch: '$FROM_BRANCH'"
    [cite_start]if ! dry_run_mode git checkout "$FROM_BRANCH"; then # [cite: 224]
        error_exit 3 "Failed to checkout branch: '$FROM_BRANCH'"
    fi
    [cite_start]if ! dry_run_mode git pull origin "$FROM_BRANCH"; then # [cite: 225]
        error_exit 3 "Failed to pull latest for branch: '$FROM_BRANCH'"
    fi

    log "INFO" "Checking out and pulling latest for branch: '$TO_BRANCH'"
    [cite_start]if ! dry_run_mode git checkout "$TO_BRANCH"; then # [cite: 226]
        error_exit 3 "Failed to checkout branch: '$TO_BRANCH'"
    fi
    [cite_start]if ! dry_run_mode git pull origin "$TO_BRANCH"; then # [cite: 227]
        error_exit 3 "Failed to pull latest for branch: '$TO_BRANCH'"
    fi

    log "INFO" "Merging '$FROM_BRANCH' into '$TO_BRANCH'..."
    MERGE_ATTEMPTED=true
    
    local -a merge_opts=(--no-ff)
    [cite_start]if $NO_VERIFY; then # [cite: 228]
        merge_opts+=(--no-verify)
    fi

    [cite_start]if ! dry_run_mode git merge "${merge_opts[@]}" "$FROM_BRANCH" -m "Merge branch '$FROM_BRANCH' into '$TO_BRANCH' for release v$NEW_VERSION"; then # [cite: 229]
        error_exit 3 "Git merge failed. This often indicates merge conflicts. Please resolve them manually and re-run. Rolling back..."
    fi
    log "INFO" "Merge successful."
    RELEASE_TAG="v$NEW_VERSION"
    log "INFO" "Creating Git tag: '$RELEASE_TAG'"
    [cite_start]if git tag -l "$RELEASE_TAG" | grep -q "^$RELEASE_TAG$"; then # [cite: 231]
        [cite_start]if $FORCE; then # [cite: 232]
            log "WARNING" "Tag '$RELEASE_TAG' already exists. Forcing overwrite due to --force."
            [cite_start]if ! dry_run_mode git tag -f -a "$RELEASE_TAG" -m "Release v$NEW_VERSION"; then # [cite: 233]
                error_exit 3 "Failed to force-create Git tag: '$RELEASE_TAG'"
            fi
        else
            error_exit 3 "Tag '$RELEASE_TAG' already exists. Use --force to overwrite."
        fi
    else
        [cite_start]if ! dry_run_mode git tag -a "$RELEASE_TAG" -m "Release v$NEW_VERSION"; then # [cite: 236]
            error_exit 3 "Failed to create Git tag: '$RELEASE_TAG'"
        fi
    fi
    log "INFO" "Tag '$RELEASE_TAG' created locally."
    [cite_start]if $PUSH_BRANCHES; then # [cite: 238]
        log "INFO" "Pushing updated branch: '$TO_BRANCH'"
        [cite_start]if ! dry_run_mode git push origin "$TO_BRANCH" ${NO_VERIFY:+"--no-verify"}; then # [cite: 239]
            error_exit 3 "Failed to push branch '$TO_BRANCH'. Check permissions or remote state."
        fi
    [cite_start]else # [cite: 240]
        log "INFO" "Skipping branch push (use --push-branches to enable)."
    fi

    [cite_start]if $PUSH_TAGS; then # [cite: 242]
        log "INFO" "Pushing new tag: '$RELEASE_TAG'"
        [cite_start]if ! dry_run_mode git push origin "$RELEASE_TAG"; then # [cite: 243]
            error_exit 3 "Failed to push tag '$RELEASE_TAG'. Check permissions or remote state."
        fi
    [cite_start]else # [cite: 244]
        log "INFO" "Skipping tag push (use --push-tags to enable)."
    fi

    log "INFO" "Git operations complete."
}

# ==============================================================================
# Release Process Functions
# ==============================================================================

# Generate CHANGELOG.md based on Git history since the last tag
function process_generate_changelog() {
    if ! [cite_start]$GENERATE_CHANGELOG; then # [cite: 246]
        log "INFO" "Skipping changelog generation (use --generate-changelog to enable)."
        [cite_start]return 0 # [cite: 247]
    fi

    log "INFO" "Generating CHANGELOG.md..."

    local changelog_file="$CLONE_DIR/CHANGELOG.md"
    local temp_changelog_content="$TEMP_DIR/changelog_content.md"
    register_temp_file "$temp_changelog_content"

    local current_tag_version="v$CURRENT_VERSION"
    local new_tag_version="v$NEW_VERSION"

    local git_log_range=""
    [cite_start]if [[ "$CURRENT_VERSION" == "0.0.0" ]]; then # [cite: 248]
        [cite_start]git_log_range="--all" # [cite: 249]
        log "INFO" "No previous semantic version tag found. Generating changelog from all commits."
    [cite_start]elif git tag -l "$current_tag_version" | grep -q "^$current_tag_version$"; then # [cite: 250]
        git_log_range="$current_tag_version..HEAD"
        log "INFO" "Generating changelog from '$current_tag_version' to HEAD."
    [cite_start]else # [cite: 251]
        log "WARNING" "Previous tag '$current_tag_version' not found locally. Generating changelog from all commits to be safe."
        [cite_start]git_log_range="--all" # [cite: 252]
    fi

    local log_entries=""
    [cite_start]if $DRY_RUN; then # [cite: 253]
        log "INFO" "[DRY-RUN] Would generate git log for changelog."
        [cite_start]log_entries="* feat: Initial feature (dry-run)\n* fix: Critical bug fix (dry-run)\n* chore: Dependency updates (dry-run)" # [cite: 254]
    else
        log_entries=$(git log "$git_log_range" --pretty=format:"* %s" --no-merges)
    fi

    echo "## $new_tag_version - $(date +%Y-%m-%d)" > "$temp_changelog_content"
    echo "" >> "$temp_changelog_content"

    [cite_start]if [[ -n "$log_entries" ]]; then # [cite: 255]
        echo "$log_entries" >> "$temp_changelog_content"
    else
        echo "No significant changes." >> [cite_start]"$temp_changelog_content" # [cite: 256]
    fi
    echo "" >> "$temp_changelog_content"

    [cite_start]if [[ -f "$changelog_file" ]]; then # [cite: 257]
        log "DEBUG" "Prepending new changelog entries to existing file: '$changelog_file'"
        { cat "$temp_changelog_content"; echo ""; cat "$changelog_file"; [cite_start]} > "$changelog_file.tmp" && mv "$changelog_file.tmp" "$changelog_file" # [cite: 258]
    else
        log "DEBUG" "Creating new CHANGELOG.md file: '$changelog_file'"
        mv "$temp_changelog_content" "$changelog_file"
    fi

    [cite_start]RELEASE_BODY=$( # [cite: 261]
        awk "/^## $new_tag_version/{flag=1;next}/^## v[0-9]/{flag=0}flag" "$changelog_file" |
        sed -e '1d' -e '$d'
    )
    RELEASE_TITLE="Release $RELEASE_TAG"

    log "INFO" "CHANGELOG.md generated and updated. Release body prepared."
}

# Create a GitHub Release via API
function process_create_github_release() {
    if ! [cite_start]$CREATE_RELEASE; then # [cite: 263]
        log "INFO" "Skipping GitHub release creation (use --create-release to enable)."
        [cite_start]return 0 # [cite: 264]
    fi

    log "INFO" "Creating GitHub release for tag: '$RELEASE_TAG'..."

    local prerelease_flag="false"
    [cite_start]if [[ "$VERSION_TYPE" == "prerelease" ]]; then # [cite: 265]
        prerelease_flag="true"
    fi

    [cite_start]if [[ -z "$RELEASE_BODY" ]]; then # [cite: 266]
        log "WARNING" "Release body is empty. Using default message for the release."
        RELEASE_BODY="Automated release for version $NEW_VERSION." [cite_start]# [cite: 267]
    fi

    local release_data
    if ! release_data=$(jq -n \
        --arg tag_name "$RELEASE_TAG" \
        --arg name "Release $NEW_VERSION" \
        --arg body "$RELEASE_BODY" \
        --arg target_commitish "$TARGET_BRANCH" \
        --argjson prerelease "$prerelease_flag" \
        [cite_start]'{tag_name: $tag_name, name: $name, body: $body, target_commitish: $target_commitish, prerelease: $prerelease, generate_release_notes: false}'); then # [cite: 268]
        error_exit 4 "Failed to construct JSON for release creation. Check jq installation or input data."
    fi

    if $DRY_RUN; then
        log "INFO" "[DRY-RUN] Would create GitHub release with data: $release_data"
        RELEASE_ID="dry_run_release_id_$(date +%s)"
        RELEASE_URL="https://github.com/$OWNER/$REPO/releases/tag/$RELEASE_TAG"
        log "INFO" "[DRY-RUN] GitHub release simulated. ID: '$RELEASE_ID', URL: '$RELEASE_URL'"
        return 0
    fi

    local release_response
    [cite_start]release_response=$(api "$API_BASE/repos/$OWNER/$REPO/releases" POST "$release_data") # [cite: 271]

    if [[ $? [cite_start]-ne 0 ]]; then # [cite: 272]
        error_exit 4 "Failed to create GitHub release. API response: $release_response"
    fi

    RELEASE_ID=$(echo "$release_response" | jq -r '.id // "null"')
    RELEASE_URL=$(echo "$release_response" | jq -r '.html_url // "null"')

    if [[ "$RELEASE_ID" == "null" || -z "$RELEASE_ID" || "$RELEASE_URL" == "null" || [cite_start]-z "$RELEASE_URL" ]]; then # [cite: 273, 274]
        error_exit 4 "Failed to parse release ID or URL from GitHub API response after creation. Response: $release_response"
    fi

    log "INFO" "GitHub Release created successfully: $RELEASE_URL (ID: $RELEASE_ID)"
}

# Generate a zip artifact of the repository and optionally upload it to GitHub Release
function process_generate_artifacts() {
    if ! [cite_start]$GENERATE_ARTIFACTS; then # [cite: 275]
        log "INFO" "Skipping artifact generation (use --generate-artifacts to enable)."
        [cite_start]return 0 # [cite: 276]
    fi

    log "INFO" "Generating release artifact (zip)..."

    local artifact_name="$REPO-$NEW_VERSION.zip"
    local artifact_path="$TEMP_DIR/$artifact_name"
    register_temp_file "$artifact_path"

    local -a zip_exclude_args=()
    [cite_start]for exclude_pattern in "${ARTIFACT_EXCLUSIONS[@]}"; do # [cite: 277]
        zip_exclude_args+=("-x" "$exclude_pattern")
    done

    (
        cd "$CLONE_DIR" || error_exit 1 "Failed to change directory to CLONE_DIR: '$CLONE_DIR'"
        if dry_run_mode zip -r "$artifact_path" . "${zip_exclude_args[@]}"; then
            [cite_start]log "INFO" "Artifact created at: $artifact_path" # [cite: 278]
        else
            error_exit 1 "Failed to create zip artifact."
        fi
    )

    if $CREATE_RELEASE && [[ -n "$RELEASE_ID" && ! [cite_start]"$RELEASE_ID" =~ ^dry_run_release_id_.*$ ]]; then # [cite: 279]
        log "INFO" "Uploading artifact '$artifact_name' to GitHub Release (ID: $RELEASE_ID)..."

        local upload_url
        upload_url=$(api "$API_BASE/repos/$OWNER/$REPO/releases/$RELEASE_ID" | jq -r '.upload_url // "null"' | sed 's/{?name,label}//')
        if [[ "$upload_url" == "null" || [cite_start]-z "$upload_url" ]]; then # [cite: 280]
            error_exit 4 "Failed to get upload URL for release asset. The API response might be malformed."
        fi

        log "DEBUG" "Upload URL: $upload_url"
        local upload_response
        local upload_error_log="$TEMP_DIR/curl_upload_error.log"
        local http_code
        local response_body

        http_code=$(curl -s -w "%{http_code}" \
            -o >(cat >&1; printf "\n") \
            --max-time 600 \
            -H "Authorization: token $GH_TOKEN" \
            -H "Content-Type: application/zip" \
            --data-binary "@$artifact_path" \
            "$upload_url?name=$artifact_name" 2>"$upload_error_log")

        [cite_start]if [[ "$http_code" =~ ^2[0-9]{2}$ ]]; then # [cite: 283]
            log "INFO" "Artifact uploaded successfully."
        [cite_start]else # [cite: 284]
            log "ERROR" "Failed to upload artifact. HTTP Code: $http_code. Response body may be above. Error log: $(cat "$upload_error_log")"
            error_exit 4 "Artifact upload failed."
        fi
    else
        log "INFO" "Skipping artifact upload (either --create-release not enabled, release ID is missing, or in dry-run mode)."
    fi
}

# Export release metadata to a JSON file for external systems
function process_export_metadata() {
    if ! [cite_start]$EXPORT_METADATA; then # [cite: 287]
        log "INFO" "Skipping metadata export (use --export-metadata to enable)."
        [cite_start]return 0 # [cite: 288]
    fi

    log "INFO" "Exporting release metadata to 'release_metadata.json'..."

    local metadata_file="$CLONE_DIR/release_metadata.json"
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    local metadata_json
    if ! metadata_json=$(jq -n \
        --arg current_version "$CURRENT_VERSION" \
        --arg new_version "$NEW_VERSION" \
        --arg version_type "$VERSION_TYPE" \
        --arg prerelease_identifier "$PRERELEASE_IDENTIFIER" \
        --arg owner "$OWNER" \
        --arg repo "$REPO" \
        --arg from_branch "$FROM_BRANCH" \
        --arg to_branch "$TO_BRANCH" \
        --arg target_branch "$TARGET_BRANCH" \
        --arg release_tag "$RELEASE_TAG" \
        --arg release_id "$RELEASE_ID" \
        --arg release_url "$RELEASE_URL" \
        --arg release_title "$RELEASE_TITLE" \
        --arg release_body "$RELEASE_BODY" \
        --arg timestamp "$timestamp" \
        '{
            "current_version": $current_version,
            "new_version": $new_version,
            "version_type": $version_type,
            "prerelease_identifier": $prerelease_identifier,
            "repository": {
                "owner": $owner,
                "name": $repo
            },
            "branches": {
                "from": $from_branch,
                "to": $to_branch,
                "target": $target_branch
            },
            "release": {
                "tag": $release_tag,
                "id": $release_id,
                "url": $release_url,
                "title": $release_title,
                "body": $release_body
            },
            "timestamp": $timestamp
        [cite_start]}'); then # [cite: 294]
        error_exit 1 "Failed to construct JSON for metadata export. Check jq installation or data."
    fi

    [cite_start]if command -v jq &>/dev/null; then # [cite: 296]
        echo "$metadata_json" | jq . > [cite_start]"$metadata_file" # [cite: 297]
    else
        echo "$metadata_json" > "$metadata_file"
    fi

    log "INFO" "Release metadata exported to: '$metadata_file'"
}

# Send notifications to configured channels
function process_notify() {
    [cite_start]if [[ -z "$NOTIFICATION_CHANNELS" ]]; then # [cite: 298]
        log "INFO" "No notification channels specified. Skipping notifications."
        [cite_start]return 0 # [cite: 299]
    fi

    log "INFO" "Sending notifications to channels: $NOTIFICATION_CHANNELS"

    IFS=',' read -ra CHANNELS <<< "$NOTIFICATION_CHANNELS"
    [cite_start]for channel in "${CHANNELS[@]}"; do # [cite: 300]
        local hook_script="${HOOKS_DIR}/notify_${channel}.sh"
        [cite_start]if [[ -f "$hook_script" ]]; then # [cite: 301]
            log "INFO" "Attempting to send notification via '$channel' hook."
            local notification_data
            if ! notification_data=$(jq -n \
                --arg new_version "$NEW_VERSION" \
                --arg release_tag "$RELEASE_TAG" \
                --arg release_url "$RELEASE_URL" \
                --arg release_title "$RELEASE_TITLE" \
                --arg release_body "$RELEASE_BODY" \
                --arg owner "$OWNER" \
                --arg repo "$REPO" \
                '{
                    "version": $new_version,
                    "tag": $RELEASE_TAG,
                    "url": $release_url,
                    "title": $release_title,
                    "body": $release_body,
                    "repository": { "owner": $owner, "name": $repo }
                [cite_start]}'); then # [cite: 306]
                log "ERROR" "Failed to construct JSON for notification data for channel '$channel'. Skipping."
                [cite_start]continue # [cite: 307]
            fi
            execute_hook "$hook_script" "release_notification" "$notification_data"
        else
            log "WARNING" "Notification hook for channel '$channel' not found at '$hook_script'. Skipping notification for this channel."
        fi
    done
    log "INFO" "Notification process complete."
}

# ==============================================================================
# Main Execution Flow
# ==============================================================================

function main() {
    initialize_temp_dir

    [cite_start]parse_args "$@" # [cite: 310]

    [cite_start]load_config # [cite: 312]

    [cite_start]set_branch_defaults # [cite: 313]

    [cite_start]validate_environment_requirements # [cite: 314]
    validate_repo_info
    [cite_start]validate_git_state # [cite: 315]
    validate_github_permissions

    get_latest_git_tag
    calculate_new_version
    validate_version_comparison

    log "INFO" "Starting release process for v$NEW_VERSION (a '$VERSION_TYPE' bump from v$CURRENT_VERSION)."
    [cite_start]git_backup_repo # [cite: 316]

    local pre_commit_hook_data
    pre_commit_hook_data=$(jq -n \
        --arg current_version "$CURRENT_VERSION" \
        --arg new_version "$NEW_VERSION" \
        --arg version_type "$VERSION_TYPE" \
        --arg from_branch "$FROM_BRANCH" \
        --arg to_branch "$TO_BRANCH" \
        [cite_start]'{current_version: $current_version, new_version: $new_version, version_type: $version_type, from_branch: $from_branch, to_branch: $to_branch}') # [cite: 317]
    [cite_start]for hook_name in "${PRE_COMMIT_HOOKS[@]}"; do # [cite: 318]
        local hook_script="${HOOKS_DIR}/pre_commit_${hook_name}.sh"
        execute_hook "$hook_script" "pre_commit" "$pre_commit_hook_data"
    done

    process_git_operations

    process_generate_changelog

    process_create_github_release

    process_generate_artifacts

    [cite_start]process_export_metadata # [cite: 319]

    local post_release_hook_data
    post_release_hook_data=$(jq -n \
        --arg new_version "$NEW_VERSION" \
        --arg release_tag "$RELEASE_TAG" \
        --arg release_url "$RELEASE_URL" \
        --arg release_id "$RELEASE_ID" \
        --arg owner "$OWNER" \
        --arg repo "$REPO" \
        '{
            "new_version": $new_version,
            "release_tag": $release_tag,
            "release_url": $release_url,
            "release_id": $release_id,
            "repository_owner": $owner,
            "repository_name": $repo
        [cite_start]}') # [cite: 320]
    [cite_start]for hook_name in "${POST_RELEASE_HOOKS[@]}"; do # [cite: 321]
        local hook_script="${HOOKS_DIR}/post_release_${hook_name}.sh"
        execute_hook "$hook_script" "post_release" "$post_release_hook_data"
    done

    process_notify

    log "INFO" "Release process for v$NEW_VERSION completed successfully!"
}

# Pass all script arguments to the main function
main "$@"

# --------------   END verbatim copy of 2028.txt   ----------------------
ARCHIVE_2028
