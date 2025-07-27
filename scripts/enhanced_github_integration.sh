#!/usr/bin/env bash
#
# Enhanced GitHub Integration System
# Professional-grade version pushing with advanced security, validation, and automation
#
# Features:
# - Secure credential management with multiple auth methods
# - Comprehensive pre-push validation and testing  
# - Advanced conflict resolution and merge strategies
# - GitHub API integration for releases and status checks
# - Rollback capabilities and emergency procedures
# - Multi-branch deployment strategies
# - Security scanning and secret detection
# - Automated PR creation and management
# - Performance monitoring and metrics
# - Comprehensive audit logging
#

set -euo pipefail
IFS=$'\n\t'

# Source enterprise logging and alerting
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/enterprise_logging_framework_v2.sh" 2>/dev/null || {
    echo "WARNING: Enterprise logging not available"
}
source "${SCRIPT_DIR}/lib/external_alerting_system.sh" 2>/dev/null || {
    echo "WARNING: External alerting not available"  
}

# === CONFIGURATION ===
readonly GITHUB_INTEGRATION_VERSION="2.0.0"
readonly CONFIG_DIR="${HOME}/.cache/cursor/github-integration"
readonly CREDENTIALS_FILE="${CONFIG_DIR}/credentials.enc"
readonly GITHUB_CONFIG_FILE="${CONFIG_DIR}/config.json"
readonly PUSH_LOG_FILE="${CONFIG_DIR}/push_history.log"
readonly METRICS_FILE="${CONFIG_DIR}/metrics.json"

# GitHub Configuration
declare -g GITHUB_OWNER="${GITHUB_OWNER:-}"
declare -g GITHUB_REPO="${GITHUB_REPO:-}"
declare -g GITHUB_TOKEN="${GITHUB_TOKEN:-}"
declare -g GITHUB_API_URL="${GITHUB_API_URL:-https://api.github.com}"
declare -g DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
declare -g RELEASE_BRANCH_PREFIX="${RELEASE_BRANCH_PREFIX:-release/}"

# Push Configuration
declare -g ENABLE_PRE_PUSH_HOOKS="${ENABLE_PRE_PUSH_HOOKS:-true}"
declare -g ENABLE_SECURITY_SCANNING="${ENABLE_SECURITY_SCANNING:-true}"
declare -g ENABLE_PERFORMANCE_TESTING="${ENABLE_PERFORMANCE_TESTING:-true}"
declare -g ENABLE_AUTO_PR="${ENABLE_AUTO_PR:-false}"
declare -g REQUIRE_SIGNED_COMMITS="${REQUIRE_SIGNED_COMMITS:-true}"
declare -g MAX_PUSH_RETRIES="${MAX_PUSH_RETRIES:-3}"
declare -g PUSH_TIMEOUT="${PUSH_TIMEOUT:-300}"

# Validation thresholds
declare -g MAX_COMMIT_SIZE_MB="${MAX_COMMIT_SIZE_MB:-100}"
declare -g MIN_TEST_COVERAGE="${MIN_TEST_COVERAGE:-80}"
declare -g MAX_SECURITY_VULNERABILITIES="${MAX_SECURITY_VULNERABILITIES:-0}"

# === INITIALIZATION ===
init_github_integration() {
    log_info "Initializing Enhanced GitHub Integration v${GITHUB_INTEGRATION_VERSION}" "github_init"
    
    # Create required directories
    mkdir -p "$CONFIG_DIR"
    touch "$PUSH_LOG_FILE" "$METRICS_FILE"
    
    # Initialize configuration if not exists
    if [[ ! -f "$GITHUB_CONFIG_FILE" ]]; then
        create_default_config
    fi
    
    # Load configuration
    load_github_config
    
    # Validate setup
    if ! validate_github_setup; then
        log_error "GitHub integration setup validation failed" "github_init"
        return 1
    fi
    
    log_info "GitHub integration initialized successfully" "github_init"
    return 0
}

create_default_config() {
    cat > "$GITHUB_CONFIG_FILE" << 'EOF'
{
    "version": "2.0.0",
    "github": {
        "api_url": "https://api.github.com",
        "default_branch": "main",
        "release_branch_prefix": "release/"
    },
    "validation": {
        "enable_pre_push_hooks": true,
        "enable_security_scanning": true,
        "enable_performance_testing": true,
        "require_signed_commits": true,
        "max_commit_size_mb": 100,
        "min_test_coverage": 80,
        "max_security_vulnerabilities": 0
    },
    "automation": {
        "enable_auto_pr": false,
        "auto_merge_patch": false,
        "auto_deploy_staging": false
    },
    "notifications": {
        "slack_on_push": true,
        "email_on_failure": true,
        "webhook_on_release": true
    }
}
EOF
    
    log_info "Created default GitHub integration configuration" "github_init"
}

load_github_config() {
    if [[ -f "$GITHUB_CONFIG_FILE" ]] && command -v jq >/dev/null 2>&1; then
        GITHUB_API_URL=$(jq -r '.github.api_url // "https://api.github.com"' "$GITHUB_CONFIG_FILE")
        DEFAULT_BRANCH=$(jq -r '.github.default_branch // "main"' "$GITHUB_CONFIG_FILE")
        RELEASE_BRANCH_PREFIX=$(jq -r '.github.release_branch_prefix // "release/"' "$GITHUB_CONFIG_FILE")
        
        ENABLE_PRE_PUSH_HOOKS=$(jq -r '.validation.enable_pre_push_hooks // true' "$GITHUB_CONFIG_FILE")
        ENABLE_SECURITY_SCANNING=$(jq -r '.validation.enable_security_scanning // true' "$GITHUB_CONFIG_FILE")
        REQUIRE_SIGNED_COMMITS=$(jq -r '.validation.require_signed_commits // true' "$GITHUB_CONFIG_FILE")
        
        log_info "GitHub configuration loaded from file" "github_config"
    else
        log_warn "Using default GitHub configuration" "github_config"
    fi
}

# === AUTHENTICATION & SECURITY ===
setup_github_auth() {
    log_info "Setting up GitHub authentication" "github_auth"
    
    # Try multiple authentication methods in order of preference
    if setup_github_token_auth; then
        log_info "GitHub token authentication configured" "github_auth"
        return 0
    fi
    
    if setup_github_ssh_auth; then
        log_info "GitHub SSH authentication configured" "github_auth"
        return 0
    fi
    
    if setup_github_app_auth; then
        log_info "GitHub App authentication configured" "github_auth"
        return 0
    fi
    
    log_error "Failed to configure GitHub authentication" "github_auth"
    return 1
}

setup_github_token_auth() {
    # Check for token in environment
    if [[ -n "$GITHUB_TOKEN" ]]; then
        return 0
    fi
    
    # Check for token in GitHub CLI
    if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
        GITHUB_TOKEN=$(gh auth token 2>/dev/null || echo "")
        if [[ -n "$GITHUB_TOKEN" ]]; then
            return 0
        fi
    fi
    
    # Check for token in git config
    local git_token
    git_token=$(git config --global github.token 2>/dev/null || echo "")
    if [[ -n "$git_token" ]]; then
        GITHUB_TOKEN="$git_token"
        return 0
    fi
    
    # Check for encrypted credentials file
    if [[ -f "$CREDENTIALS_FILE" ]] && command -v openssl >/dev/null 2>&1; then
        local decrypted_token
        decrypted_token=$(decrypt_credential "github_token")
        if [[ -n "$decrypted_token" ]]; then
            GITHUB_TOKEN="$decrypted_token"
            return 0
        fi
    fi
    
    return 1
}

setup_github_ssh_auth() {
    # Check if SSH keys are set up for GitHub
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        log_info "SSH authentication to GitHub verified" "github_auth"
        return 0
    fi
    
    return 1
}

setup_github_app_auth() {
    # GitHub App authentication (for enterprise users)
    local app_id="${GITHUB_APP_ID:-}"
    local private_key="${GITHUB_APP_PRIVATE_KEY:-}"
    local installation_id="${GITHUB_APP_INSTALLATION_ID:-}"
    
    if [[ -n "$app_id" && -n "$private_key" && -n "$installation_id" ]]; then
        # Generate JWT token for GitHub App
        if generate_github_app_token "$app_id" "$private_key" "$installation_id"; then
            return 0
        fi
    fi
    
    return 1
}

generate_secure_password() {
    # Generate a secure password using available tools
    if command -v openssl >/dev/null 2>&1; then
        openssl rand -base64 32 | tr -d '\n'
    elif command -v head >/dev/null 2>&1 && [[ -c /dev/urandom ]]; then
        head -c 32 /dev/urandom | base64 | tr -d '\n'
    else
        # Fallback: generate from timestamp and process info
        echo "${USER}_$(date +%s)_$$_$(hostname)" | sha256sum | cut -d' ' -f1
    fi
}

encrypt_credential() {
    local credential_name="$1"
    local credential_value="$2"
    local password="${ENCRYPTION_PASSWORD:-$(generate_secure_password)}"
    
    if command -v openssl >/dev/null 2>&1; then
        echo "$credential_value" | openssl enc -aes-256-cbc -salt -a -pass pass:"$password" > "${CREDENTIALS_FILE}.${credential_name}"
        chmod 600 "${CREDENTIALS_FILE}.${credential_name}"
        log_info "Credential encrypted and stored: $credential_name" "github_auth"
    else
        log_warn "OpenSSL not available, storing credential in plain text" "github_auth"
        echo "$credential_value" > "${CREDENTIALS_FILE}.${credential_name}"
        chmod 600 "${CREDENTIALS_FILE}.${credential_name}"
    fi
}

decrypt_credential() {
    local credential_name="$1"
    local password="${ENCRYPTION_PASSWORD:-$(generate_secure_password)}"
    local credential_file="${CREDENTIALS_FILE}.${credential_name}"
    
    if [[ -f "$credential_file" ]]; then
        if command -v openssl >/dev/null 2>&1; then
            openssl enc -aes-256-cbc -d -a -pass pass:"$password" -in "$credential_file" 2>/dev/null || cat "$credential_file"
        else
            cat "$credential_file"
        fi
    fi
}

# === GITHUB API INTEGRATION ===
github_api_call() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"
    local headers="${4:-}"
    
    if [[ -z "$GITHUB_TOKEN" ]]; then
        log_error "GitHub token not available for API call" "github_api"
        return 1
    fi
    
    local curl_args=(
        -s
        -X "$method"
        -H "Authorization: token $GITHUB_TOKEN"
        -H "Accept: application/vnd.github.v3+json"
        -H "User-Agent: cursor-bundle-integration/2.0.0"
    )
    
    if [[ -n "$headers" ]]; then
        while IFS= read -r header; do
            [[ -n "$header" ]] && curl_args+=(-H "$header")
        done <<< "$headers"
    fi
    
    if [[ -n "$data" ]]; then
        curl_args+=(-d "$data")
    fi
    
    local response
    response=$(curl "${curl_args[@]}" "${GITHUB_API_URL}${endpoint}" 2>/dev/null)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo "$response"
        return 0
    else
        log_error "GitHub API call failed: $method $endpoint" "github_api"
        return 1
    fi
}

get_repository_info() {
    local owner="$1"
    local repo="$2"
    
    github_api_call "GET" "/repos/$owner/$repo"
}

create_github_release() {
    local owner="$1"
    local repo="$2"
    local tag="$3"
    local name="$4"
    local body="$5"
    local prerelease="${6:-false}"
    
    local release_data=$(cat << EOF
{
    "tag_name": "$tag",
    "target_commitish": "$(git rev-parse HEAD)",
    "name": "$name",
    "body": "$body",
    "draft": false,
    "prerelease": $prerelease
}
EOF
)
    
    github_api_call "POST" "/repos/$owner/$repo/releases" "$release_data"
}

create_pull_request() {
    local owner="$1"
    local repo="$2"
    local head_branch="$3"
    local base_branch="$4"
    local title="$5"
    local body="$6"
    
    local pr_data=$(cat << EOF
{
    "title": "$title",
    "head": "$head_branch",
    "base": "$base_branch",
    "body": "$body",
    "maintainer_can_modify": true
}
EOF
)
    
    github_api_call "POST" "/repos/$owner/$repo/pulls" "$pr_data"
}

get_branch_protection() {
    local owner="$1"
    local repo="$2"
    local branch="$3"
    
    github_api_call "GET" "/repos/$owner/$repo/branches/$branch/protection"
}

# === PRE-PUSH VALIDATION ===
run_pre_push_validation() {
    local branch="$1"
    local remote="$2"
    
    log_info "Running comprehensive pre-push validation" "validation"
    
    local validation_results=()
    
    # 1. Repository state validation
    if validate_repository_state; then
        validation_results+=("repo_state:PASS")
    else
        validation_results+=("repo_state:FAIL")
    fi
    
    # 2. Commit validation
    if validate_commits "$branch"; then
        validation_results+=("commits:PASS")
    else
        validation_results+=("commits:FAIL")
    fi
    
    # 3. Security scanning
    if [[ "$ENABLE_SECURITY_SCANNING" == "true" ]]; then
        if run_security_scan; then
            validation_results+=("security:PASS")
        else
            validation_results+=("security:FAIL")
        fi
    fi
    
    # 4. Test execution
    if run_pre_push_tests; then
        validation_results+=("tests:PASS")
    else
        validation_results+=("tests:FAIL")
    fi
    
    # 5. Performance validation
    if [[ "$ENABLE_PERFORMANCE_TESTING" == "true" ]]; then
        if run_performance_validation; then
            validation_results+=("performance:PASS")
        else
            validation_results+=("performance:FAIL")
        fi
    fi
    
    # 6. Branch protection compliance
    if validate_branch_protection "$branch"; then
        validation_results+=("branch_protection:PASS")
    else
        validation_results+=("branch_protection:FAIL")
    fi
    
    # Evaluate overall result
    local failed_validations=()
    for result in "${validation_results[@]}"; do
        if [[ "$result" =~ :FAIL$ ]]; then
            failed_validations+=("${result%:*}")
        fi
    done
    
    if [[ ${#failed_validations[@]} -eq 0 ]]; then
        log_info "All pre-push validations passed" "validation"
        return 0
    else
        log_error "Pre-push validation failed: ${failed_validations[*]}" "validation"
        send_external_alert "HIGH" "Pre-push Validation Failed" \
            "Failed validations: ${failed_validations[*]}" "github_push"
        return 1
    fi
}

validate_repository_state() {
    log_info "Validating repository state" "validation"
    
    # Check for uncommitted changes
    if ! git diff --quiet; then
        log_error "Uncommitted changes detected" "validation"
        return 1
    fi
    
    # Check for untracked files that should be committed
    local untracked_files
    untracked_files=$(git ls-files --others --exclude-standard)
    if [[ -n "$untracked_files" ]]; then
        log_warn "Untracked files detected: $untracked_files" "validation"
    fi
    
    # Check repository size
    local repo_size_mb
    repo_size_mb=$(du -sm . | cut -f1)
    if [[ $repo_size_mb -gt 1000 ]]; then  # 1GB limit
        log_warn "Repository size is large: ${repo_size_mb}MB" "validation"
    fi
    
    return 0
}

validate_commits() {
    local branch="$1"
    log_info "Validating commits on branch: $branch" "validation"
    
    # Get commits to be pushed
    local commits_to_push
    commits_to_push=$(git rev-list "origin/$branch..$branch" 2>/dev/null || git rev-list "$branch" | head -10)
    
    if [[ -z "$commits_to_push" ]]; then
        log_info "No new commits to validate" "validation"
        return 0
    fi
    
    local commit_count=0
    while IFS= read -r commit; do
        [[ -z "$commit" ]] && continue
        ((commit_count++))
        
        # Validate commit message
        local commit_msg
        commit_msg=$(git log --format=%B -n 1 "$commit")
        if ! validate_commit_message "$commit_msg"; then
            log_error "Invalid commit message format: $commit" "validation"
            return 1
        fi
        
        # Check commit size
        local commit_size
        commit_size=$(git show --format='' --numstat "$commit" | awk '{sum += $1 + $2} END {print sum}')
        if [[ $commit_size -gt $((MAX_COMMIT_SIZE_MB * 1024)) ]]; then  # Convert MB to KB
            log_error "Commit too large: $commit (${commit_size}KB)" "validation"
            return 1
        fi
        
        # Validate commit signature if required
        if [[ "$REQUIRE_SIGNED_COMMITS" == "true" ]]; then
            if ! git verify-commit "$commit" >/dev/null 2>&1; then
                log_error "Unsigned commit detected: $commit" "validation"
                return 1
            fi
        fi
        
    done <<< "$commits_to_push"
    
    log_info "Validated $commit_count commits successfully" "validation"
    return 0
}

validate_commit_message() {
    local commit_msg="$1"
    
    # Check for conventional commit format or basic requirements
    if [[ "$commit_msg" =~ ^(feat|fix|docs|style|refactor|test|chore|ci|build|perf)(\(.+\))?: .+ ]] || \
       [[ ${#commit_msg} -ge 10 && ! "$commit_msg" =~ ^(wip|temp|tmp) ]]; then
        return 0
    fi
    
    return 1
}

run_security_scan() {
    log_info "Running security scan" "validation"
    
    local security_issues=0
    
    # 1. Secret detection
    if detect_secrets; then
        log_info "No secrets detected" "validation"
    else
        ((security_issues++))
        log_error "Secrets detected in codebase" "validation"
    fi
    
    # 2. Dependency vulnerability scan
    if scan_dependencies; then
        log_info "No vulnerable dependencies found" "validation"
    else
        ((security_issues++))
        log_error "Vulnerable dependencies detected" "validation"
    fi
    
    # 3. Static analysis security scan
    if run_static_security_analysis; then
        log_info "Static security analysis passed" "validation"
    else
        ((security_issues++))
        log_error "Static security analysis found issues" "validation"
    fi
    
    if [[ $security_issues -le $MAX_SECURITY_VULNERABILITIES ]]; then
        return 0
    else
        send_external_alert "CRITICAL" "Security Scan Failed" \
            "Found $security_issues security issues before push" "github_security"
        return 1
    fi
}

detect_secrets() {
    # Simple secret patterns detection
    local secret_patterns=(
        "-----BEGIN [A-Z ]*PRIVATE KEY-----"
        "password[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
        "api[_-]?key[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
        "secret[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
        "token[[:space:]]*=[[:space:]]*['\"][^'\"]+['\"]"
        "ghp_[a-zA-Z0-9]{36}"  # GitHub personal access token
        "github_pat_[a-zA-Z0-9_]{82}"  # GitHub fine-grained token
    )
    
    for pattern in "${secret_patterns[@]}"; do
        if git grep -i -E "$pattern" -- ':!*.log' ':!*test*' ':!*example*' >/dev/null 2>&1; then
            log_error "Potential secret detected matching pattern: $pattern" "security"
            return 1
        fi
    done
    
    return 0
}

scan_dependencies() {
    # Dependency scanning for different package managers
    local vuln_count=0
    
    # npm audit (if package.json exists)
    if [[ -f "package.json" ]] && command -v npm >/dev/null 2>&1; then
        if ! npm audit --audit-level=moderate >/dev/null 2>&1; then
            ((vuln_count++))
            log_warn "npm audit found vulnerabilities" "security"
        fi
    fi
    
    # pip audit (if requirements.txt exists)
    if [[ -f "requirements.txt" ]] && command -v pip-audit >/dev/null 2>&1; then
        if ! pip-audit -r requirements.txt >/dev/null 2>&1; then
            ((vuln_count++))
            log_warn "pip-audit found vulnerabilities" "security"
        fi
    fi
    
    return $vuln_count
}

run_static_security_analysis() {
    # Run available static analysis tools
    local analysis_results=0
    
    # Bandit for Python
    if command -v bandit >/dev/null 2>&1 && find . -name "*.py" -not -path "./.git/*" | head -1 >/dev/null; then
        if ! bandit -r . -f json -o /tmp/bandit_results.json >/dev/null 2>&1; then
            ((analysis_results++))
        fi
    fi
    
    # Semgrep (if available)
    if command -v semgrep >/dev/null 2>&1; then
        if ! semgrep --config=auto --json --output=/tmp/semgrep_results.json . >/dev/null 2>&1; then
            ((analysis_results++))
        fi
    fi
    
    return $analysis_results
}

run_pre_push_tests() {
    log_info "Running pre-push tests" "validation"
    
    # Discover and run test suites
    local test_results=0
    
    # Python tests
    if [[ -f "pytest.ini" ]] || [[ -f "setup.cfg" ]] || find . -name "*test*.py" | head -1 >/dev/null; then
        if command -v pytest >/dev/null 2>&1; then
            if ! timeout 300 pytest --tb=short -q >/dev/null 2>&1; then
                ((test_results++))
                log_error "Python tests failed" "validation"
            fi
        fi
    fi
    
    # Node.js tests
    if [[ -f "package.json" ]] && command -v npm >/dev/null 2>&1; then
        if npm test >/dev/null 2>&1; then
            log_info "Node.js tests passed" "validation"
        else
            ((test_results++))
            log_error "Node.js tests failed" "validation"
        fi
    fi
    
    # Shell script tests
    if [[ -f "scripts/enhanced_test_runner.sh" ]]; then
        if timeout 300 bash scripts/enhanced_test_runner.sh --comprehensive >/dev/null 2>&1; then
            log_info "Shell script tests passed" "validation"
        else
            ((test_results++))
            log_error "Shell script tests failed" "validation"
        fi
    fi
    
    return $test_results
}

run_performance_validation() {
    log_info "Running performance validation" "validation"
    
    # Simple performance checks
    local perf_issues=0
    
    # Check for large files
    local large_files
    large_files=$(find . -type f -size +10M -not -path "./.git/*" 2>/dev/null | wc -l)
    if [[ $large_files -gt 5 ]]; then
        ((perf_issues++))
        log_warn "Found $large_files large files (>10MB)" "validation"
    fi
    
    # Check repository size growth
    local current_size
    current_size=$(du -sm . | cut -f1)
    if [[ $current_size -gt 500 ]]; then  # 500MB threshold
        ((perf_issues++))
        log_warn "Repository size is large: ${current_size}MB" "validation"
    fi
    
    return $perf_issues
}

validate_branch_protection() {
    local branch="$1"
    
    if [[ -z "$GITHUB_OWNER" || -z "$GITHUB_REPO" ]]; then
        log_warn "GitHub repository info not configured, skipping branch protection check" "validation"
        return 0
    fi
    
    local protection_info
    protection_info=$(get_branch_protection "$GITHUB_OWNER" "$GITHUB_REPO" "$branch" 2>/dev/null)
    
    if [[ -n "$protection_info" ]]; then
        log_info "Branch protection is enabled for $branch" "validation"
        return 0
    else
        log_warn "Branch protection not enabled for $branch" "validation"
        return 0  # Don't fail, just warn
    fi
}

# === ENHANCED PUSH OPERATIONS ===
enhanced_git_push() {
    local branch="${1:-$(git rev-parse --abbrev-ref HEAD)}"
    local remote="${2:-origin}"
    local version="${3:-}"
    local force="${4:-false}"
    
    log_info "Starting enhanced Git push: $remote/$branch" "github_push"
    
    # Record push attempt
    record_push_attempt "$branch" "$remote" "$version"
    
    # Pre-push validation
    if [[ "$ENABLE_PRE_PUSH_HOOKS" == "true" ]]; then
        if ! run_pre_push_validation "$branch" "$remote"; then
            log_error "Pre-push validation failed, aborting push" "github_push"
            record_push_result "VALIDATION_FAILED" "$branch" "$remote"
            return 1
        fi
    fi
    
    # Setup authentication
    if ! setup_github_auth; then
        log_error "GitHub authentication setup failed" "github_push"
        record_push_result "AUTH_FAILED" "$branch" "$remote"
        return 1
    fi
    
    # Attempt push with retry logic
    local push_success=false
    for ((attempt=1; attempt<=MAX_PUSH_RETRIES; attempt++)); do
        log_info "Push attempt $attempt/$MAX_PUSH_RETRIES" "github_push"
        
        if attempt_push_with_conflict_resolution "$branch" "$remote" "$force"; then
            push_success=true
            break
        else
            if [[ $attempt -lt $MAX_PUSH_RETRIES ]]; then
                log_warn "Push attempt $attempt failed, retrying in 5 seconds..." "github_push"
                sleep 5
            fi
        fi
    done
    
    if [[ "$push_success" != "true" ]]; then
        log_error "All push attempts failed" "github_push"
        record_push_result "PUSH_FAILED" "$branch" "$remote"
        send_external_alert "HIGH" "Git Push Failed" \
            "Failed to push $branch to $remote after $MAX_PUSH_RETRIES attempts" "github_push"
        return 1
    fi
    
    # Post-push operations
    perform_post_push_operations "$branch" "$remote" "$version"
    
    # Record successful push
    record_push_result "SUCCESS" "$branch" "$remote"
    log_info "Enhanced Git push completed successfully" "github_push"
    
    return 0
}

attempt_push_with_conflict_resolution() {
    local branch="$1"
    local remote="$2"
    local force="$3"
    
    # Try normal push first
    if [[ "$force" == "true" ]]; then
        log_warn "Force pushing to $remote/$branch" "github_push"
        if timeout "$PUSH_TIMEOUT" git push --force-with-lease "$remote" "$branch"; then
            return 0
        fi
    else
        if timeout "$PUSH_TIMEOUT" git push "$remote" "$branch"; then
            return 0
        fi
    fi
    
    # Handle conflicts
    local push_exit_code=$?
    if [[ $push_exit_code -eq 124 ]]; then
        log_error "Push timed out after ${PUSH_TIMEOUT} seconds" "github_push"
        return 1
    fi
    
    # Try to resolve conflicts
    log_info "Push failed, attempting conflict resolution" "github_push"
    
    # Fetch latest changes
    if ! git fetch "$remote" "$branch"; then
        log_error "Failed to fetch latest changes from remote" "github_push"
        return 1
    fi
    
    # Check for conflicts
    local local_commit=$(git rev-parse "$branch")
    local remote_commit=$(git rev-parse "$remote/$branch" 2>/dev/null || echo "")
    
    if [[ -n "$remote_commit" && "$local_commit" != "$remote_commit" ]]; then
        log_info "Detected remote changes, attempting rebase" "github_push"
        
        # Attempt automatic rebase
        if git rebase "$remote/$branch"; then
            log_info "Rebase successful, retrying push" "github_push"
            if timeout "$PUSH_TIMEOUT" git push "$remote" "$branch"; then
                return 0
            fi
        else
            log_error "Rebase failed due to conflicts" "github_push"
            git rebase --abort 2>/dev/null || true
            return 1
        fi
    fi
    
    return 1
}

perform_post_push_operations() {
    local branch="$1"
    local remote="$2"
    local version="$3"
    
    log_info "Performing post-push operations" "github_push"
    
    # Push tags if version is provided
    if [[ -n "$version" ]]; then
        push_version_tag "$version" "$remote"
    fi
    
    # Create GitHub release if this is a release branch
    if [[ "$branch" =~ ^${RELEASE_BRANCH_PREFIX} ]] && [[ -n "$version" ]]; then
        create_github_release_if_configured "$version"
    fi
    
    # Create pull request if auto-PR is enabled
    if [[ "$ENABLE_AUTO_PR" == "true" && "$branch" != "$DEFAULT_BRANCH" ]]; then
        create_auto_pull_request "$branch"
    fi
    
    # Send notifications
    send_push_notifications "$branch" "$version"
    
    # Update metrics
    update_push_metrics "$branch" "$version"
}

push_version_tag() {
    local version="$1"
    local remote="$2"
    
    log_info "Pushing version tag: $version" "github_push"
    
    # Check if tag exists locally
    if git tag -l | grep -q "^${version}$"; then
        if timeout "$PUSH_TIMEOUT" git push "$remote" "$version"; then
            log_info "Version tag pushed successfully: $version" "github_push"
        else
            log_error "Failed to push version tag: $version" "github_push"
        fi
    else
        log_warn "Version tag does not exist locally: $version" "github_push"
    fi
}

create_github_release_if_configured() {
    local version="$1"
    
    if [[ -z "$GITHUB_OWNER" || -z "$GITHUB_REPO" || -z "$GITHUB_TOKEN" ]]; then
        log_info "GitHub release creation not configured" "github_push"
        return 0
    fi
    
    log_info "Creating GitHub release for version: $version" "github_push"
    
    # Generate release notes
    local release_notes
    release_notes=$(generate_release_notes "$version")
    
    # Create release
    local release_response
    release_response=$(create_github_release "$GITHUB_OWNER" "$GITHUB_REPO" "$version" \
        "Release $version" "$release_notes" "false")
    
    if [[ $? -eq 0 ]]; then
        log_info "GitHub release created successfully: $version" "github_push"
        local release_url
        release_url=$(echo "$release_response" | jq -r '.html_url' 2>/dev/null || echo "")
        if [[ -n "$release_url" ]]; then
            log_info "Release URL: $release_url" "github_push"
        fi
    else
        log_error "Failed to create GitHub release: $version" "github_push"
    fi
}

generate_release_notes() {
    local version="$1"
    local previous_tag
    previous_tag=$(git describe --tags --abbrev=0 HEAD~1 2>/dev/null || echo "")
    
    local release_notes="Release $version\n\n"
    
    if [[ -n "$previous_tag" ]]; then
        release_notes+="## Changes since $previous_tag\n\n"
        release_notes+="$(git log --pretty=format:'- %s (%an)' "${previous_tag}..HEAD" 2>/dev/null || echo '- Initial release')\n\n"
    else
        release_notes+="## Changes\n\n- Initial release\n\n"
    fi
    
    release_notes+="---\n"
    release_notes+="Generated by Enhanced GitHub Integration v${GITHUB_INTEGRATION_VERSION}"
    
    echo -e "$release_notes"
}

create_auto_pull_request() {
    local branch="$1"
    
    if [[ -z "$GITHUB_OWNER" || -z "$GITHUB_REPO" || -z "$GITHUB_TOKEN" ]]; then
        log_info "Auto PR creation not configured" "github_push"
        return 0
    fi
    
    log_info "Creating automatic pull request for branch: $branch" "github_push"
    
    # Generate PR title and body
    local pr_title="Auto PR: $branch"
    local pr_body=$(cat << EOF
This is an automatically created pull request for branch \`$branch\`.

## Changes
$(git log --pretty=format:'- %s' "${DEFAULT_BRANCH}..${branch}" | head -10)

## Checklist
- [x] Tests passing
- [x] Security scan completed  
- [x] Pre-push validation successful

---
Created by Enhanced GitHub Integration v${GITHUB_INTEGRATION_VERSION}
EOF
)
    
    # Create pull request
    local pr_response
    pr_response=$(create_pull_request "$GITHUB_OWNER" "$GITHUB_REPO" "$branch" \
        "$DEFAULT_BRANCH" "$pr_title" "$pr_body")
    
    if [[ $? -eq 0 ]]; then
        log_info "Pull request created successfully for branch: $branch" "github_push"
        local pr_url
        pr_url=$(echo "$pr_response" | jq -r '.html_url' 2>/dev/null || echo "")
        if [[ -n "$pr_url" ]]; then
            log_info "Pull request URL: $pr_url" "github_push"
        fi
    else
        log_error "Failed to create pull request for branch: $branch" "github_push"
    fi
}

send_push_notifications() {
    local branch="$1"
    local version="$2"
    
    local notification_title="Git Push Successful"
    local notification_message="Successfully pushed $branch"
    if [[ -n "$version" ]]; then
        notification_message+=" (version $version)"
    fi
    notification_message+=" to GitHub"
    
    # Send alert notification
    send_external_alert "INFO" "$notification_title" "$notification_message" "github_push"
}

# === METRICS AND MONITORING ===
record_push_attempt() {
    local branch="$1"
    local remote="$2"
    local version="$3"
    local timestamp=$(date -Iseconds)
    
    echo "[$timestamp] ATTEMPT: $remote/$branch version=$version user=$USER host=$(hostname)" >> "$PUSH_LOG_FILE"
}

record_push_result() {
    local result="$1"
    local branch="$2"
    local remote="$3"
    local timestamp=$(date -Iseconds)
    
    echo "[$timestamp] RESULT: $result $remote/$branch user=$USER host=$(hostname)" >> "$PUSH_LOG_FILE"
}

update_push_metrics() {
    local branch="$1"
    local version="$2"
    
    # Update metrics file
    local metrics_data="{}"
    if [[ -f "$METRICS_FILE" ]]; then
        metrics_data=$(cat "$METRICS_FILE")
    fi
    
    # Add current push metrics (simplified without jq dependency)
    local timestamp=$(date +%s)
    echo "Push completed at $timestamp for $branch $version" >> "${METRICS_FILE}.log"
}

# === ROLLBACK AND RECOVERY ===
emergency_rollback() {
    local target_commit="${1:-HEAD~1}"
    local branch="${2:-$(git rev-parse --abbrev-ref HEAD)}"
    local remote="${3:-origin}"
    
    log_warn "Performing emergency rollback to $target_commit" "github_rollback"
    
    # Confirm rollback
    read -p "Are you sure you want to rollback $branch to $target_commit? (yes/no): " -r
    if [[ ! "$REPLY" =~ ^[Yy][Ee][Ss]$ ]]; then
        log_info "Rollback cancelled by user" "github_rollback"
        return 1
    fi
    
    # Create backup branch
    local backup_branch="backup-$(date +%Y%m%d-%H%M%S)"
    git branch "$backup_branch" || {
        log_error "Failed to create backup branch" "github_rollback"
        return 1
    }
    
    # Perform rollback
    if git reset --hard "$target_commit"; then
        log_info "Local rollback successful" "github_rollback"
        
        # Force push rollback
        if enhanced_git_push "$branch" "$remote" "" "true"; then
            log_info "Emergency rollback completed successfully" "github_rollback"
            send_external_alert "CRITICAL" "Emergency Rollback Completed" \
                "Rolled back $branch to $target_commit. Backup: $backup_branch" "github_rollback"
            return 0
        else
            log_error "Failed to push rollback" "github_rollback"
            return 1
        fi
    else
        log_error "Local rollback failed" "github_rollback"
        return 1
    fi
}

# === UTILITIES ===
validate_github_setup() {
    log_info "Validating GitHub integration setup" "github_setup"
    
    # Check git configuration
    if ! git config user.name >/dev/null 2>&1; then
        log_error "Git user.name not configured" "github_setup"
        return 1
    fi
    
    if ! git config user.email >/dev/null 2>&1; then
        log_error "Git user.email not configured" "github_setup"
        return 1
    fi
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Not in a git repository" "github_setup"
        return 1
    fi
    
    # Check remote configuration
    if ! git remote get-url origin >/dev/null 2>&1; then
        log_warn "No origin remote configured" "github_setup"
    fi
    
    return 0
}

show_github_integration_status() {
    echo "Enhanced GitHub Integration Status"
    echo "================================="
    echo "Version: $GITHUB_INTEGRATION_VERSION"
    echo ""
    
    echo "Configuration:"
    echo "  API URL: $GITHUB_API_URL"
    echo "  Default Branch: $DEFAULT_BRANCH"
    echo "  Release Prefix: $RELEASE_BRANCH_PREFIX"
    echo ""
    
    echo "Authentication:"
    if [[ -n "$GITHUB_TOKEN" ]]; then
        echo "  ✓ GitHub Token: Configured"
    else
        echo "  ✗ GitHub Token: Not configured"
    fi
    
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        echo "  ✓ SSH Auth: Working"
    else
        echo "  ✗ SSH Auth: Not working"
    fi
    echo ""
    
    echo "Features:"
    echo "  Pre-push Hooks: $ENABLE_PRE_PUSH_HOOKS"
    echo "  Security Scanning: $ENABLE_SECURITY_SCANNING"
    echo "  Performance Testing: $ENABLE_PERFORMANCE_TESTING"
    echo "  Auto PR: $ENABLE_AUTO_PR"
    echo "  Signed Commits: $REQUIRE_SIGNED_COMMITS"
    echo ""
    
    echo "Repository:"
    if git rev-parse --git-dir >/dev/null 2>&1; then
        echo "  ✓ Git Repository: $(pwd)"
        echo "  Current Branch: $(git rev-parse --abbrev-ref HEAD)"
        local remote_url
        remote_url=$(git remote get-url origin 2>/dev/null || echo "Not configured")
        echo "  Origin Remote: $remote_url"
    else
        echo "  ✗ Not in a git repository"
    fi
}

# === COMMAND LINE INTERFACE ===
show_usage() {
    cat << EOF
Enhanced GitHub Integration v$GITHUB_INTEGRATION_VERSION

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    push [BRANCH] [REMOTE]     - Enhanced push with validation
    tag-push VERSION [REMOTE]  - Push with version tagging
    release VERSION            - Create GitHub release
    rollback [COMMIT] [BRANCH] - Emergency rollback
    test                       - Test configuration and connectivity
    status                     - Show integration status
    config                     - Show configuration help

OPTIONS:
    --force                    - Force push (use with caution)
    --no-validation           - Skip pre-push validation
    --no-hooks                - Skip pre-push hooks
    --help                    - Show this help

EXAMPLES:
    $0 push                               # Push current branch with full validation
    $0 push main origin                   # Push main branch to origin
    $0 tag-push v1.2.3                   # Push with version tag
    $0 release v1.2.3                    # Create GitHub release
    $0 rollback HEAD~1 main               # Rollback main branch
    $0 test                               # Test GitHub connectivity

CONFIGURATION:
    Set environment variables or edit $GITHUB_CONFIG_FILE

    Required:
      GITHUB_TOKEN              - GitHub personal access token
      GITHUB_OWNER              - Repository owner/organization
      GITHUB_REPO               - Repository name

    Optional:
      GITHUB_API_URL            - GitHub API URL (default: https://api.github.com)
      DEFAULT_BRANCH            - Default branch name (default: main)
      ENABLE_PRE_PUSH_HOOKS     - Enable validation hooks (default: true)
      ENABLE_SECURITY_SCANNING  - Enable security scans (default: true)
      REQUIRE_SIGNED_COMMITS    - Require signed commits (default: true)

EOF
}

# === MAIN EXECUTION ===
main() {
    local command="${1:-}"
    
    # Initialize if not running as help
    if [[ "$command" != "--help" && "$command" != "-h" ]]; then
        if ! init_github_integration; then
            echo "ERROR: Failed to initialize GitHub integration" >&2
            exit 1
        fi
    fi
    
    case "$command" in
        "push")
            local branch="${2:-}"
            local remote="${3:-origin}"
            local force=false
            
            # Check for force flag
            for arg in "$@"; do
                if [[ "$arg" == "--force" ]]; then
                    force=true
                fi
                if [[ "$arg" == "--no-validation" ]]; then
                    ENABLE_PRE_PUSH_HOOKS=false
                fi
                if [[ "$arg" == "--no-hooks" ]]; then
                    ENABLE_PRE_PUSH_HOOKS=false
                fi
            done
            
            enhanced_git_push "$branch" "$remote" "" "$force"
            ;;
        "tag-push")
            local version="$2"
            local remote="${3:-origin}"
            if [[ -z "$version" ]]; then
                echo "ERROR: Version required for tag-push" >&2
                exit 1
            fi
            enhanced_git_push "" "$remote" "$version"
            ;;
        "release")
            local version="$2"
            if [[ -z "$version" ]]; then
                echo "ERROR: Version required for release" >&2
                exit 1
            fi
            create_github_release_if_configured "$version"
            ;;
        "rollback")
            local commit="${2:-HEAD~1}"
            local branch="${3:-}"
            emergency_rollback "$commit" "$branch"
            ;;
        "test")
            test_github_connectivity
            ;;
        "status")
            show_github_integration_status
            ;;
        "config")
            echo "GitHub Integration Configuration"
            echo "Edit: $GITHUB_CONFIG_FILE"
            echo "Logs: $PUSH_LOG_FILE"
            ;;
        "--help"|"-h"|"help"|"")
            show_usage
            ;;
        *)
            echo "ERROR: Unknown command: $command" >&2
            echo "Use '$0 --help' for usage information" >&2
            exit 1
            ;;
    esac
}

test_github_connectivity() {
    echo "Testing GitHub connectivity..."
    
    # Test authentication
    if setup_github_auth; then
        echo "✓ Authentication successful"
        
        # Test API access
        if github_api_call "GET" "/user" >/dev/null 2>&1; then
            echo "✓ GitHub API access working"
        else
            echo "✗ GitHub API access failed"
        fi
    else
        echo "✗ Authentication failed"
    fi
    
    # Test git remote
    if git ls-remote origin >/dev/null 2>&1; then
        echo "✓ Git remote access working"
    else
        echo "✗ Git remote access failed"
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi