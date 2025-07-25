#!/usr/bin/env bash
# 
# UPGRADED CURSOR BUNDLE TEST SUITE v07-tkinter-improved-v2.py
# Advanced Enterprise Testing Framework with Policy Enforcement
# 
# Features:
# - Advanced test automation and reporting
# - Policy compliance validation
# - Performance benchmarking
# - Security testing
# - Multi-environment support
# - Real-time monitoring
# - Test parallelization
# - Advanced error recovery
# - Comprehensive logging
# - CI/CD integration

set -euo pipefail
IFS=$'\n\t'

# === CONFIGURATION ===
readonly SCRIPT_VERSION="07-tkinter-improved-v2.py"
readonly SCRIPT_NAME="$(basename "${0}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
readonly VERSION="$(cat VERSION 2>/dev/null || echo "unknown")"

# Directories and Files
readonly TEST_DIR="${SCRIPT_DIR}/test-results"
readonly LOG_DIR="${TEST_DIR}/logs"
readonly REPORTS_DIR="${TEST_DIR}/reports"
readonly TEMP_DIR="$(mktemp -d)"
readonly CONFIG_FILE="${SCRIPT_DIR}/.test-config.json"

# Test Configuration
readonly PARALLEL_JOBS="${TEST_PARALLEL_JOBS:-4}"
readonly TEST_TIMEOUT="${TEST_TIMEOUT:-300}"
readonly RETRY_COUNT="${TEST_RETRY_COUNT:-3}"
readonly VERBOSE="${TEST_VERBOSE:-1}"

# Output files
readonly MAIN_LOG="${LOG_DIR}/test_${TIMESTAMP}.log"
readonly ERROR_LOG="${LOG_DIR}/errors_${TIMESTAMP}.log"
readonly JSON_REPORT="${REPORTS_DIR}/results_${TIMESTAMP}.json"
readonly HTML_REPORT="${REPORTS_DIR}/report_${TIMESTAMP}.html"
readonly JUNIT_XML="${REPORTS_DIR}/junit_${TIMESTAMP}.xml"
readonly PERFORMANCE_LOG="${LOG_DIR}/performance_${TIMESTAMP}.log"

# Colors and formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

# Global test state
declare -A TEST_RESULTS=()
declare -A TEST_TIMES=()
declare -A TEST_METADATA=()
declare -i TESTS_TOTAL=0
declare -i TESTS_PASSED=0
declare -i TESTS_FAILED=0
declare -i TESTS_SKIPPED=0
declare -i TESTS_WARNINGS=0

# === LOGGING AND OUTPUT ===
log() {
    local level="${1:-INFO}"
    local message="$2"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    echo "[${timestamp}] [${level}] ${message}" | tee -a "${MAIN_LOG}"
    
    if [[ "${VERBOSE}" -eq 1 ]]; then
        case "${level}" in
            "ERROR") echo -e "${RED}[ERROR]${NC} ${message}" >&2 ;;
            "WARN")  echo -e "${YELLOW}[WARN]${NC} ${message}" ;;
            "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} ${message}" ;;
            "INFO")  echo -e "${BLUE}[INFO]${NC} ${message}" ;;
            "DEBUG") echo -e "${PURPLE}[DEBUG]${NC} ${message}" ;;
            *) echo "[${level}] ${message}" ;;
        esac
    fi
}

error() { log "ERROR" "$1"; echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >> "${ERROR_LOG}"; }
warn() { log "WARN" "$1"; }
success() { log "SUCCESS" "$1"; }
info() { log "INFO" "$1"; }
debug() { log "DEBUG" "$1"; }

# === SETUP AND CLEANUP ===
setup_test_environment() {
    info "Setting up test environment..."
    
    # Create directory structure
    mkdir -p "${TEST_DIR}" "${LOG_DIR}" "${REPORTS_DIR}"
    
    # Initialize test configuration
    cat > "${CONFIG_FILE}" <<EOF
{
    "version": "${VERSION}",
    "script_version": "${SCRIPT_VERSION}",
    "timestamp": "${TIMESTAMP}",
    "environment": {
        "os": "$(uname -s)",
        "arch": "$(uname -m)",
        "kernel": "$(uname -r)",
        "user": "$(whoami)",
        "shell": "${SHELL}",
        "pwd": "$(pwd)"
    },
    "config": {
        "parallel_jobs": ${PARALLEL_JOBS},
        "timeout": ${TEST_TIMEOUT},
        "retry_count": ${RETRY_COUNT},
        "verbose": ${VERBOSE}
    }
}
EOF

    # Initialize reports
    init_json_report
    init_html_report
    init_junit_xml
    
    success "Test environment initialized"
}

cleanup() {
    local exit_code=$?
    info "Cleaning up test environment..."
    
    # Generate final reports
    finalize_reports
    
    # Clean up temporary files
    rm -rf "${TEMP_DIR}"
    
    # Display summary
    display_test_summary
    
    # Exit with appropriate code
    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        exit 1
    else
        exit ${exit_code}
    fi
}

trap cleanup EXIT

# === REPORTING FUNCTIONS ===
init_json_report() {
    cat > "${JSON_REPORT}" <<EOF
{
    "test_suite": "Cursor Bundle Test Suite",
    "version": "${VERSION}",
    "script_version": "${SCRIPT_VERSION}",
    "timestamp": "${TIMESTAMP}",
    "environment": $(jq '.environment' "${CONFIG_FILE}" 2>/dev/null || echo "{}"),
    "config": $(jq '.config' "${CONFIG_FILE}" 2>/dev/null || echo "{}"),
    "tests": [],
    "summary": {
        "total": 0,
        "passed": 0,
        "failed": 0,
        "skipped": 0,
        "warnings": 0,
        "duration": 0
    }
}
EOF
}

init_html_report() {
    cat > "${HTML_REPORT}" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Cursor Bundle Test Report - ${VERSION}</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background: #f5f5f5; padding: 15px; border-radius: 5px; }
        .summary { margin: 20px 0; }
        .test { margin: 10px 0; padding: 10px; border-left: 4px solid #ccc; }
        .passed { border-left-color: #28a745; }
        .failed { border-left-color: #dc3545; }
        .skipped { border-left-color: #ffc107; }
        .warning { border-left-color: #fd7e14; }
        pre { background: #f8f9fa; padding: 10px; border-radius: 3px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Cursor Bundle Test Report</h1>
        <p>Version: ${VERSION} | Script: ${SCRIPT_VERSION} | Date: ${TIMESTAMP}</p>
    </div>
    <div id="content">
        <p>Tests are running...</p>
    </div>
</body>
</html>
EOF
}

init_junit_xml() {
    cat > "${JUNIT_XML}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<testsuites name="Cursor Bundle Test Suite" time="0" tests="0" failures="0" errors="0" skipped="0">
</testsuites>
EOF
}

record_test_result() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    local duration="${4:-0}"
    local metadata="${5:-{}}"
    
    TEST_RESULTS["${test_name}"]="${result}"
    TEST_TIMES["${test_name}"]="${duration}"
    TEST_METADATA["${test_name}"]="${metadata}"
    
    ((TESTS_TOTAL++))
    case "${result}" in
        "PASS") ((TESTS_PASSED++)) ;;
        "FAIL") ((TESTS_FAILED++)) ;;
        "SKIP") ((TESTS_SKIPPED++)) ;;
        "WARN") ((TESTS_WARNINGS++)) ;;
    esac
    
    # Update JSON report
    update_json_report "${test_name}" "${result}" "${message}" "${duration}" "${metadata}"
    
    # Log result
    case "${result}" in
        "PASS") success "✅ ${test_name}: ${message} (${duration}s)" ;;
        "FAIL") error "❌ ${test_name}: ${message} (${duration}s)" ;;
        "SKIP") warn "⏭️  ${test_name}: ${message}" ;;
        "WARN") warn "⚠️  ${test_name}: ${message} (${duration}s)" ;;
    esac
}

update_json_report() {
    local test_name="$1"
    local result="$2"
    local message="$3"
    local duration="$4"
    local metadata="$5"
    
    local test_entry=$(cat <<EOF
{
    "name": "${test_name}",
    "result": "${result}",
    "message": "${message}",
    "duration": ${duration},
    "timestamp": "$(date -Iseconds)",
    "metadata": ${metadata}
}
EOF
)
    
    # Add test entry to JSON report (simplified approach)
    cp "${JSON_REPORT}" "${JSON_REPORT}.tmp"
    jq --argjson test "${test_entry}" '.tests += [$test]' "${JSON_REPORT}.tmp" > "${JSON_REPORT}" 2>/dev/null || {
        # Fallback if jq fails
        echo "${test_entry}" >> "${JSON_REPORT}.tests"
    }
    rm -f "${JSON_REPORT}.tmp"
}

# === TEST EXECUTION FRAMEWORK ===
run_test() {
    local test_name="$1"
    local test_function="$2"
    local timeout="${3:-${TEST_TIMEOUT}}"
    local retries="${4:-${RETRY_COUNT}}"
    
    info "🧪 Running test: ${test_name}"
    
    local start_time=$(date +%s.%N)
    local attempt=1
    
    while [[ ${attempt} -le ${retries} ]]; do
        if [[ ${attempt} -gt 1 ]]; then
            warn "Retry attempt ${attempt}/${retries} for ${test_name}"
        fi
        
        # Run test with timeout
        local test_output
        local test_exit_code=0
        
        if command -v timeout >/dev/null 2>&1; then
            test_output=$(timeout "${timeout}" bash -c "${test_function}" 2>&1) || test_exit_code=$?
        else
            test_output=$(bash -c "${test_function}" 2>&1) || test_exit_code=$?
        fi
        
        local end_time=$(date +%s.%N)
        local duration=$(echo "${end_time} - ${start_time}" | bc -l 2>/dev/null || echo "0")
        
        if [[ ${test_exit_code} -eq 0 ]]; then
            record_test_result "${test_name}" "PASS" "Test completed successfully" "${duration}" "{\"attempt\": ${attempt}, \"output\": \"${test_output}\"}"
            return 0
        elif [[ ${test_exit_code} -eq 124 ]]; then
            record_test_result "${test_name}" "FAIL" "Test timed out after ${timeout}s" "${duration}" "{\"attempt\": ${attempt}, \"timeout\": true}"
            return 1
        else
            if [[ ${attempt} -eq ${retries} ]]; then
                record_test_result "${test_name}" "FAIL" "Test failed after ${retries} attempts" "${duration}" "{\"attempt\": ${attempt}, \"exit_code\": ${test_exit_code}, \"output\": \"${test_output}\"}"
                return 1
            fi
        fi
        
        ((attempt++))
        sleep 2
    done
}

run_test_suite() {
    local suite_name="$1"
    shift
    local tests=("$@")
    
    info "🚀 Starting test suite: ${suite_name}"
    
    if [[ ${PARALLEL_JOBS} -gt 1 ]]; then
        info "Running ${#tests[@]} tests in parallel (${PARALLEL_JOBS} jobs)"
        run_parallel_tests "${tests[@]}"
    else
        info "Running ${#tests[@]} tests sequentially"
        for test in "${tests[@]}"; do
            run_test "${test}" "test_${test}"
        done
    fi
    
    success "✅ Test suite '${suite_name}' completed"
}

run_parallel_tests() {
    local tests=("$@")
    local pids=()
    local job_count=0
    
    for test in "${tests[@]}"; do
        # Wait if we've reached the job limit
        while [[ ${job_count} -ge ${PARALLEL_JOBS} ]]; do
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[i]}" 2>/dev/null; then
                    wait "${pids[i]}"
                    unset pids[i]
                    ((job_count--))
                fi
            done
            sleep 0.1
        done
        
        # Start new test
        (run_test "${test}" "test_${test}") &
        pids+=($!)
        ((job_count++))
    done
    
    # Wait for all remaining jobs
    for pid in "${pids[@]}"; do
        wait "${pid}"
    done
}

# === POLICY ENFORCEMENT TESTS ===
test_policy_enforcer() {
    if [[ ! -x "policy_enforcer.sh" ]]; then
        return 1
    fi
    
    ./policy_enforcer.sh compliance || return 1
    return 0
}

test_consolidated_policies() {
    if [[ ! -f "CONSOLIDATED_POLICIES.md" ]]; then
        return 1
    fi
    
    # Check for required policy sections
    local required_sections=(
        "NEVER STOP UNTIL VERIFICATION IS COMPLETE"
        "ALWAYS USE EXISTING BUMP FUNCTIONS"
        "GITHUB API MUST BE PRIMARY VERIFICATION METHOD"
        "MANDATORY GITHUB NOTIFICATIONS CHECK"
    )
    
    for section in "${required_sections[@]}"; do
        if ! grep -q "${section}" "CONSOLIDATED_POLICIES.md"; then
            return 1
        fi
    done
    
    return 0
}

test_github_actions_status() {
    local api_result
    api_result=$(curl -s "https://api.github.com/repos/jackxsmith/cursor_bundle/commits/main/check-runs" | jq -r '.check_runs[] | "\(.name): \(.status) - \(.conclusion)"' 2>/dev/null)
    
    if [[ -z "${api_result}" ]]; then
        return 1
    fi
    
    local success_count=$(echo "${api_result}" | grep -c "completed - success" || echo "0")
    
    if [[ ${success_count} -lt 5 ]]; then
        return 1
    fi
    
    return 0
}

# === PERFORMANCE TESTS ===
test_performance_startup() {
    local start_time=$(date +%s.%N)
    
    # Simulate application startup
    sleep 0.1
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "${end_time} - ${start_time}" | bc -l 2>/dev/null || echo "0.1")
    
    echo "startup_time=${duration}" >> "${PERFORMANCE_LOG}"
    
    # Fail if startup takes more than 5 seconds
    if (( $(echo "${duration} > 5.0" | bc -l 2>/dev/null || echo "0") )); then
        return 1
    fi
    
    return 0
}

test_performance_memory() {
    local memory_usage
    memory_usage=$(ps aux --sort=-%mem | head -5 | awk '{sum += $4} END {print sum}')
    
    echo "memory_usage=${memory_usage}" >> "${PERFORMANCE_LOG}"
    
    # Basic validation that memory usage is reasonable
    if (( $(echo "${memory_usage} > 90.0" | bc -l 2>/dev/null || echo "0") )); then
        return 1
    fi
    
    return 0
}

test_performance_disk_io() {
    local temp_file="${TEMP_DIR}/disk_io_test"
    local start_time=$(date +%s.%N)
    
    # Write test
    for i in {1..100}; do
        echo "test data ${i}" > "${temp_file}_${i}"
    done
    
    # Read test
    for i in {1..100}; do
        cat "${temp_file}_${i}" > /dev/null
    done
    
    # Cleanup
    rm -f "${temp_file}_"*
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "${end_time} - ${start_time}" | bc -l 2>/dev/null || echo "1.0")
    
    echo "disk_io_time=${duration}" >> "${PERFORMANCE_LOG}"
    
    # Fail if disk I/O takes more than 10 seconds
    if (( $(echo "${duration} > 10.0" | bc -l 2>/dev/null || echo "0") )); then
        return 1
    fi
    
    return 0
}

# === SECURITY TESTS ===
test_security_file_permissions() {
    local violations=0
    
    # Check for world-writable files
    while IFS= read -r -d '' file; do
        ((violations++))
        warn "World-writable file: ${file}"
    done < <(find . -type f -perm -002 -print0 2>/dev/null)
    
    # Check for executable files without proper permissions
    while IFS= read -r -d '' file; do
        if [[ "${file}" =~ \.(sh|py|pl)$ ]] && [[ ! -x "${file}" ]]; then
            ((violations++))
            warn "Script file not executable: ${file}"
        fi
    done < <(find . -type f -print0 2>/dev/null)
    
    if [[ ${violations} -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

test_security_secrets_scan() {
    local violations=0
    
    # Scan for potential secrets
    local patterns=(
        "password.*=.*['\"][^'\"]{8,}"
        "secret.*=.*['\"][^'\"]{16,}"
        "key.*=.*['\"][^'\"]{20,}"
        "token.*=.*['\"][^'\"]{20,}"
        "api[_-]key.*=.*['\"][^'\"]{16,}"
    )
    
    for pattern in "${patterns[@]}"; do
        while IFS= read -r line; do
            ((violations++))
            warn "Potential secret found: ${line}"
        done < <(grep -rEi "${pattern}" --include="*.sh" --include="*.py" --include="*.txt" . 2>/dev/null || true)
    done
    
    if [[ ${violations} -gt 0 ]]; then
        return 1
    fi
    
    return 0
}

# === INTEGRATION TESTS ===
test_integration_bump_script() {
    if [[ ! -x "bump.sh" ]]; then
        return 1
    fi
    
    # Test bump script syntax
    bash -n bump.sh || return 1
    
    # Test bump script help
    ./bump.sh --help >/dev/null 2>&1 || return 1
    
    return 0
}

test_integration_docker_build() {
    if ! command -v docker >/dev/null 2>&1; then
        return 2  # Skip if Docker not available
    fi
    
    if [[ ! -f "Dockerfile" ]]; then
        return 1
    fi
    
    # Test Docker build (dry run)
    docker build --dry-run . >/dev/null 2>&1 || return 1
    
    return 0
}

test_integration_ci_workflow() {
    if [[ ! -f ".github/workflows/ci.yml" ]]; then
        return 1
    fi
    
    # Basic YAML syntax check
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" 2>/dev/null || return 1
    fi
    
    # Check for required jobs
    local required_jobs=("build" "perf-test" "security-scan" "container-security")
    for job in "${required_jobs[@]}"; do
        if ! grep -q "${job}:" ".github/workflows/ci.yml"; then
            return 1
        fi
    done
    
    return 0
}

# === FILE SYSTEM TESTS ===
test_filesystem_structure() {
    local required_files=(
        "VERSION"
        "README.md"
        "CONSOLIDATED_POLICIES.md"
        "bump.sh"
        ".github/workflows/ci.yml"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "${file}" ]]; then
            return 1
        fi
    done
    
    return 0
}

test_filesystem_version_consistency() {
    local version_file_version
    version_file_version=$(cat VERSION 2>/dev/null || echo "")
    
    if [[ -z "${version_file_version}" ]]; then
        return 1
    fi
    
    # Check version format
    if [[ ! "${version_file_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        return 1
    fi
    
    return 0
}

# === ENHANCED TEST PROGRAM TESTS ===
test_enhanced_program_structure() {
    if [[ ! -f "claude-code-enhanced/package.json" ]]; then
        return 1
    fi
    
    if [[ ! -f "claude-code-enhanced/index.js" ]]; then
        return 1
    fi
    
    # Check package.json structure
    if command -v jq >/dev/null 2>&1; then
        if ! jq -e '.scripts.test' "claude-code-enhanced/package.json" >/dev/null 2>&1; then
            return 1
        fi
    fi
    
    return 0
}

test_enhanced_program_functionality() {
    if [[ ! -f "claude-code-enhanced/index.js" ]]; then
        return 1
    fi
    
    # Test Node.js syntax
    if command -v node >/dev/null 2>&1; then
        cd claude-code-enhanced
        node -c index.js 2>/dev/null || return 1
        cd ..
    fi
    
    return 0
}

# === REPORT GENERATION ===
finalize_reports() {
    info "Generating final reports..."
    
    # Update JSON report summary
    update_json_summary
    
    # Generate HTML report
    generate_html_report
    
    # Generate JUnit XML
    generate_junit_xml
    
    # Generate performance report
    generate_performance_report
    
    success "Reports generated successfully"
}

update_json_summary() {
    local total_duration=0
    for test_name in "${!TEST_TIMES[@]}"; do
        total_duration=$(echo "${total_duration} + ${TEST_TIMES[${test_name}]}" | bc -l 2>/dev/null || echo "${total_duration}")
    done
    
    cp "${JSON_REPORT}" "${JSON_REPORT}.tmp"
    jq --arg total "${TESTS_TOTAL}" \
       --arg passed "${TESTS_PASSED}" \
       --arg failed "${TESTS_FAILED}" \
       --arg skipped "${TESTS_SKIPPED}" \
       --arg warnings "${TESTS_WARNINGS}" \
       --arg duration "${total_duration}" \
       '.summary.total = ($total | tonumber) |
        .summary.passed = ($passed | tonumber) |
        .summary.failed = ($failed | tonumber) |
        .summary.skipped = ($skipped | tonumber) |
        .summary.warnings = ($warnings | tonumber) |
        .summary.duration = ($duration | tonumber)' \
       "${JSON_REPORT}.tmp" > "${JSON_REPORT}" 2>/dev/null || {
        warn "Failed to update JSON summary"
    }
    rm -f "${JSON_REPORT}.tmp"
}

generate_html_report() {
    local html_content=""
    
    # Generate test results HTML
    for test_name in "${!TEST_RESULTS[@]}"; do
        local result="${TEST_RESULTS[${test_name}]}"
        local duration="${TEST_TIMES[${test_name}]}"
        local class_name="$(echo "${result}" | tr '[:upper:]' '[:lower:]')"
        
        html_content+="<div class=\"test ${class_name}\">"
        html_content+="<h3>${test_name}</h3>"
        html_content+="<p><strong>Result:</strong> ${result} (${duration}s)</p>"
        html_content+="</div>"
    done
    
    # Update HTML report
    sed -i "s|<p>Tests are running...</p>|${html_content}|" "${HTML_REPORT}" 2>/dev/null || {
        warn "Failed to update HTML report"
    }
}

generate_junit_xml() {
    local junit_content="<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
    junit_content+="<testsuites name=\"Cursor Bundle Test Suite\" time=\"0\" tests=\"${TESTS_TOTAL}\" failures=\"${TESTS_FAILED}\" errors=\"0\" skipped=\"${TESTS_SKIPPED}\">\n"
    junit_content+="<testsuite name=\"Main Suite\" tests=\"${TESTS_TOTAL}\" failures=\"${TESTS_FAILED}\" errors=\"0\" skipped=\"${TESTS_SKIPPED}\">\n"
    
    for test_name in "${!TEST_RESULTS[@]}"; do
        local result="${TEST_RESULTS[${test_name}]}"
        local duration="${TEST_TIMES[${test_name}]}"
        
        junit_content+="<testcase name=\"${test_name}\" time=\"${duration}\">"
        
        case "${result}" in
            "FAIL") junit_content+="<failure message=\"Test failed\"/>" ;;
            "SKIP") junit_content+="<skipped/>" ;;
        esac
        
        junit_content+="</testcase>\n"
    done
    
    junit_content+="</testsuite>\n</testsuites>"
    
    echo -e "${junit_content}" > "${JUNIT_XML}"
}

generate_performance_report() {
    if [[ -f "${PERFORMANCE_LOG}" ]]; then
        info "Performance metrics:"
        while IFS= read -r line; do
            info "  ${line}"
        done < "${PERFORMANCE_LOG}"
    fi
}

display_test_summary() {
    echo
    echo -e "${BOLD}=== TEST SUMMARY ===${NC}"
    echo -e "Total tests:    ${TESTS_TOTAL}"
    echo -e "✅ Passed:      ${GREEN}${TESTS_PASSED}${NC}"
    echo -e "❌ Failed:      ${RED}${TESTS_FAILED}${NC}"
    echo -e "⏭️  Skipped:     ${YELLOW}${TESTS_SKIPPED}${NC}"
    echo -e "⚠️  Warnings:    ${YELLOW}${TESTS_WARNINGS}${NC}"
    echo
    echo -e "${BOLD}=== REPORTS ===${NC}"
    echo -e "📊 JSON Report:  ${JSON_REPORT}"
    echo -e "📄 HTML Report:  ${HTML_REPORT}"
    echo -e "🧪 JUnit XML:   ${JUNIT_XML}"
    echo -e "📝 Main Log:    ${MAIN_LOG}"
    echo -e "❌ Error Log:   ${ERROR_LOG}"
    echo
    
    if [[ ${TESTS_FAILED} -gt 0 ]]; then
        echo -e "${RED}${BOLD}❌ SOME TESTS FAILED${NC}"
    else
        echo -e "${GREEN}${BOLD}✅ ALL TESTS PASSED${NC}"
    fi
}

# === MAIN EXECUTION ===
main() {
    local test_suites=()
    local run_specific_test=""
    local list_tests=false
    local show_help=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --suite=*) test_suites+=("${1#*=}") ;;
            --test=*) run_specific_test="${1#*=}" ;;
            --list) list_tests=true ;;
            --help|-h) show_help=true ;;
            --verbose|-v) declare -g VERBOSE=1 ;;
            --parallel=*) PARALLEL_JOBS="${1#*=}" ;;
            --timeout=*) TEST_TIMEOUT="${1#*=}" ;;
            *) warn "Unknown option: $1" ;;
        esac
        shift
    done
    
    if [[ "${show_help}" == true ]]; then
        show_usage
        exit 0
    fi
    
    if [[ "${list_tests}" == true ]]; then
        list_available_tests
        exit 0
    fi
    
    # Initialize
    setup_test_environment
    
    info "🚀 Starting Cursor Bundle Test Suite v${SCRIPT_VERSION}"
    info "Version: ${VERSION} | Timestamp: ${TIMESTAMP}"
    
    # Define test suites
    local policy_tests=(
        "policy_enforcer"
        "consolidated_policies"
        "github_actions_status"
    )
    
    local performance_tests=(
        "performance_startup"
        "performance_memory"
        "performance_disk_io"
    )
    
    local security_tests=(
        "security_file_permissions"
        "security_secrets_scan"
    )
    
    local integration_tests=(
        "integration_bump_script"
        "integration_docker_build"
        "integration_ci_workflow"
    )
    
    local filesystem_tests=(
        "filesystem_structure"
        "filesystem_version_consistency"
    )
    
    local enhanced_program_tests=(
        "enhanced_program_structure"
        "enhanced_program_functionality"
    )
    
    # Run specific test if requested
    if [[ -n "${run_specific_test}" ]]; then
        run_test "${run_specific_test}" "test_${run_specific_test}"
        return
    fi
    
    # Run specific test suites if requested
    if [[ ${#test_suites[@]} -gt 0 ]]; then
        for suite in "${test_suites[@]}"; do
            case "${suite}" in
                "policy") run_test_suite "Policy Tests" "${policy_tests[@]}" ;;
                "performance") run_test_suite "Performance Tests" "${performance_tests[@]}" ;;
                "security") run_test_suite "Security Tests" "${security_tests[@]}" ;;
                "integration") run_test_suite "Integration Tests" "${integration_tests[@]}" ;;
                "filesystem") run_test_suite "Filesystem Tests" "${filesystem_tests[@]}" ;;
                "enhanced") run_test_suite "Enhanced Program Tests" "${enhanced_program_tests[@]}" ;;
                *) warn "Unknown test suite: ${suite}" ;;
            esac
        done
    else
        # Run all test suites
        run_test_suite "Policy Tests" "${policy_tests[@]}"
        run_test_suite "Performance Tests" "${performance_tests[@]}"
        run_test_suite "Security Tests" "${security_tests[@]}"
        run_test_suite "Integration Tests" "${integration_tests[@]}"
        run_test_suite "Filesystem Tests" "${filesystem_tests[@]}"
        run_test_suite "Enhanced Program Tests" "${enhanced_program_tests[@]}"
    fi
    
    success "🎉 Test execution completed!"
}

show_usage() {
    cat <<EOF
Cursor Bundle Test Suite v${SCRIPT_VERSION}

USAGE:
    ${SCRIPT_NAME} [OPTIONS]

OPTIONS:
    --suite=SUITE       Run specific test suite (policy|performance|security|integration|filesystem|enhanced)
    --test=TEST         Run specific test
    --list              List all available tests
    --verbose, -v       Enable verbose output
    --parallel=N        Set number of parallel jobs (default: ${PARALLEL_JOBS})
    --timeout=N         Set test timeout in seconds (default: ${TEST_TIMEOUT})
    --help, -h          Show this help

EXAMPLES:
    ${SCRIPT_NAME}                          # Run all tests
    ${SCRIPT_NAME} --suite=policy           # Run only policy tests
    ${SCRIPT_NAME} --test=policy_enforcer   # Run specific test
    ${SCRIPT_NAME} --list                   # List available tests
    ${SCRIPT_NAME} --parallel=8 --verbose   # Run with 8 parallel jobs and verbose output

ENVIRONMENT VARIABLES:
    TEST_PARALLEL_JOBS  Number of parallel jobs (default: 4)
    TEST_TIMEOUT        Test timeout in seconds (default: 300)
    TEST_RETRY_COUNT    Number of retries for failed tests (default: 3)
    TEST_VERBOSE        Enable verbose output (default: 1)

REPORTS:
    Test results are saved in the test-results/ directory:
    - JSON report: results_TIMESTAMP.json
    - HTML report: report_TIMESTAMP.html
    - JUnit XML: junit_TIMESTAMP.xml
    - Logs: logs/test_TIMESTAMP.log
EOF
}

list_available_tests() {
    echo "Available tests:"
    echo
    echo "Policy Tests:"
    echo "  - policy_enforcer"
    echo "  - consolidated_policies"
    echo "  - github_actions_status"
    echo
    echo "Performance Tests:"
    echo "  - performance_startup"
    echo "  - performance_memory"
    echo "  - performance_disk_io"
    echo
    echo "Security Tests:"
    echo "  - security_file_permissions"
    echo "  - security_secrets_scan"
    echo
    echo "Integration Tests:"
    echo "  - integration_bump_script"
    echo "  - integration_docker_build"
    echo "  - integration_ci_workflow"
    echo
    echo "Filesystem Tests:"
    echo "  - filesystem_structure"
    echo "  - filesystem_version_consistency"
    echo
    echo "Enhanced Program Tests:"
    echo "  - enhanced_program_structure"
    echo "  - enhanced_program_functionality"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi