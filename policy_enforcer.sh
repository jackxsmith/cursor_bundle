#!/usr/bin/env bash
# policy_enforcer.sh - Automated Policy Violation Prevention System
# 
# This script prevents all known policy violations by enforcing mandatory checks
# and stopping execution if any violations are detected.

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}❌ POLICY VIOLATION: $1${NC}" >&2
}

warn() {
    echo -e "${YELLOW}⚠️  POLICY WARNING: $1${NC}" >&2
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# LESSON 1: NEVER STOP VERIFICATION POLICY
enforce_verification_policy() {
    log "🔍 ENFORCING: Never stop until verification complete"
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log "Verification attempt $attempt/$max_attempts"
        
        # Check GitHub API status
        local api_result
        api_result=$(curl -s "https://api.github.com/repos/jackxsmith/cursor_bundle/commits/main/check-runs" | jq -r '.check_runs[] | "\(.name): \(.status) - \(.conclusion)"' 2>/dev/null || echo "API_ERROR")
        
        if [[ "$api_result" == "API_ERROR" ]]; then
            warn "GitHub API unreachable, continuing verification..."
            ((attempt++))
            sleep 30
            continue
        fi
        
        local success_count=$(echo "$api_result" | grep -c "completed - success" || echo "0")
        local in_progress_count=$(echo "$api_result" | grep -c "in_progress" || echo "0")
        local total_count=$(echo "$api_result" | wc -l)
        
        # Remove any newlines/whitespace from counts
        success_count=$(echo "$success_count" | tr -d '\n\r ')
        in_progress_count=$(echo "$in_progress_count" | tr -d '\n\r ')
        total_count=$(echo "$total_count" | tr -d '\n\r ')
        
        log "Status: $success_count successful, $in_progress_count in progress, $total_count total"
        echo "$api_result"
        
        # Success condition: All jobs completed successfully
        if [[ $success_count -ge 5 ]] && [[ $in_progress_count -eq 0 ]]; then
            success "All 5 GitHub Actions jobs completed successfully!"
            return 0
        fi
        
        # If no jobs are running and we don't have 5 successes, something is wrong
        if [[ $in_progress_count -eq 0 ]] && [[ $success_count -lt 5 ]]; then
            error "No jobs in progress but only $success_count/5 successful"
            return 1
        fi
        
        log "Waiting 30 seconds before next verification..."
        sleep 30
        ((attempt++))
    done
    
    error "Verification failed after $max_attempts attempts"
    return 1
}

# LESSON 2: MANDATORY VERSION BUMPING POLICY
enforce_bump_policy() {
    log "🔍 ENFORCING: Always use existing bump functions"
    
    # Check if VERSION file was manually edited (look for actual bump commits)
    local recent_version_changes=$(git log -5 --oneline -- VERSION | grep "feat: bump to" | wc -l)
    local recent_commits=$(git log -5 --oneline | wc -l)
    
    # If VERSION was changed recently and no bump commits found, it's a violation
    if git diff HEAD~3 VERSION | grep -q "^+[0-9]" && [[ $recent_version_changes -eq 0 ]]; then
        error "VERSION file was manually edited without using bump script"
        error "Use ./bump.sh <version> instead"
        return 1
    fi
    
    # Check if bump.sh exists and is executable
    if [[ ! -x "./bump.sh" ]]; then
        error "bump.sh not found or not executable"
        return 1
    fi
    
    success "Version bump policy compliance verified"
    return 0
}

# LESSON 3: GITHUB API PRIMARY VERIFICATION
enforce_api_verification_policy() {
    log "🔍 ENFORCING: GitHub API as primary verification method"
    
    # Ensure jq is available
    if ! command -v jq >/dev/null 2>&1; then
        error "jq is required for API verification but not installed"
        return 1
    fi
    
    # Ensure curl is available
    if ! command -v curl >/dev/null 2>&1; then
        error "curl is required for API verification but not installed"
        return 1
    fi
    
    success "API verification tools available"
    return 0
}

# LESSON 10: NOTIFICATION MONITORING POLICY
enforce_notifications_policy() {
    log "🔍 ENFORCING: GitHub notifications check required"
    
    echo
    echo "📬 MANDATORY POLICY REQUIREMENT:"
    echo "🔗 You must check: https://github.com/notifications"
    echo "⚠️  This is a manual verification step that cannot be automated"
    echo "📋 Look for any notifications related to cursor_bundle repository"
    echo
    
    success "Notifications policy reminder displayed"
    return 0
}

# LESSON 6: POLICY DOCUMENTATION CONSOLIDATION
enforce_policy_consolidation() {
    log "🔍 ENFORCING: Single source of truth for policies"
    
    # Check for deprecated policy files
    local deprecated_files=(
        "VERIFICATION_POLICY.md"
        "LESSONS_LEARNED_POLICY.md"
    )
    
    local violations=0
    for file in "${deprecated_files[@]}"; do
        if [[ -f "$file" ]]; then
            error "Deprecated policy file exists: $file"
            error "All policies must be in CONSOLIDATED_POLICIES.md"
            ((violations++))
        fi
    done
    
    if [[ $violations -gt 0 ]]; then
        return 1
    fi
    
    success "Policy consolidation verified"
    return 0
}

# NEW: LESSON 11 - POLICY VIOLATION PREVENTION SYSTEM
enforce_continuous_compliance() {
    log "🔍 ENFORCING: Continuous compliance monitoring"
    
    # Log this enforcement run
    local log_file="policy-enforcement.log"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] Policy enforcement run started" >> "$log_file"
    
    # Count total violations
    local total_violations=0
    
    # Run all policy checks
    log "Running comprehensive policy compliance check..."
    
    if ! enforce_bump_policy; then ((total_violations++)); fi
    if ! enforce_api_verification_policy; then ((total_violations++)); fi
    if ! enforce_policy_consolidation; then ((total_violations++)); fi
    
    # Always run these (they don't fail, just inform)
    enforce_notifications_policy
    
    if [[ $total_violations -gt 0 ]]; then
        error "$total_violations policy violations detected"
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] $total_violations violations detected" >> "$log_file"
        return 1
    fi
    
    success "All policy compliance checks passed"
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] All policies compliant" >> "$log_file"
    return 0
}

# Main enforcement function
main() {
    echo
    log "🛡️  POLICY ENFORCEMENT SYSTEM ACTIVATED"
    echo "======================================================"
    
    local start_time=$(date +%s)
    
    # Run continuous compliance first
    if ! enforce_continuous_compliance; then
        error "Policy compliance check failed - stopping execution"
        exit 1
    fi
    
    # Run verification loop (MOST IMPORTANT - NEVER SKIP THIS)
    log "🔄 Starting mandatory verification loop..."
    if ! enforce_verification_policy; then
        error "Verification policy enforcement failed"
        exit 1
    fi
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo
    success "🛡️  ALL POLICIES SUCCESSFULLY ENFORCED"
    log "⏱️  Total enforcement time: ${duration}s"
    echo "======================================================"
    echo
}

# Handle command line arguments
case "${1:-main}" in
    "verify")
        enforce_verification_policy
        ;;
    "bump")
        enforce_bump_policy
        ;;
    "api")
        enforce_api_verification_policy
        ;;
    "notifications")
        enforce_notifications_policy
        ;;
    "compliance")
        enforce_continuous_compliance
        ;;
    "main"|"")
        main
        ;;
    *)
        echo "Usage: $0 [verify|bump|api|notifications|compliance]"
        echo "  verify       - Run verification policy enforcement"
        echo "  bump         - Check version bump policy compliance"
        echo "  api          - Verify API verification tools"
        echo "  notifications - Display notifications policy reminder"
        echo "  compliance   - Run all compliance checks"
        echo "  (no args)    - Run full policy enforcement"
        exit 1
        ;;
esac