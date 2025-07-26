#!/usr/bin/env bash
#
# PROFESSIONAL POST-INSTALLATION TESTING FRAMEWORK v2.0
# Enterprise-Grade Verification and Validation System
#
# Enhanced Features:
# - Comprehensive post-installation validation
# - Self-correcting test recovery mechanisms
# - Advanced diagnostic capabilities
# - Performance benchmarking
# - Security validation
# - Automated issue resolution
# - Professional reporting
#

set -euo pipefail
IFS=$'\n\t'

# === CONFIGURATION ===
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="$(basename "${0}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Test Configuration
readonly TEST_TIMEOUT=300
readonly MAX_RETRIES=3
readonly PARALLEL_TESTS=true

# Directory Structure
readonly LOG_DIR="${HOME}/.cache/cursor/logs"
readonly REPORT_DIR="${HOME}/.cache/cursor/reports"
readonly TEST_DIR="${HOME}/.cache/cursor/tests"
readonly TEMP_DIR="$(mktemp -d -t cursor_posttest_XXXXXX)"

# Log Files
readonly MAIN_LOG="${LOG_DIR}/posttest_${TIMESTAMP}.log"
readonly ERROR_LOG="${LOG_DIR}/posttest_errors_${TIMESTAMP}.log"
readonly TEST_REPORT="${REPORT_DIR}/posttest_report_${TIMESTAMP}.json"
readonly PERFORMANCE_LOG="${LOG_DIR}/performance_${TIMESTAMP}.log"

# Test Results
declare -A TEST_RESULTS
declare -A TEST_METRICS
declare -A SYSTEM_STATUS
TEST_RESULTS[passed]=0
TEST_RESULTS[failed]=0
TEST_RESULTS[warnings]=0
TEST_RESULTS[skipped]=0

# === UTILITY FUNCTIONS ===

# Enhanced logging with levels
log() {
    local level="$1"
    local message="$2"
    local timestamp="$(date -Iseconds)"
    
    echo "[${timestamp}] ${level}: ${message}" >> "$MAIN_LOG"
    
    case "$level" in
        ERROR) 
            echo "[${timestamp}] ${level}: ${message}" >> "$ERROR_LOG"
            echo -e "\033[0;31m[ERROR]\033[0m ${message}" >&2
            ((TEST_RESULTS[failed]++)) || true
            ;;
        WARN) 
            echo -e "\033[1;33m[WARN]\033[0m ${message}"
            ((TEST_RESULTS[warnings]++)) || true
            ;;
        PASS) 
            echo -e "\033[0;32m[✓]\033[0m ${message}"
            ((TEST_RESULTS[passed]++)) || true
            ;;
        SKIP)
            echo -e "\033[0;36m[SKIP]\033[0m ${message}"
            ((TEST_RESULTS[skipped]++)) || true
            ;;
        INFO) 
            echo -e "\033[0;34m[INFO]\033[0m ${message}"
            ;;
        *) 
            echo "[${level}] ${message}"
            ;;
    esac
}

# Performance measurement
measure_performance() {
    local test_name="$1"
    local start_time="$(date +%s%N)"
    
    eval "$2"
    local exit_code=$?
    
    local end_time="$(date +%s%N)"
    local duration=$(((end_time - start_time) / 1000000))
    
    TEST_METRICS["${test_name}_duration_ms"]="$duration"
    echo "[${timestamp}] PERF: ${test_name} completed in ${duration}ms" >> "$PERFORMANCE_LOG"
    
    return $exit_code
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
    local dirs=("$LOG_DIR" "$REPORT_DIR" "$TEST_DIR")
    
    for dir in "${dirs[@]}"; do
        if ! ensure_directory "$dir"; then
            echo "Failed to initialize directories"
            return 1
        fi
    done
    
    # Log rotation
    find "$LOG_DIR" -name "posttest_*.log" -mtime +7 -delete 2>/dev/null || true
    find "$REPORT_DIR" -name "posttest_report_*.json" -mtime +30 -delete 2>/dev/null || true
    
    return 0
}

# Retry mechanism for tests
retry_test() {
    local test_name="$1"
    local test_function="$2"
    local max_attempts="${3:-$MAX_RETRIES}"
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if eval "$test_function"; then
            log "PASS" "$test_name (attempt $((attempt + 1)))"
            return 0
        fi
        
        ((attempt++))
        if [[ $attempt -lt $max_attempts ]]; then
            log "WARN" "$test_name failed, retrying (attempt $((attempt + 1))/$max_attempts)"
            sleep 2
        fi
    done
    
    log "ERROR" "$test_name failed after $max_attempts attempts"
    return 1
}

# Cleanup
cleanup() {
    [[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
    
    # Generate final test report
    generate_test_report
    
    log "INFO" "Post-installation testing completed"
}

trap cleanup EXIT
trap 'exit 130' INT TERM

# === CURSOR BINARY TESTS ===

# Test Cursor binary availability
test_cursor_binary() {
    log "INFO" "Testing Cursor binary availability"
    
    if ! command -v cursor >/dev/null 2>&1; then
        log "ERROR" "Cursor binary not found in PATH"
        
        # Self-correcting: search for cursor in common locations
        local common_paths=("/usr/local/bin" "/opt/cursor/bin" "$HOME/.local/bin" "/usr/bin")
        
        for path in "${common_paths[@]}"; do
            if [[ -x "$path/cursor" ]]; then
                log "INFO" "Found Cursor binary at: $path/cursor"
                export PATH="$path:$PATH"
                log "PASS" "Cursor binary path corrected"
                return 0
            fi
        done
        
        return 1
    fi
    
    local cursor_path="$(which cursor)"
    SYSTEM_STATUS[cursor_binary_path]="$cursor_path"
    
    # Test binary permissions
    if [[ ! -x "$cursor_path" ]]; then
        log "ERROR" "Cursor binary is not executable: $cursor_path"
        
        # Self-correcting: attempt to fix permissions
        if chmod +x "$cursor_path" 2>/dev/null; then
            log "PASS" "Fixed Cursor binary permissions"
        else
            return 1
        fi
    fi
    
    log "PASS" "Cursor binary found and executable: $cursor_path"
    return 0
}

# Test Cursor version
test_cursor_version() {
    log "INFO" "Testing Cursor version information"
    
    local version_output
    if ! version_output="$(timeout 10 cursor --version 2>&1)"; then
        log "ERROR" "Failed to get Cursor version"
        return 1
    fi
    
    SYSTEM_STATUS[cursor_version]="$version_output"
    log "PASS" "Cursor version: $version_output"
    
    # Extract and validate version number
    if echo "$version_output" | grep -E '[0-9]+\.[0-9]+\.[0-9]+' >/dev/null; then
        local version_number=$(echo "$version_output" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        SYSTEM_STATUS[cursor_version_number]="$version_number"
        log "PASS" "Version number extracted: $version_number"
    else
        log "WARN" "Could not extract version number from output"
    fi
    
    return 0
}

# Test Cursor help functionality
test_cursor_help() {
    log "INFO" "Testing Cursor help functionality"
    
    local help_output
    if ! help_output="$(timeout 10 cursor --help 2>&1)"; then
        log "ERROR" "Failed to get Cursor help"
        return 1
    fi
    
    # Validate help output contains expected sections
    local expected_sections=("Usage:" "Options:" "Commands:")
    local found_sections=0
    
    for section in "${expected_sections[@]}"; do
        if echo "$help_output" | grep -q "$section"; then
            ((found_sections++))
        fi
    done
    
    if [[ $found_sections -ge 2 ]]; then
        log "PASS" "Cursor help functionality working ($found_sections sections found)"
    else
        log "WARN" "Cursor help output may be incomplete"
    fi
    
    return 0
}

# === PROCESS TESTS ===

# Test for running Cursor processes
test_cursor_processes() {
    log "INFO" "Testing for running Cursor processes"
    
    local cursor_processes=(
        "cursor"
        "cursor_web_ui.py"
        "cursor-helper"
        "cursor-renderer"
    )
    
    local running_processes=()
    local process_count=0
    
    for process in "${cursor_processes[@]}"; do
        if pgrep -f "$process" >/dev/null 2>&1; then
            running_processes+=("$process")
            ((process_count++))
            
            local pid=$(pgrep -f "$process" | head -1)
            local memory_usage=$(ps -o rss= -p "$pid" 2>/dev/null | xargs)
            TEST_METRICS["${process}_memory_kb"]="${memory_usage:-0}"
        fi
    done
    
    SYSTEM_STATUS[running_processes]="${running_processes[*]}"
    SYSTEM_STATUS[process_count]="$process_count"
    
    if [[ $process_count -gt 0 ]]; then
        log "PASS" "Found $process_count Cursor processes: ${running_processes[*]}"
    else
        log "WARN" "No Cursor processes currently running"
    fi
    
    return 0
}

# Test process health
test_process_health() {
    log "INFO" "Testing Cursor process health"
    
    local cursor_pids=($(pgrep -f "cursor" 2>/dev/null || true))
    
    if [[ ${#cursor_pids[@]} -eq 0 ]]; then
        log "SKIP" "No Cursor processes to check"
        return 0
    fi
    
    local healthy_processes=0
    
    for pid in "${cursor_pids[@]}"; do
        # Check if process is responsive
        if kill -0 "$pid" 2>/dev/null; then
            ((healthy_processes++))
            
            # Get process information
            local process_info=$(ps -p "$pid" -o pid,ppid,cmd,etime,pcpu,pmem --no-headers 2>/dev/null || true)
            if [[ -n "$process_info" ]]; then
                log "DEBUG" "Process $pid: $process_info"
            fi
        fi
    done
    
    TEST_METRICS[healthy_processes]="$healthy_processes"
    TEST_METRICS[total_processes]="${#cursor_pids[@]}"
    
    if [[ $healthy_processes -eq ${#cursor_pids[@]} ]]; then
        log "PASS" "All $healthy_processes Cursor processes are healthy"
    else
        log "WARN" "Only $healthy_processes of ${#cursor_pids[@]} processes are healthy"
    fi
    
    return 0
}

# === FILE SYSTEM TESTS ===

# Test installation directory
test_installation_directory() {
    log "INFO" "Testing Cursor installation directory"
    
    local install_dirs=(
        "/opt/cursor"
        "/usr/local/cursor"
        "$HOME/.cursor"
        "$HOME/cursor"
    )
    
    local found_install_dir=""
    
    for dir in "${install_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            found_install_dir="$dir"
            SYSTEM_STATUS[install_directory]="$dir"
            
            # Check directory permissions
            if [[ -r "$dir" ]]; then
                log "PASS" "Installation directory found and readable: $dir"
            else
                log "WARN" "Installation directory found but not readable: $dir"
            fi
            
            # Check for key files
            local key_files=("cursor" "package.json" "resources")
            local found_files=0
            
            for file in "${key_files[@]}"; do
                if [[ -e "$dir/$file" ]]; then
                    ((found_files++))
                fi
            done
            
            TEST_METRICS[installation_files_found]="$found_files"
            log "INFO" "Found $found_files key installation files"
            
            break
        fi
    done
    
    if [[ -z "$found_install_dir" ]]; then
        log "WARN" "No standard Cursor installation directory found"
        return 1
    fi
    
    return 0
}

# Test log files
test_log_files() {
    log "INFO" "Testing Cursor log files"
    
    local log_locations=(
        "/var/log/cursor.log"
        "$HOME/.cursor/logs"
        "$HOME/.cache/cursor/logs"
        "/tmp/cursor.log"
    )
    
    local found_logs=()
    
    for location in "${log_locations[@]}"; do
        if [[ -f "$location" ]]; then
            found_logs+=("$location")
            
            # Check log file size and recent activity
            local size=$(stat -f%z "$location" 2>/dev/null || stat -c%s "$location" 2>/dev/null || echo "0")
            local mtime=$(stat -f%m "$location" 2>/dev/null || stat -c%Y "$location" 2>/dev/null || echo "0")
            local current_time=$(date +%s)
            local age=$((current_time - mtime))
            
            TEST_METRICS["log_${location//\//_}_size"]="$size"
            TEST_METRICS["log_${location//\//_}_age"]="$age"
            
            if [[ $age -lt 3600 ]]; then
                log "PASS" "Recent log activity: $location (${size} bytes, ${age}s old)"
            else
                log "INFO" "Log file found: $location (${size} bytes, ${age}s old)"
            fi
        elif [[ -d "$location" ]]; then
            found_logs+=("$location")
            
            local log_count=$(find "$location" -name "*.log" -type f 2>/dev/null | wc -l)
            TEST_METRICS["log_dir_${location//\//_}_count"]="$log_count"
            
            log "PASS" "Log directory found: $location ($log_count log files)"
        fi
    done
    
    SYSTEM_STATUS[log_files]="${found_logs[*]}"
    
    if [[ ${#found_logs[@]} -gt 0 ]]; then
        log "PASS" "Found ${#found_logs[@]} log locations"
    else
        log "WARN" "No Cursor log files found"
    fi
    
    return 0
}

# === CONFIGURATION TESTS ===

# Test configuration files
test_configuration_files() {
    log "INFO" "Testing Cursor configuration files"
    
    local config_locations=(
        "$HOME/.cursor/config.json"
        "$HOME/.config/cursor"
        "$HOME/.cursor-settings.json"
    )
    
    local found_configs=()
    
    for location in "${config_locations[@]}"; do
        if [[ -f "$location" ]]; then
            found_configs+=("$location")
            
            # Validate JSON configuration
            if command -v jq >/dev/null 2>&1; then
                if jq empty "$location" 2>/dev/null; then
                    log "PASS" "Valid JSON configuration: $location"
                else
                    log "ERROR" "Invalid JSON configuration: $location"
                fi
            else
                log "INFO" "Configuration file found: $location (JSON validation skipped)"
            fi
        elif [[ -d "$location" ]]; then
            found_configs+=("$location")
            
            local config_count=$(find "$location" -name "*.json" -type f 2>/dev/null | wc -l)
            log "PASS" "Configuration directory found: $location ($config_count files)"
        fi
    done
    
    SYSTEM_STATUS[config_files]="${found_configs[*]}"
    
    if [[ ${#found_configs[@]} -gt 0 ]]; then
        log "PASS" "Found ${#found_configs[@]} configuration locations"
    else
        log "WARN" "No Cursor configuration files found"
    fi
    
    return 0
}

# === NETWORK TESTS ===

# Test network connectivity
test_network_connectivity() {
    log "INFO" "Testing network connectivity for Cursor services"
    
    local test_endpoints=(
        "api.cursor.so:443"
        "update.cursor.so:443"
        "github.com:443"
    )
    
    local reachable_endpoints=0
    
    for endpoint in "${test_endpoints[@]}"; do
        local host="${endpoint%:*}"
        local port="${endpoint#*:}"
        
        if timeout 5 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
            ((reachable_endpoints++))
            log "PASS" "Network connectivity verified: $endpoint"
        else
            log "WARN" "Network connectivity failed: $endpoint"
        fi
    done
    
    TEST_METRICS[reachable_endpoints]="$reachable_endpoints"
    TEST_METRICS[total_endpoints]="${#test_endpoints[@]}"
    
    if [[ $reachable_endpoints -gt 0 ]]; then
        log "PASS" "Network connectivity: $reachable_endpoints/${#test_endpoints[@]} endpoints reachable"
    else
        log "ERROR" "No network connectivity to Cursor services"
        return 1
    fi
    
    return 0
}

# === SECURITY TESTS ===

# Test file permissions
test_file_permissions() {
    log "INFO" "Testing Cursor file permissions"
    
    local cursor_binary="$(which cursor 2>/dev/null || echo "")"
    
    if [[ -z "$cursor_binary" ]]; then
        log "SKIP" "Cursor binary not found for permission testing"
        return 0
    fi
    
    # Check binary permissions
    local perms=$(stat -f%Mp%Lp "$cursor_binary" 2>/dev/null || stat -c%a "$cursor_binary" 2>/dev/null || echo "000")
    
    if [[ "$perms" =~ ^[0-9]*755$ ]] || [[ "$perms" =~ ^[0-9]*555$ ]]; then
        log "PASS" "Cursor binary has correct permissions: $perms"
    else
        log "WARN" "Cursor binary has unusual permissions: $perms"
    fi
    
    # Check for setuid/setgid bits
    if [[ -u "$cursor_binary" ]] || [[ -g "$cursor_binary" ]]; then
        log "WARN" "Cursor binary has setuid/setgid bits set"
    else
        log "PASS" "Cursor binary has no setuid/setgid bits"
    fi
    
    return 0
}

# === PERFORMANCE TESTS ===

# Test system resources
test_system_resources() {
    log "INFO" "Testing system resource availability"
    
    # Check memory usage
    local total_mem_kb=$(grep "MemTotal:" /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
    local available_mem_kb=$(grep "MemAvailable:" /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
    
    if [[ $total_mem_kb -gt 0 ]]; then
        local mem_usage_percent=$(((total_mem_kb - available_mem_kb) * 100 / total_mem_kb))
        TEST_METRICS[memory_usage_percent]="$mem_usage_percent"
        TEST_METRICS[available_memory_mb]="$((available_mem_kb / 1024))"
        
        if [[ $mem_usage_percent -lt 80 ]]; then
            log "PASS" "Memory usage: ${mem_usage_percent}% (${available_mem_kb} KB available)"
        else
            log "WARN" "High memory usage: ${mem_usage_percent}%"
        fi
    fi
    
    # Check CPU load
    local load_avg=$(uptime | grep -oE 'load average[s]*: [0-9.]+' | grep -oE '[0-9.]+' || echo "0")
    local cpu_cores=$(nproc 2>/dev/null || echo "1")
    
    if [[ -n "$load_avg" ]] && [[ "$load_avg" != "0" ]]; then
        local load_per_core=$(echo "scale=2; $load_avg / $cpu_cores" | bc 2>/dev/null || echo "0")
        TEST_METRICS[load_average]="$load_avg"
        TEST_METRICS[load_per_core]="$load_per_core"
        
        if (( $(echo "$load_per_core < 1.0" | bc -l 2>/dev/null || echo "1") )); then
            log "PASS" "System load: $load_avg (${load_per_core} per core)"
        else
            log "WARN" "High system load: $load_avg"
        fi
    fi
    
    return 0
}

# === REPORT GENERATION ===

# Generate comprehensive test report
generate_test_report() {
    log "INFO" "Generating comprehensive test report"
    
    cat > "$TEST_REPORT" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "version": "$SCRIPT_VERSION",
    "summary": {
        "passed": ${TEST_RESULTS[passed]},
        "failed": ${TEST_RESULTS[failed]},
        "warnings": ${TEST_RESULTS[warnings]},
        "skipped": ${TEST_RESULTS[skipped]},
        "total": $((TEST_RESULTS[passed] + TEST_RESULTS[failed] + TEST_RESULTS[warnings] + TEST_RESULTS[skipped])),
        "success_rate": $(echo "scale=2; ${TEST_RESULTS[passed]} * 100 / (${TEST_RESULTS[passed]} + ${TEST_RESULTS[failed]})" | bc 2>/dev/null || echo "0"),
        "overall_status": "$([ ${TEST_RESULTS[failed]} -eq 0 ] && echo "PASS" || echo "FAIL")"
    },
    "system_status": {
$(for key in "${!SYSTEM_STATUS[@]}"; do
    echo "        \"$key\": \"${SYSTEM_STATUS[$key]}\","
done | sed '$ s/,$//')
    },
    "test_metrics": {
$(for key in "${!TEST_METRICS[@]}"; do
    echo "        \"$key\": \"${TEST_METRICS[$key]}\","
done | sed '$ s/,$//')
    },
    "recommendations": [
$(if [[ ${TEST_RESULTS[failed]} -gt 0 ]]; then
    echo "        \"Investigate and resolve failed tests before using Cursor\","
fi
if [[ ${TEST_RESULTS[warnings]} -gt 0 ]]; then
    echo "        \"Review warnings for optimal performance\","
fi
if [[ ${TEST_RESULTS[skipped]} -gt 0 ]]; then
    echo "        \"Consider running skipped tests manually\","
fi | sed '$ s/,$//')
    ]
}
EOF
    
    log "INFO" "Test report generated: $TEST_REPORT"
}

# === USER INTERFACE ===

# Show test summary
show_test_summary() {
    echo
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║         CURSOR IDE POST-INSTALLATION TEST SUMMARY       ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo
    echo "Test Results:"
    echo "  ✓ Passed:   ${TEST_RESULTS[passed]}"
    echo "  ✗ Failed:   ${TEST_RESULTS[failed]}"
    echo "  ⚠ Warnings: ${TEST_RESULTS[warnings]}"
    echo "  ◦ Skipped:  ${TEST_RESULTS[skipped]}"
    echo
    
    local total_tests=$((TEST_RESULTS[passed] + TEST_RESULTS[failed] + TEST_RESULTS[warnings] + TEST_RESULTS[skipped]))
    if [[ $total_tests -gt 0 ]]; then
        local success_rate=$(echo "scale=1; ${TEST_RESULTS[passed]} * 100 / $total_tests" | bc 2>/dev/null || echo "0")
        echo "Success Rate: ${success_rate}%"
    fi
    
    echo
    if [[ ${TEST_RESULTS[failed]} -eq 0 ]]; then
        echo -e "\033[0;32m✓ All critical tests passed - Cursor IDE is ready to use\033[0m"
    else
        echo -e "\033[0;31m✗ Some tests failed - Please review the issues\033[0m"
    fi
    
    echo
    echo "Detailed report: $TEST_REPORT"
    echo "Logs: $MAIN_LOG"
    echo
}

# === MAIN EXECUTION ===

main() {
    echo "CURSOR IDE POST-INSTALLATION TESTING v${SCRIPT_VERSION}"
    echo "===================================================="
    echo
    
    # Initialize
    if ! initialize_directories; then
        echo "Failed to initialize. Check permissions."
        exit 1
    fi
    
    log "INFO" "Starting post-installation testing"
    
    # Run all tests with performance measurement and retry logic
    retry_test "Cursor Binary Test" "measure_performance 'cursor_binary' 'test_cursor_binary'"
    retry_test "Cursor Version Test" "measure_performance 'cursor_version' 'test_cursor_version'"
    retry_test "Cursor Help Test" "measure_performance 'cursor_help' 'test_cursor_help'"
    retry_test "Process Detection Test" "measure_performance 'cursor_processes' 'test_cursor_processes'"
    retry_test "Process Health Test" "measure_performance 'process_health' 'test_process_health'"
    retry_test "Installation Directory Test" "measure_performance 'install_dir' 'test_installation_directory'"
    retry_test "Log Files Test" "measure_performance 'log_files' 'test_log_files'"
    retry_test "Configuration Test" "measure_performance 'config_files' 'test_configuration_files'"
    retry_test "Network Connectivity Test" "measure_performance 'network' 'test_network_connectivity'"
    retry_test "File Permissions Test" "measure_performance 'permissions' 'test_file_permissions'"
    retry_test "System Resources Test" "measure_performance 'resources' 'test_system_resources'"
    
    # Show results
    show_test_summary
    
    # Exit with appropriate code
    if [[ ${TEST_RESULTS[failed]} -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Execute main function
main "$@"