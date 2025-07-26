#!/bin/bash
# Pre-push validation system to prevent policy violations

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Running pre-push validation...${NC}"

# Function to check for secrets
check_secrets() {
    echo "Checking for secrets..."
    
    # Common secret patterns
    local patterns=(
        "ghp_[a-zA-Z0-9]{36}"  # GitHub Personal Access Token
        "ghs_[a-zA-Z0-9]{36}"  # GitHub Secret
        "github_pat_[a-zA-Z0-9]{22}_[a-zA-Z0-9]{59}"  # New GitHub PAT format
        "AKIA[0-9A-Z]{16}"     # AWS Access Key
        "(?i)api[_-]?key.*[:=].*['\"][a-zA-Z0-9]{20,}['\"]"  # Generic API keys
        "(?i)password.*[:=].*['\"][^'\"]{8,}['\"]"  # Passwords
    )
    
    local found_secrets=0
    
    # Check staged files
    for pattern in "${patterns[@]}"; do
        if git diff --cached --name-only | xargs -I {} git show :{} 2>/dev/null | grep -E "$pattern" > /dev/null 2>&1; then
            echo -e "${RED}ERROR: Potential secret found matching pattern: $pattern${NC}"
            found_secrets=1
        fi
    done
    
    # Check all commits being pushed
    local remote="$1"
    local url="$2"
    
    while read local_ref local_sha remote_ref remote_sha; do
        if [ "$local_sha" != "0000000000000000000000000000000000000000" ]; then
            # Get list of commits
            if [ "$remote_sha" = "0000000000000000000000000000000000000000" ]; then
                # New branch
                commits=$(git rev-list "$local_sha" --not --remotes="$remote")
            else
                # Existing branch
                commits=$(git rev-list "$remote_sha..$local_sha")
            fi
            
            # Check each commit
            for commit in $commits; do
                for pattern in "${patterns[@]}"; do
                    if git show "$commit" | grep -E "$pattern" > /dev/null 2>&1; then
                        echo -e "${RED}ERROR: Secret found in commit $commit${NC}"
                        git show --name-only --oneline "$commit"
                        found_secrets=1
                    fi
                done
            done
        fi
    done
    
    return $found_secrets
}

# Function to validate branch names
validate_branch_names() {
    echo "Validating branch names..."
    
    local invalid_branches=()
    
    while read local_ref local_sha remote_ref remote_sha; do
        local branch_name=$(echo "$remote_ref" | sed 's|refs/heads/||')
        
        # Check for valid branch name patterns
        if ! echo "$branch_name" | grep -E '^(main|master|develop|release/v[0-9]+\.[0-9]+\.[0-9]+|feature/.+|bugfix/.+|hotfix/.+)$' > /dev/null; then
            invalid_branches+=("$branch_name")
        fi
    done
    
    if [ ${#invalid_branches[@]} -gt 0 ]; then
        echo -e "${RED}ERROR: Invalid branch names detected:${NC}"
        printf '%s\n' "${invalid_branches[@]}"
        echo -e "${YELLOW}Valid patterns: main, master, develop, release/vX.Y.Z, feature/*, bugfix/*, hotfix/*${NC}"
        return 1
    fi
    
    return 0
}

# Function to check file permissions
check_file_permissions() {
    echo "Checking file permissions..."
    
    local issues=0
    
    # Check for files with overly permissive permissions
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            perms=$(stat -c %a "$file" 2>/dev/null || stat -f %p "$file" 2>/dev/null | cut -c 3-5)
            if [ "$perms" = "777" ] || [ "$perms" = "666" ]; then
                echo -e "${YELLOW}WARNING: File '$file' has overly permissive permissions: $perms${NC}"
                issues=1
            fi
        fi
    done < <(git diff --cached --name-only)
    
    return $issues
}

# Function to check commit messages
check_commit_messages() {
    echo "Checking commit messages..."
    
    local remote="$1"
    local url="$2"
    local invalid_commits=()
    
    while read local_ref local_sha remote_ref remote_sha; do
        if [ "$local_sha" != "0000000000000000000000000000000000000000" ]; then
            # Get list of commits
            if [ "$remote_sha" = "0000000000000000000000000000000000000000" ]; then
                commits=$(git rev-list "$local_sha" --not --remotes="$remote")
            else
                commits=$(git rev-list "$remote_sha..$local_sha")
            fi
            
            # Check each commit message
            for commit in $commits; do
                msg=$(git log --format=%s -n 1 "$commit")
                
                # Check for conventional commit format
                if ! echo "$msg" | grep -E '^(feat|fix|docs|style|refactor|test|chore|build|ci|perf|revert)(\(.+\))?: .+' > /dev/null; then
                    invalid_commits+=("$commit: $msg")
                fi
            done
        fi
    done
    
    if [ ${#invalid_commits[@]} -gt 0 ]; then
        echo -e "${YELLOW}WARNING: Non-conventional commit messages found:${NC}"
        printf '%s\n' "${invalid_commits[@]}"
        echo -e "${YELLOW}Format: type(scope)?: description${NC}"
    fi
    
    return 0
}

# Main validation
main() {
    local remote="$1"
    local url="$2"
    local errors=0
    
    # Run all checks
    check_secrets "$remote" "$url" || errors=$((errors + 1))
    validate_branch_names || errors=$((errors + 1))
    check_file_permissions || true  # Just warnings
    check_commit_messages "$remote" "$url" || true  # Just warnings
    
    if [ $errors -gt 0 ]; then
        echo -e "${RED}❌ Pre-push validation failed!${NC}"
        echo -e "${YELLOW}To bypass (not recommended): git push --no-verify${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All validation checks passed!${NC}"
    exit 0
}

# Check if being run as a git hook
if [ -n "${GIT_DIR:-}" ]; then
    # Read stdin for hook parameters
    while read local_ref local_sha remote_ref remote_sha; do
        main "$1" "$2"
    done
else
    # Manual run
    echo "This script should be run as a Git pre-push hook"
    echo "To install: ln -s $(pwd)/$0 .git/hooks/pre-push"
    exit 1
fi