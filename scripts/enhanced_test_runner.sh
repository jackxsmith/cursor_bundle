#!/usr/bin/env bash
#
# Enhanced Test Runner with Professional Error Checking
# Comprehensive testing framework with advanced error detection and prevention
#

set -euo pipefail
IFS=$'\n\t'

# Source the professional error checking framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/professional_error_checking.sh" ]]; then
    source "$SCRIPT_DIR/lib/professional_error_checking.sh"
    setup_error_trap "test_cleanup"
else
    echo "ERROR: Professional error checking framework not found" >&2
    exit 1
fi

# === CONFIGURATION ===
readonly TEST_RUNNER_VERSION="1.0.0"
readonly TEST_ROOT_DIR="$(cd "$(dirname "$SCRIPT_DIR")" && pwd)"
readonly TEST_RESULTS_DIR="$TEST_ROOT_DIR/test-results"
readonly TEST_CONFIG_FILE="$TEST_ROOT_DIR/tests/test_config.json"

# Test execution parameters
declare -g TEST_TIMEOUT=300
declare -g MAX_PARALLEL_TESTS=4
declare -g STRICT_MODE=true
declare -g COMPREHENSIVE_MODE=false

# Test tracking
declare -A TEST_SUITE_RESULTS=()
declare -A TEST_EXECUTION_TIMES=()
declare -i TOTAL_TESTS=0
declare -i PASSED_TESTS=0
declare -i FAILED_TESTS=0
declare -i SKIPPED_TESTS=0

# === CLEANUP FUNCTION ===
test_cleanup() {
    log_framework "INFO" "Performing test cleanup" "test_cleanup"
    
    # Kill any remaining test processes
    pkill -f "test_runner_" 2>/dev/null || true
    
    # Clean up temporary test files
    find "$TEST_RESULTS_DIR" -name "*.tmp" -delete 2>/dev/null || true
    
    # Generate final test report
    generate_test_summary
}

# === VALIDATION FUNCTIONS ===
validate_test_environment() {
    log_framework "INFO" "Validating test environment" "validate_test_environment"
    
    # Validate test directory structure
    validate_required_param "TEST_ROOT_DIR" "$TEST_ROOT_DIR" "directory" || return 1
    
    # Ensure test results directory exists
    if ! mkdir -p "$TEST_RESULTS_DIR"; then
        log_framework "ERROR" "Cannot create test results directory: $TEST_RESULTS_DIR" "validate_test_environment"
        return 1
    fi
    
    # Validate required commands
    validate_command_exists "timeout" true || return 1
    validate_command_exists "bash" true || return 1
    
    # Validate disk space for test artifacts
    validate_disk_space "$TEST_RESULTS_DIR" 200 || return 1
    
    log_framework "INFO" "Test environment validation completed" "validate_test_environment"
    return 0
}

validate_test_script() {
    local test_script="$1"
    
    log_framework "DEBUG" "Validating test script: $test_script" "validate_test_script"
    
    # Check if test script exists and is executable
    validate_required_param "test_script" "$test_script" "file" || return 1
    
    if [[ ! -x "$test_script" ]]; then
        log_framework "ERROR" "Test script is not executable: $test_script" "validate_test_script"
        return 1
    fi
    
    # Check bash syntax
    if ! bash -n "$test_script" 2>/dev/null; then
        log_framework "ERROR" "Test script has syntax errors: $test_script" "validate_test_script"
        return 1
    fi
    
    # Validate test script follows naming convention
    local script_name=$(basename "$test_script")
    if [[ ! "$script_name" =~ ^[0-9]{2}-.*\.(sh|py)$ ]]; then
        log_framework "WARN" "Test script does not follow naming convention: $script_name" "validate_test_script"
    fi
    
    log_framework "DEBUG" "Test script validation passed: $test_script" "validate_test_script"
    return 0
}

# === TEST DISCOVERY ===
discover_test_scripts() {
    local test_pattern="${1:-*test*.sh}"
    local search_dir="${2:-$TEST_ROOT_DIR}"
    
    log_framework "INFO" "Discovering test scripts with pattern: $test_pattern" "discover_test_scripts"
    
    local discovered_tests=()
    
    while IFS= read -r -d '' test_script; do
        if validate_test_script "$test_script"; then
            discovered_tests+=("$test_script")
        else
            log_framework "WARN" "Skipping invalid test script: $test_script" "discover_test_scripts"
        fi
    done < <(find "$search_dir" -name "$test_pattern" -type f -print0 2>/dev/null)
    
    if [[ ${#discovered_tests[@]} -eq 0 ]]; then
        log_framework "WARN" "No valid test scripts found with pattern: $test_pattern" "discover_test_scripts"
        return 1
    fi
    
    log_framework "INFO" "Discovered ${#discovered_tests[@]} test scripts" "discover_test_scripts"
    printf '%s\n' "${discovered_tests[@]}"
    return 0
}

# === TEST EXECUTION ===
execute_single_test() {
    local test_script="$1"
    local test_name="$(basename "$test_script" .sh)"
    local test_log="$TEST_RESULTS_DIR/${test_name}_$(date +%Y%m%d_%H%M%S).log"
    
    log_framework "INFO" "Executing test: $test_name" "execute_single_test"
    
    # Record start time
    local start_time=$(date +%s.%N)
    
    # Create isolated environment for test
    local test_env_file=$(mktemp)
    cat > "$test_env_file" << EOF
export TEST_NAME="$test_name"
export TEST_LOG="$test_log"
export TEST_RUNNER_PID=$$
export STRICT_MODE="$STRICT_MODE"
EOF
    
    # Execute test with timeout and error handling
    local test_exit_code=0
    local test_output=""
    
    if command -v timeout >/dev/null 2>&1; then
        test_output=$(timeout "$TEST_TIMEOUT" bash -c "source '$test_env_file' && '$test_script'" 2>&1) || test_exit_code=$?
    else
        test_output=$(bash -c "source '$test_env_file' && '$test_script'" 2>&1) || test_exit_code=$?
    fi
    
    # Calculate execution time
    local end_time=$(date +%s.%N)
    local execution_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    
    # Record results
    TEST_EXECUTION_TIMES["$test_name"]="$execution_time"
    
    # Log test output
    echo "=== Test: $test_name ===" > "$test_log"
    echo "Start Time: $(date -d @"${start_time%.*}" -Iseconds)" >> "$test_log"
    echo "Exit Code: $test_exit_code" >> "$test_log"
    echo "Duration: ${execution_time}s" >> "$test_log"
    echo "=== Output ===" >> "$test_log"
    echo "$test_output" >> "$test_log"
    
    # Clean up
    rm -f "$test_env_file"
    
    # Evaluate results
    case $test_exit_code in
        0)
            TEST_SUITE_RESULTS["$test_name"]="PASSED"
            ((PASSED_TESTS++))
            log_framework "INFO" "Test PASSED: $test_name (${execution_time}s)" "execute_single_test"
            ;;
        124)
            TEST_SUITE_RESULTS["$test_name"]="TIMEOUT"
            ((FAILED_TESTS++))
            log_framework "ERROR" "Test TIMEOUT: $test_name (${TEST_TIMEOUT}s)" "execute_single_test"
            ;;
        2)
            TEST_SUITE_RESULTS["$test_name"]="SKIPPED"
            ((SKIPPED_TESTS++))
            log_framework "INFO" "Test SKIPPED: $test_name" "execute_single_test"
            ;;
        *)
            TEST_SUITE_RESULTS["$test_name"]="FAILED"
            ((FAILED_TESTS++))
            log_framework "ERROR" "Test FAILED: $test_name (exit code: $test_exit_code)" "execute_single_test"
            ;;
    esac
    
    ((TOTAL_TESTS++))
    return $test_exit_code
}

execute_parallel_tests() {
    local tests=("$@")
    local pids=()
    local running_tests=0
    
    log_framework "INFO" "Executing ${#tests[@]} tests in parallel (max: $MAX_PARALLEL_TESTS)" "execute_parallel_tests"
    
    for test in "${tests[@]}"; do
        # Wait if we've reached the parallel limit
        while [[ $running_tests -ge $MAX_PARALLEL_TESTS ]]; do
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[i]}" 2>/dev/null; then
                    wait "${pids[i]}"
                    unset pids[i]
                    ((running_tests--))
                fi
            done
            sleep 0.1
        done
        
        # Start new test in background
        execute_single_test "$test" &
        pids+=($!)
        ((running_tests++))
    done
    
    # Wait for all remaining tests
    for pid in "${pids[@]}"; do
        wait "$pid" || true
    done
    
    log_framework "INFO" "Parallel test execution completed" "execute_parallel_tests"
}

# === COMPREHENSIVE TESTING ===
run_installation_script_tests() {
    log_framework "INFO" "Running comprehensive installation script tests" "run_installation_script_tests"
    
    # Discover all installation scripts
    local install_scripts
    mapfile -t install_scripts < <(find "$TEST_ROOT_DIR" -name "[0-9][0-9]-*.sh" -type f 2>/dev/null | sort)
    
    if [[ ${#install_scripts[@]} -eq 0 ]]; then
        log_framework "WARN" "No installation scripts found for testing" "run_installation_script_tests"
        return 0
    fi
    
    log_framework "INFO" "Testing ${#install_scripts[@]} installation scripts" "run_installation_script_tests"
    
    # Test each script for basic functionality
    for script in "${install_scripts[@]}"; do
        local script_name=$(basename "$script")
        
        # Test help functionality
        local help_test_name="${script_name}_help"
        log_framework "DEBUG" "Testing help functionality: $script_name" "run_installation_script_tests"
        
        local help_output=""
        local help_exit_code=0
        help_output=$("$script" --help 2>&1) || help_exit_code=$?
        
        if [[ $help_exit_code -eq 0 ]]; then
            TEST_SUITE_RESULTS["$help_test_name"]="PASSED"
            ((PASSED_TESTS++))
        else
            TEST_SUITE_RESULTS["$help_test_name"]="FAILED"
            ((FAILED_TESTS++))
            log_framework "ERROR" "Help test failed for: $script_name" "run_installation_script_tests"
        fi
        
        ((TOTAL_TESTS++))
        
        # Test syntax validation
        local syntax_test_name="${script_name}_syntax"
        if bash -n "$script" 2>/dev/null; then
            TEST_SUITE_RESULTS["$syntax_test_name"]="PASSED"
            ((PASSED_TESTS++))
        else
            TEST_SUITE_RESULTS["$syntax_test_name"]="FAILED"
            ((FAILED_TESTS++))
            log_framework "ERROR" "Syntax test failed for: $script_name" "run_installation_script_tests"
        fi
        
        ((TOTAL_TESTS++))
    done
    
    log_framework "INFO" "Installation script tests completed" "run_installation_script_tests"
}

run_gui_script_tests() {
    log_framework "INFO" "Running GUI script tests" "run_gui_script_tests"
    
    # Discover GUI scripts
    local gui_scripts
    mapfile -t gui_scripts < <(find "$TEST_ROOT_DIR" -name "*tkinter*.py" -o -name "*zenity*.sh" -type f 2>/dev/null)
    
    if [[ ${#gui_scripts[@]} -eq 0 ]]; then
        log_framework "WARN" "No GUI scripts found for testing" "run_gui_script_tests"
        return 0
    fi
    
    log_framework "INFO" "Testing ${#gui_scripts[@]} GUI scripts" "run_gui_script_tests"
    
    for script in "${gui_scripts[@]}"; do
        local script_name=$(basename "$script")
        local help_test_name="${script_name}_help"
        
        # Test help functionality (should not open GUI)
        log_framework "DEBUG" "Testing GUI help functionality: $script_name" "run_gui_script_tests"
        
        local help_exit_code=0
        if [[ "$script" =~ \.py$ ]]; then
            python3 "$script" --help >/dev/null 2>&1 || help_exit_code=$?
        else
            "$script" --help >/dev/null 2>&1 || help_exit_code=$?
        fi
        
        if [[ $help_exit_code -eq 0 ]]; then
            TEST_SUITE_RESULTS["$help_test_name"]="PASSED"
            ((PASSED_TESTS++))
        else
            TEST_SUITE_RESULTS["$help_test_name"]="FAILED"
            ((FAILED_TESTS++))
            log_framework "ERROR" "GUI help test failed for: $script_name" "run_gui_script_tests"
        fi
        
        ((TOTAL_TESTS++))
    done
    
    log_framework "INFO" "GUI script tests completed" "run_gui_script_tests"
}

# === REPORTING ===
generate_test_summary() {
    local summary_file="$TEST_RESULTS_DIR/test_summary_$(date +%Y%m%d_%H%M%S).txt"
    
    log_framework "INFO" "Generating test summary report" "generate_test_summary"
    
    cat > "$summary_file" << EOF
# Enhanced Test Runner Summary Report
# Generated: $(date -Iseconds)
# Runner Version: $TEST_RUNNER_VERSION

## Test Execution Summary
- Total Tests: $TOTAL_TESTS
- Passed: $PASSED_TESTS
- Failed: $FAILED_TESTS
- Skipped: $SKIPPED_TESTS
- Success Rate: $(echo "scale=2; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l 2>/dev/null || echo "0")%

## Individual Test Results
EOF
    
    for test_name in "${!TEST_SUITE_RESULTS[@]}"; do
        local result="${TEST_SUITE_RESULTS[$test_name]}"
        local time="${TEST_EXECUTION_TIMES[$test_name]:-0}"
        printf "%-40s %-10s %8ss\n" "$test_name" "$result" "$time" >> "$summary_file"
    done
    
    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo -e "\n## Failed Tests Details" >> "$summary_file"
        for test_name in "${!TEST_SUITE_RESULTS[@]}"; do
            if [[ "${TEST_SUITE_RESULTS[$test_name]}" == "FAILED" ]]; then
                echo "- $test_name" >> "$summary_file"
            fi
        done
    fi
    
    log_framework "INFO" "Test summary generated: $summary_file" "generate_test_summary"
    
    # Display summary to console
    echo
    echo "=== TEST EXECUTION SUMMARY ==="
    echo "Total Tests: $TOTAL_TESTS"
    echo "Passed: $PASSED_TESTS"
    echo "Failed: $FAILED_TESTS"
    echo "Skipped: $SKIPPED_TESTS"
    echo "Success Rate: $(echo "scale=2; $PASSED_TESTS * 100 / $TOTAL_TESTS" | bc -l 2>/dev/null || echo "0")%"
    echo "Report: $summary_file"
    echo
}

# === MAIN EXECUTION ===
show_usage() {
    cat << EOF
Enhanced Test Runner v$TEST_RUNNER_VERSION

USAGE:
    $0 [OPTIONS] [TEST_PATTERN]

OPTIONS:
    --comprehensive     Run comprehensive test suite
    --parallel=N        Set max parallel tests (default: $MAX_PARALLEL_TESTS)
    --timeout=N         Set test timeout in seconds (default: $TEST_TIMEOUT)
    --strict            Enable strict mode (default: $STRICT_MODE)
    --help, -h          Show this help

TEST_PATTERN:
    Pattern to match test files (default: *test*.sh)

EXAMPLES:
    $0                              # Run all tests
    $0 --comprehensive              # Run comprehensive test suite
    $0 "*install*.sh"               # Run installation tests only
    $0 --parallel=8 --timeout=600   # Run with custom settings

EOF
}

main() {
    # Parse arguments
    local test_pattern="*test*.sh"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --comprehensive)
                COMPREHENSIVE_MODE=true
                ;;
            --parallel=*)
                MAX_PARALLEL_TESTS="${1#*=}"
                ;;
            --timeout=*)
                TEST_TIMEOUT="${1#*=}"
                ;;
            --strict)
                STRICT_MODE=true
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                test_pattern="$1"
                ;;
        esac
        shift
    done
    
    log_framework "INFO" "Starting Enhanced Test Runner v$TEST_RUNNER_VERSION"
    
    # Validate environment
    if ! validate_test_environment; then
        log_framework "ERROR" "Test environment validation failed"
        exit 1
    fi
    
    # Run comprehensive test suite if requested
    if [[ "$COMPREHENSIVE_MODE" == "true" ]]; then
        log_framework "INFO" "Running comprehensive test suite"
        
        run_installation_script_tests
        run_gui_script_tests
        
        # Discover and run additional test scripts
        local discovered_tests
        mapfile -t discovered_tests < <(discover_test_scripts "$test_pattern" 2>/dev/null || true)
        
        if [[ ${#discovered_tests[@]} -gt 0 ]]; then
            execute_parallel_tests "${discovered_tests[@]}"
        fi
    else
        # Run standard test discovery and execution
        local test_scripts
        mapfile -t test_scripts < <(discover_test_scripts "$test_pattern")
        
        if [[ ${#test_scripts[@]} -eq 0 ]]; then
            log_framework "ERROR" "No test scripts found with pattern: $test_pattern"
            exit 1
        fi
        
        execute_parallel_tests "${test_scripts[@]}"
    fi
    
    # Generate final report
    generate_test_summary
    
    # Exit with appropriate code
    if [[ $FAILED_TESTS -gt 0 ]]; then
        log_framework "ERROR" "Test execution completed with $FAILED_TESTS failures"
        exit 1
    else
        log_framework "INFO" "All tests completed successfully"
        exit 0
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi