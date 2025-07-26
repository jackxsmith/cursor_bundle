#!/bin/bash
# Policy Compliance System - Main Script
# Validates repository against security and compliance policies

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_DIR="${SCRIPT_DIR}/logs/policy-compliance"
readonly POLICY_CONFIG="${SCRIPT_DIR}/policy-config.json"
readonly COMPLIANCE_LOG="${LOG_DIR}/compliance-$(date +%Y%m%d-%H%M%S).log"
readonly VIOLATIONS_LOG="${LOG_DIR}/violations.log"
readonly AUDIT_LOG="${LOG_DIR}/audit.log"

# Create log directory
mkdir -p "$LOG_DIR"

# Colors for terminal output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Initialize logs
{
    echo "==================================================="
    echo "Policy Compliance Check - $(date -Iseconds)"
    echo "==================================================="
    echo "Repository: $(git config --get remote.origin.url || echo 'Unknown')"
    echo "Branch: $(git branch --show-current || echo 'Unknown')"
    echo "User: $(git config --get user.name || echo 'Unknown')"
    echo "==================================================="
} | tee "$COMPLIANCE_LOG"

# Function to log messages
log() {
    local level="$1"
    local message="$2"
    local timestamp="$(date -Iseconds)"
    
    echo "[${timestamp}] [${level}] ${message}" | tee -a "$COMPLIANCE_LOG"
    
    if [ "$level" = "VIOLATION" ] || [ "$level" = "ERROR" ]; then
        echo "[${timestamp}] [${level}] ${message}" >> "$VIOLATIONS_LOG"
    fi
    
    # Audit trail for all checks
    echo "[${timestamp}] [${level}] ${message}" >> "$AUDIT_LOG"
}

# Function to check for secrets in repository
check_secrets() {
    log "INFO" "Starting secret scanning..."
    
    local violations=0
    local files_scanned=0
    
    # Define secret patterns
    local -a patterns=(
        "ghp_[a-zA-Z0-9]{36}|GitHub Personal Access Token"
        "ghs_[a-zA-Z0-9]{36}|GitHub Secret"
        "github_pat_[a-zA-Z0-9]{22}_[a-zA-Z0-9]{59}|GitHub PAT (new format)"
        "AKIA[0-9A-Z]{16}|AWS Access Key ID"
        "aws_secret_access_key.*=.*[A-Za-z0-9/+=]{40}|AWS Secret Key"
        "api[_-]?key.*[:=].*['\"][a-zA-Z0-9]{20,}['\"]|Generic API Key"
        "-----BEGIN (RSA|DSA|EC|OPENSSH) PRIVATE KEY-----|Private Key"
        "password.*[:=].*['\"][^'\"]{8,}['\"]|Hardcoded Password"
        "bearer [a-zA-Z0-9_\\-\\.=]+|Bearer Token"
        "basic [a-zA-Z0-9_\\-\\.=]+|Basic Auth"
    )
    
    # Scan all tracked files
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            ((files_scanned++))
            
            for pattern_desc in "${patterns[@]}"; do
                IFS='|' read -r pattern description <<< "$pattern_desc"
                
                if grep -E "$pattern" "$file" > /dev/null 2>&1; then
                    log "VIOLATION" "Secret detected: $description in file: $file"
                    ((violations++))
                    
                    # Log line numbers
                    grep -n -E "$pattern" "$file" | while IFS= read -r line; do
                        log "DETAIL" "  Line: $line"
                    done
                fi
            done
        fi
    done < <(git ls-files)
    
    log "INFO" "Secret scanning complete. Files scanned: $files_scanned, Violations: $violations"
    return $violations
}

# Function to validate branch protection
check_branch_protection() {
    log "INFO" "Checking branch protection rules..."
    
    local current_branch="$(git branch --show-current)"
    local violations=0
    
    # Check if on protected branch
    if [[ "$current_branch" =~ ^(main|master)$ ]]; then
        # Check for direct commits (should use PRs)
        local direct_commits=$(git log origin/"$current_branch"..HEAD --oneline 2>/dev/null | wc -l)
        
        if [ "$direct_commits" -gt 0 ]; then
            log "WARNING" "Direct commits to protected branch '$current_branch': $direct_commits commits pending"
        fi
    fi
    
    # Validate branch naming conventions
    if ! [[ "$current_branch" =~ ^(main|master|develop|release/v[0-9]+\.[0-9]+\.[0-9]+|feature/.+|bugfix/.+|hotfix/.+)$ ]]; then
        log "VIOLATION" "Invalid branch name: '$current_branch' does not follow naming convention"
        ((violations++))
    fi
    
    return $violations
}

# Function to check commit signatures
check_commit_signatures() {
    log "INFO" "Checking commit signatures..."
    
    local unsigned_commits=0
    local total_commits=0
    
    # Check last 10 commits
    while IFS= read -r commit; do
        ((total_commits++))
        
        if ! git verify-commit "$commit" &>/dev/null; then
            ((unsigned_commits++))
            local commit_info=$(git log --oneline -n 1 "$commit")
            log "WARNING" "Unsigned commit: $commit_info"
        fi
    done < <(git log --format=%H -n 10 2>/dev/null)
    
    if [ "$unsigned_commits" -gt 0 ]; then
        log "INFO" "Commit signature check: $unsigned_commits/$total_commits commits are unsigned"
    else
        log "INFO" "All recent commits are signed"
    fi
    
    return 0
}

# Function to check file permissions
check_file_permissions() {
    log "INFO" "Checking file permissions..."
    
    local violations=0
    
    while IFS= read -r file; do
        if [ -f "$file" ]; then
            local perms=$(stat -c %a "$file" 2>/dev/null || stat -f %p "$file" 2>/dev/null | cut -c 3-5)
            
            # Check for world-writable files
            if [[ "$perms" =~ [0-9][0-9][267] ]]; then
                log "VIOLATION" "World-writable file detected: $file (permissions: $perms)"
                ((violations++))
            fi
            
            # Check for overly permissive files
            if [ "$perms" = "777" ]; then
                log "VIOLATION" "File with 777 permissions: $file"
                ((violations++))
            fi
        fi
    done < <(git ls-files)
    
    log "INFO" "File permission check complete. Violations: $violations"
    return $violations
}

# Function to check for sensitive file patterns
check_sensitive_files() {
    log "INFO" "Checking for sensitive files..."
    
    local violations=0
    local -a sensitive_patterns=(
        ".env$|Environment file"
        ".env.local$|Local environment file"
        ".env.*.local$|Environment file with secrets"
        "private_key|Private key file"
        "secret|Secret file"
        ".pem$|Certificate file"
        ".key$|Key file"
        "password|Password file"
        "credentials|Credentials file"
        ".pfx$|Certificate file"
        ".p12$|Certificate file"
    )
    
    for pattern_desc in "${sensitive_patterns[@]}"; do
        IFS='|' read -r pattern description <<< "$pattern_desc"
        
        while IFS= read -r file; do
            if [ -f "$file" ]; then
                log "VIOLATION" "Sensitive file pattern detected: $description - $file"
                ((violations++))
            fi
        done < <(git ls-files | grep -E "$pattern" || true)
    done
    
    log "INFO" "Sensitive file check complete. Violations: $violations"
    return $violations
}

# Function to generate compliance report
generate_report() {
    local total_violations="$1"
    local report_file="${LOG_DIR}/compliance-report-$(date +%Y%m%d-%H%M%S).json"
    
    cat > "$report_file" << EOF
{
  "timestamp": "$(date -Iseconds)",
  "repository": "$(git config --get remote.origin.url || echo 'Unknown')",
  "branch": "$(git branch --show-current || echo 'Unknown')",
  "commit": "$(git rev-parse HEAD || echo 'Unknown')",
  "user": "$(git config --get user.name || echo 'Unknown')",
  "violations": $total_violations,
  "compliance_status": $([ "$total_violations" -eq 0 ] && echo '"PASSED"' || echo '"FAILED"'),
  "log_file": "$COMPLIANCE_LOG",
  "violations_log": "$VIOLATIONS_LOG"
}
EOF
    
    log "INFO" "Compliance report generated: $report_file"
    echo -e "${BLUE}Compliance report: $report_file${NC}"
}

# Main execution
main() {
    local total_violations=0
    
    echo -e "${BLUE}Starting Policy Compliance Check...${NC}"
    
    # Run all checks
    check_secrets || total_violations=$((total_violations + $?))
    check_branch_protection || total_violations=$((total_violations + $?))
    check_commit_signatures || true  # Warnings only
    check_file_permissions || total_violations=$((total_violations + $?))
    check_sensitive_files || total_violations=$((total_violations + $?))
    
    # Generate report
    generate_report "$total_violations"
    
    # Summary
    echo ""
    if [ "$total_violations" -eq 0 ]; then
        log "SUCCESS" "✅ All policy compliance checks passed!"
        echo -e "${GREEN}✅ All policy compliance checks passed!${NC}"
        exit 0
    else
        log "FAILURE" "❌ Policy compliance check failed with $total_violations violations"
        echo -e "${RED}❌ Policy compliance check failed with $total_violations violations${NC}"
        echo -e "${YELLOW}Check the violations log: $VIOLATIONS_LOG${NC}"
        exit 1
    fi
}

# Run main function
main "$@"