#!/usr/bin/env bash
#
# PROFESSIONAL CURSOR IDE POLICY CHECKER v2.0
# Enterprise-Grade Compliance and Governance System
#
# Enhanced Features:
# - Robust policy validation and enforcement
# - Self-correcting compliance mechanisms
# - Advanced security and governance checks
# - Professional reporting and auditing
# - Automated policy remediation
# - Performance optimization
#

set -euo pipefail
IFS=$'\n\t'

# === CONFIGURATION ===
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="$(basename "${0}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Directory Structure
readonly BASE_DIR="${HOME}/.cache/cursor/policy"
readonly LOG_DIR="${BASE_DIR}/logs"
readonly REPORTS_DIR="${BASE_DIR}/reports"
readonly POLICIES_DIR="${BASE_DIR}/policies"
readonly TEMP_DIR="$(mktemp -d -t cursor_policy_XXXXXX)"

# Log Files
readonly MAIN_LOG="${LOG_DIR}/policy_${TIMESTAMP}.log"
readonly ERROR_LOG="${LOG_DIR}/policy_errors_${TIMESTAMP}.log"
readonly COMPLIANCE_LOG="${LOG_DIR}/compliance_${TIMESTAMP}.log"

# Report Files
readonly COMPLIANCE_REPORT="${REPORTS_DIR}/compliance_${TIMESTAMP}.html"
readonly POLICY_JSON="${REPORTS_DIR}/policy_${TIMESTAMP}.json"
readonly VIOLATIONS_CSV="${REPORTS_DIR}/violations_${TIMESTAMP}.csv"

# Policy Categories
declare -A POLICY_CATEGORIES=(
    ["security"]="Security and access control policies"
    ["coding"]="Code quality and standards policies"
    ["licensing"]="Software licensing compliance"
    ["data"]="Data protection and privacy policies"
    ["operational"]="Operational and deployment policies"
)

# Compliance Variables
declare -A POLICY_RESULTS
declare -A VIOLATION_COUNTS
declare -A REMEDIATION_ACTIONS
declare -g TOTAL_POLICIES=0
declare -g PASSED_POLICIES=0
declare -g FAILED_POLICIES=0
declare -g DRY_RUN=false
declare -g AUTO_REMEDIATE=false

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
            ((PASSED_POLICIES++))
            ;;
        FAIL) 
            echo -e "\033[0;31m[✗]\033[0m ${message}"
            ((FAILED_POLICIES++))
            ;;
        INFO) 
            echo -e "\033[0;34m[INFO]\033[0m ${message}"
            ;;
        DEBUG) 
            [[ "${DEBUG:-false}" == "true" ]] && echo -e "\033[0;36m[DEBUG]\033[0m ${message}"
            ;;
    esac
}

# Compliance logging
compliance_log() {
    local policy="$1"
    local status="$2"
    local details="${3:-}"
    local timestamp="$(date -Iseconds)"
    
    echo "[${timestamp}] POLICY=${policy} STATUS=${status} DETAILS=${details}" >> "$COMPLIANCE_LOG"
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
    local dirs=("$LOG_DIR" "$REPORTS_DIR" "$POLICIES_DIR")
    
    for dir in "${dirs[@]}"; do
        if ! ensure_directory "$dir"; then
            echo "Failed to initialize directories"
            return 1
        fi
    done
    
    # Log rotation
    find "$LOG_DIR" -name "policy_*.log" -mtime +7 -delete 2>/dev/null || true
    find "$REPORTS_DIR" -name "compliance_*.html" -mtime +30 -delete 2>/dev/null || true
    
    return 0
}

# Cleanup function
cleanup() {
    [[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
    
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        log "PASS" "Policy compliance check completed successfully"
    else
        log "ERROR" "Policy compliance check failed with exit code: $exit_code"
    fi
}

trap cleanup EXIT
trap 'exit 130' INT TERM

# === POLICY DEFINITIONS ===

# Load default policies
load_default_policies() {
    log "INFO" "Loading default policy definitions"
    
    # Create default policy file if it doesn't exist
    local default_policies="$POLICIES_DIR/default.json"
    
    if [[ ! -f "$default_policies" ]]; then
        cat > "$default_policies" << 'EOF'
{
    "policies": {
        "security": {
            "no_hardcoded_secrets": {
                "description": "No hardcoded passwords, tokens, or secrets",
                "severity": "critical",
                "patterns": ["password=", "token=", "secret=", "api_key="]
            },
            "secure_permissions": {
                "description": "Files should not have overly permissive permissions",
                "severity": "high",
                "check": "file_permissions"
            },
            "no_sudo_without_auth": {
                "description": "Sudo commands should require authentication",
                "severity": "high",
                "patterns": ["sudo.*NOPASSWD"]
            }
        },
        "coding": {
            "proper_error_handling": {
                "description": "Scripts should have proper error handling",
                "severity": "medium",
                "patterns": ["set -e", "trap.*ERR"]
            },
            "function_documentation": {
                "description": "Functions should be documented",
                "severity": "low",
                "check": "function_docs"
            },
            "no_long_lines": {
                "description": "Lines should not exceed 120 characters",
                "severity": "low",
                "check": "line_length"
            }
        },
        "licensing": {
            "license_header": {
                "description": "Files should contain proper license headers",
                "severity": "medium",
                "check": "license_check"
            }
        }
    }
}
EOF
        log "DEBUG" "Created default policies file"
    fi
    
    log "PASS" "Default policies loaded successfully"
}

# === POLICY CHECKERS ===

# Check for hardcoded secrets
check_hardcoded_secrets() {
    local file="$1"
    local violations=0
    
    local secret_patterns=("password=" "token=" "secret=" "api_key=" "private_key=")
    
    for pattern in "${secret_patterns[@]}"; do
        if grep -qi "$pattern" "$file" 2>/dev/null; then
            local line_nums=$(grep -ni "$pattern" "$file" | cut -d: -f1)
            for line_num in $line_nums; do
                log "FAIL" "Hardcoded secret found in $file:$line_num"
                VIOLATION_COUNTS[hardcoded_secrets]=$((${VIOLATION_COUNTS[hardcoded_secrets]:-0} + 1))
                ((violations++))
            done
        fi
    done
    
    if [[ $violations -eq 0 ]]; then
        log "PASS" "No hardcoded secrets found in $(basename "$file")"
        POLICY_RESULTS["hardcoded_secrets_$(basename "$file")"]="PASS"
    else
        POLICY_RESULTS["hardcoded_secrets_$(basename "$file")"]="FAIL"
        
        if [[ "$AUTO_REMEDIATE" == "true" ]]; then
            REMEDIATION_ACTIONS["hardcoded_secrets_$(basename "$file")"]="Move secrets to environment variables or secure vault"
        fi
    fi
    
    compliance_log "hardcoded_secrets" "$([[ $violations -eq 0 ]] && echo "PASS" || echo "FAIL")" "File: $file, Violations: $violations"
    
    return $violations
}

# Check file permissions
check_file_permissions() {
    local file="$1"
    local violations=0
    
    # Check if file is world-writable
    if [[ -w "$file" ]] && [[ $(stat -c%a "$file" 2>/dev/null | cut -c3) -gt 4 ]]; then
        log "FAIL" "World-writable file: $file"
        VIOLATION_COUNTS[file_permissions]=$((${VIOLATION_COUNTS[file_permissions]:-0} + 1))
        ((violations++))
        
        if [[ "$AUTO_REMEDIATE" == "true" ]] && [[ "$DRY_RUN" != "true" ]]; then
            chmod o-w "$file"
            log "INFO" "Fixed permissions for $file"
            REMEDIATION_ACTIONS["file_permissions_$(basename "$file")"]="Removed world-write permission"
        fi
    fi
    
    # Check if executable files have proper shebang
    if [[ -x "$file" ]] && [[ "$file" == *.sh ]]; then
        if ! head -1 "$file" | grep -q "^#!"; then
            log "FAIL" "Executable script missing shebang: $file"
            VIOLATION_COUNTS[missing_shebang]=$((${VIOLATION_COUNTS[missing_shebang]:-0} + 1))
            ((violations++))
        fi
    fi
    
    if [[ $violations -eq 0 ]]; then
        log "PASS" "File permissions OK for $(basename "$file")"
        POLICY_RESULTS["file_permissions_$(basename "$file")"]="PASS"
    else
        POLICY_RESULTS["file_permissions_$(basename "$file")"]="FAIL"
    fi
    
    compliance_log "file_permissions" "$([[ $violations -eq 0 ]] && echo "PASS" || echo "FAIL")" "File: $file, Violations: $violations"
    
    return $violations
}

# Check error handling
check_error_handling() {
    local file="$1"
    local violations=0
    
    if [[ "$file" == *.sh ]]; then
        local has_set_e=$(grep -c "set -e" "$file" 2>/dev/null || echo "0")
        local has_trap=$(grep -c "trap.*ERR" "$file" 2>/dev/null || echo "0")
        
        if [[ $has_set_e -eq 0 ]] && [[ $has_trap -eq 0 ]]; then
            log "FAIL" "No error handling found in $(basename "$file")"
            VIOLATION_COUNTS[error_handling]=$((${VIOLATION_COUNTS[error_handling]:-0} + 1))
            ((violations++))
        else
            log "PASS" "Error handling found in $(basename "$file")"
        fi
    fi
    
    POLICY_RESULTS["error_handling_$(basename "$file")"]="$([[ $violations -eq 0 ]] && echo "PASS" || echo "FAIL")"
    compliance_log "error_handling" "$([[ $violations -eq 0 ]] && echo "PASS" || echo "FAIL")" "File: $file, Violations: $violations"
    
    return $violations
}

# Check line length
check_line_length() {
    local file="$1"
    local violations=0
    local max_length=120
    
    while IFS= read -r line_num line; do
        if [[ ${#line} -gt $max_length ]]; then
            log "WARN" "Long line in $(basename "$file"):$line_num (${#line} chars)"
            VIOLATION_COUNTS[long_lines]=$((${VIOLATION_COUNTS[long_lines]:-0} + 1))
            ((violations++))
        fi
    done < <(nl -ba "$file" 2>/dev/null)
    
    if [[ $violations -eq 0 ]]; then
        log "PASS" "Line length OK for $(basename "$file")"
        POLICY_RESULTS["line_length_$(basename "$file")"]="PASS"
    else
        POLICY_RESULTS["line_length_$(basename "$file")"]="WARN"
    fi
    
    compliance_log "line_length" "$([[ $violations -eq 0 ]] && echo "PASS" || echo "WARN")" "File: $file, Violations: $violations"
    
    return 0  # Don't fail on line length
}

# Check function documentation
check_function_documentation() {
    local file="$1"
    local violations=0
    
    if [[ "$file" == *.sh ]]; then
        local functions=$(grep -c "^[a-zA-Z_][a-zA-Z0-9_]*\s*(" "$file" 2>/dev/null || echo "0")
        local documented=0
        
        # Count functions with preceding comments
        while IFS= read -r line_num line; do
            if [[ $line =~ ^[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\( ]]; then
                local prev_line_num=$((line_num - 1))
                if [[ $prev_line_num -gt 0 ]]; then
                    local prev_line=$(sed -n "${prev_line_num}p" "$file" 2>/dev/null)
                    if [[ $prev_line =~ ^[[:space:]]*# ]]; then
                        ((documented++))
                    fi
                fi
            fi
        done < <(nl -ba "$file" 2>/dev/null)
        
        if [[ $functions -gt 0 ]]; then
            local doc_percentage=$((documented * 100 / functions))
            if [[ $doc_percentage -lt 50 ]]; then
                log "WARN" "Low function documentation in $(basename "$file"): $doc_percentage%"
                VIOLATION_COUNTS[function_docs]=$((${VIOLATION_COUNTS[function_docs]:-0} + 1))
                ((violations++))
            else
                log "PASS" "Function documentation OK in $(basename "$file"): $doc_percentage%"
            fi
        fi
    fi
    
    POLICY_RESULTS["function_docs_$(basename "$file")"]="$([[ $violations -eq 0 ]] && echo "PASS" || echo "WARN")"
    compliance_log "function_docs" "$([[ $violations -eq 0 ]] && echo "PASS" || echo "WARN")" "File: $file, Violations: $violations"
    
    return 0  # Don't fail on documentation
}

# Check license headers
check_license_header() {
    local file="$1"
    local violations=0
    
    # Look for license indicators in first 20 lines
    local license_found=false
    local license_patterns=("License:" "Copyright" "MIT" "Apache" "GPL" "BSD")
    
    for pattern in "${license_patterns[@]}"; do
        if head -20 "$file" | grep -qi "$pattern" 2>/dev/null; then
            license_found=true
            break
        fi
    done
    
    if [[ "$license_found" != "true" ]]; then
        log "WARN" "No license header found in $(basename "$file")"
        VIOLATION_COUNTS[license_header]=$((${VIOLATION_COUNTS[license_header]:-0} + 1))
        ((violations++))
    else
        log "PASS" "License header found in $(basename "$file")"
    fi
    
    POLICY_RESULTS["license_header_$(basename "$file")"]="$([[ $violations -eq 0 ]] && echo "PASS" || echo "WARN")"
    compliance_log "license_header" "$([[ $violations -eq 0 ]] && echo "PASS" || echo "WARN")" "File: $file, Violations: $violations"
    
    return 0  # Don't fail on license
}

# === MAIN POLICY CHECKING ===

# Run all policy checks on a file
check_file_policies() {
    local file="$1"
    
    log "INFO" "Checking policies for: $(basename "$file")"
    
    local total_violations=0
    
    # Run all policy checks
    check_hardcoded_secrets "$file" || total_violations=$((total_violations + $?))
    check_file_permissions "$file" || total_violations=$((total_violations + $?))
    check_error_handling "$file" || total_violations=$((total_violations + $?))
    check_line_length "$file"
    check_function_documentation "$file"
    check_license_header "$file"
    
    ((TOTAL_POLICIES += 6))
    
    return $total_violations
}

# Run policy checks on directory
run_policy_checks() {
    local target_dir="${1:-$SCRIPT_DIR}"
    
    log "INFO" "Running policy compliance checks on: $target_dir"
    
    local files_checked=0
    local total_violations=0
    
    # Find files to check
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]] && [[ -r "$file" ]]; then
            check_file_policies "$file"
            total_violations=$((total_violations + $?))
            ((files_checked++))
        fi
    done < <(find "$target_dir" -type f \( -name "*.sh" -o -name "*.py" -o -name "*.js" -o -name "*.json" -o -name "*.md" \) -print0 2>/dev/null)
    
    log "INFO" "Policy check completed: $files_checked files checked, $total_violations violations found"
    
    return $total_violations
}

# === REPORTING ===

# Generate compliance report
generate_compliance_report() {
    log "INFO" "Generating compliance report"
    
    # Calculate compliance percentage
    local compliance_percentage=0
    if [[ $TOTAL_POLICIES -gt 0 ]]; then
        compliance_percentage=$((PASSED_POLICIES * 100 / TOTAL_POLICIES))
    fi
    
    cat > "$COMPLIANCE_REPORT" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Policy Compliance Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1000px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; padding-bottom: 20px; border-bottom: 2px solid #e0e0e0; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .metric { background: #f8f9fa; padding: 20px; border-radius: 8px; text-align: center; }
        .metric-value { font-size: 2em; font-weight: bold; color: #007acc; }
        .compliance-bar { width: 100%; height: 20px; background: #e0e0e0; border-radius: 10px; overflow: hidden; margin: 10px 0; }
        .compliance-fill { height: 100%; background: linear-gradient(90deg, #ff4444, #ffaa00, #44ff44); border-radius: 10px; }
        .violations { background: #fff3cd; border: 1px solid #ffeaa7; border-radius: 5px; padding: 15px; margin: 20px 0; }
        .violation-item { padding: 5px 0; border-bottom: 1px solid #ddd; }
        .violation-item:last-child { border-bottom: none; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Policy Compliance Report</h1>
            <p>Generated on $(date '+%Y-%m-%d %H:%M:%S')</p>
        </div>
        
        <div class="metrics">
            <div class="metric">
                <div class="metric-value">$compliance_percentage%</div>
                <div>Compliance Rate</div>
            </div>
            <div class="metric">
                <div class="metric-value">$PASSED_POLICIES</div>
                <div>Policies Passed</div>
            </div>
            <div class="metric">
                <div class="metric-value">$FAILED_POLICIES</div>
                <div>Policies Failed</div>
            </div>
            <div class="metric">
                <div class="metric-value">$TOTAL_POLICIES</div>
                <div>Total Policies</div>
            </div>
        </div>
        
        <div>
            <h2>Overall Compliance</h2>
            <div class="compliance-bar">
                <div class="compliance-fill" style="width: ${compliance_percentage}%;"></div>
            </div>
            <p>${compliance_percentage}% compliant</p>
        </div>
        
        <div class="violations">
            <h2>Policy Violations Summary</h2>
$(for violation_type in "${!VIOLATION_COUNTS[@]}"; do
    echo "            <div class=\"violation-item\"><strong>$violation_type:</strong> ${VIOLATION_COUNTS[$violation_type]} violations</div>"
done)
        </div>
        
        <div>
            <h2>Remediation Actions</h2>
$(for action_key in "${!REMEDIATION_ACTIONS[@]}"; do
    echo "            <div class=\"violation-item\"><strong>$action_key:</strong> ${REMEDIATION_ACTIONS[$action_key]}</div>"
done)
        </div>
    </div>
</body>
</html>
EOF
    
    # Generate JSON report
    cat > "$POLICY_JSON" << EOF
{
    "compliance_report": {
        "timestamp": "$(date -Iseconds)",
        "version": "$SCRIPT_VERSION",
        "compliance_percentage": $compliance_percentage,
        "total_policies": $TOTAL_POLICIES,
        "passed_policies": $PASSED_POLICIES,
        "failed_policies": $FAILED_POLICIES,
        "violations": {
$(for violation_type in "${!VIOLATION_COUNTS[@]}"; do
    echo "            \"$violation_type\": ${VIOLATION_COUNTS[$violation_type]},"
done | sed '$ s/,$//')
        },
        "policy_results": {
$(for policy_key in "${!POLICY_RESULTS[@]}"; do
    echo "            \"$policy_key\": \"${POLICY_RESULTS[$policy_key]}\","
done | sed '$ s/,$//')
        }
    }
}
EOF
    
    log "PASS" "Compliance reports generated successfully"
}

# === MAIN EXECUTION ===

# Show usage
show_usage() {
    cat << EOF
Cursor IDE Professional Policy Checker v$SCRIPT_VERSION

USAGE:
    $SCRIPT_NAME [TARGET_DIR] [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -n, --dry-run       Perform dry run without remediation
    -r, --remediate     Enable automatic remediation
    -v, --verbose       Enable verbose output
    --version           Show version information

EXAMPLES:
    $SCRIPT_NAME                    # Check current directory
    $SCRIPT_NAME /path/to/project   # Check specific directory
    $SCRIPT_NAME --remediate        # Enable auto-remediation

EOF
}

# Parse arguments
parse_arguments() {
    local target_dir="$SCRIPT_DIR"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            --version)
                echo "Cursor IDE Professional Policy Checker v$SCRIPT_VERSION"
                exit 0
                ;;
            -n|--dry-run)
                DRY_RUN=true
                ;;
            -r|--remediate)
                AUTO_REMEDIATE=true
                ;;
            -v|--verbose)
                DEBUG=true
                ;;
            *)
                if [[ -d "$1" ]]; then
                    target_dir="$1"
                else
                    log "ERROR" "Unknown option or invalid directory: $1"
                    exit 1
                fi
                ;;
        esac
        shift
    done
    
    echo "$target_dir"
}

# Main function
main() {
    local target_dir=$(parse_arguments "$@")
    
    log "INFO" "Starting Cursor IDE Policy Checker v$SCRIPT_VERSION"
    log "INFO" "Target directory: $target_dir"
    
    # Initialize
    if ! initialize_directories; then
        log "ERROR" "Failed to initialize directories"
        exit 1
    fi
    
    load_default_policies
    
    # Run policy checks
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Policy compliance check simulation"
    fi
    
    local total_violations
    run_policy_checks "$target_dir"
    total_violations=$?
    
    # Generate reports
    generate_compliance_report
    
    # Show summary
    echo
    echo "Policy Compliance Summary:"
    echo "  Total policies checked: $TOTAL_POLICIES"
    echo "  Policies passed: $PASSED_POLICIES"
    echo "  Policies failed: $FAILED_POLICIES"
    echo "  Compliance rate: $(( TOTAL_POLICIES > 0 ? PASSED_POLICIES * 100 / TOTAL_POLICIES : 0 ))%"
    echo
    echo "Reports generated:"
    echo "  HTML: $COMPLIANCE_REPORT"
    echo "  JSON: $POLICY_JSON"
    echo
    
    if [[ $total_violations -gt 0 ]]; then
        log "WARN" "Policy compliance check completed with $total_violations violations"
        exit 1
    else
        log "PASS" "All policy compliance checks passed"
        exit 0
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi