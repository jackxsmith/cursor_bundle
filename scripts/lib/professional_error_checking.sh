#!/usr/bin/env bash
#
# Professional Error Checking Framework
# Comprehensive error detection, prevention, and handling tools
#

set -euo pipefail
IFS=$'\n\t'

# === CONFIGURATION ===
readonly ERROR_FRAMEWORK_VERSION="1.0.0"
readonly ERROR_LOG_DIR="${HOME}/.cache/cursor/error-framework"
readonly ERROR_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
readonly ERROR_LOG="${ERROR_LOG_DIR}/errors_${ERROR_TIMESTAMP}.log"
readonly VALIDATION_LOG="${ERROR_LOG_DIR}/validation_${ERROR_TIMESTAMP}.log"

# Error severity levels
declare -A ERROR_LEVELS=(
    ["CRITICAL"]=1
    ["HIGH"]=2
    ["MEDIUM"]=3
    ["LOW"]=4
    ["INFO"]=5
)

# Global error tracking
declare -g ERROR_COUNT=0
declare -g WARNING_COUNT=0
declare -g VALIDATION_COUNT=0
declare -A ERROR_CATEGORIES=()

# === INITIALIZATION ===
init_error_framework() {
    mkdir -p "$ERROR_LOG_DIR"
    
    cat > "$ERROR_LOG" << EOF
# Professional Error Framework Log
# Session: $ERROR_TIMESTAMP
# Script: ${BASH_SOURCE[1]:-unknown}
# PID: $$
# User: $(whoami)
# PWD: $(pwd)
# Started: $(date -Iseconds)

EOF
    
    log_framework "INFO" "Error checking framework initialized"
}

# === LOGGING FUNCTIONS ===
log_framework() {
    local level="$1"
    local message="$2"
    local context="${3:-}"
    local timestamp="$(date -Iseconds)"
    
    echo "[$timestamp] [$level] ${context:+[$context] }$message" >> "$ERROR_LOG"
    
    case "$level" in
        CRITICAL|ERROR) 
            echo -e "\033[0;31m[ERROR]\033[0m $message" >&2
            ((ERROR_COUNT++))
            ;;
        WARN) 
            echo -e "\033[1;33m[WARN]\033[0m $message" >&2
            ((WARNING_COUNT++))
            ;;
        INFO) 
            echo -e "\033[0;34m[INFO]\033[0m $message"
            ;;
        DEBUG) 
            [[ "${DEBUG:-false}" == "true" ]] && echo -e "\033[0;36m[DEBUG]\033[0m $message"
            ;;
    esac
}

# === INPUT VALIDATION ===
validate_required_param() {
    local param_name="$1"
    local param_value="$2"
    local validation_type="${3:-string}"
    
    log_framework "DEBUG" "Validating parameter: $param_name" "validate_required_param"
    ((VALIDATION_COUNT++))
    
    if [[ -z "$param_value" ]]; then
        log_framework "ERROR" "Required parameter '$param_name' is empty or missing" "validate_required_param"
        return 1
    fi
    
    case "$validation_type" in
        string)
            if [[ ${#param_value} -lt 1 ]]; then
                log_framework "ERROR" "Parameter '$param_name' cannot be empty string" "validate_required_param"
                return 1
            fi
            ;;
        number)
            if ! [[ "$param_value" =~ ^[0-9]+$ ]]; then
                log_framework "ERROR" "Parameter '$param_name' must be a number, got: $param_value" "validate_required_param"
                return 1
            fi
            ;;
        email)
            if ! [[ "$param_value" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
                log_framework "ERROR" "Parameter '$param_name' must be a valid email, got: $param_value" "validate_required_param"
                return 1
            fi
            ;;
        url)
            if ! [[ "$param_value" =~ ^https?:// ]]; then
                log_framework "ERROR" "Parameter '$param_name' must be a valid URL, got: $param_value" "validate_required_param"
                return 1
            fi
            ;;
        path)
            if [[ ! -e "$param_value" ]]; then
                log_framework "ERROR" "Parameter '$param_name' path does not exist: $param_value" "validate_required_param"
                return 1
            fi
            ;;
        file)
            if [[ ! -f "$param_value" ]]; then
                log_framework "ERROR" "Parameter '$param_name' is not a valid file: $param_value" "validate_required_param"
                return 1
            fi
            ;;
        directory)
            if [[ ! -d "$param_value" ]]; then
                log_framework "ERROR" "Parameter '$param_name' is not a valid directory: $param_value" "validate_required_param"
                return 1
            fi
            ;;
    esac
    
    log_framework "DEBUG" "Parameter validation passed: $param_name=$param_value" "validate_required_param"
    return 0
}

# === COMMAND VALIDATION ===
validate_command_exists() {
    local command="$1"
    local required="${2:-true}"
    
    log_framework "DEBUG" "Validating command exists: $command" "validate_command_exists"
    
    if ! command -v "$command" >/dev/null 2>&1; then
        if [[ "$required" == "true" ]]; then
            log_framework "ERROR" "Required command not found: $command" "validate_command_exists"
            return 1
        else
            log_framework "WARN" "Optional command not found: $command" "validate_command_exists"
            return 1
        fi
    fi
    
    log_framework "DEBUG" "Command validation passed: $command" "validate_command_exists"
    return 0
}

# === ENVIRONMENT VALIDATION ===
validate_environment() {
    local env_var="$1"
    local required="${2:-true}"
    local pattern="${3:-}"
    
    log_framework "DEBUG" "Validating environment variable: $env_var" "validate_environment"
    
    if [[ -z "${!env_var:-}" ]]; then
        if [[ "$required" == "true" ]]; then
            log_framework "ERROR" "Required environment variable not set: $env_var" "validate_environment"
            return 1
        else
            log_framework "WARN" "Optional environment variable not set: $env_var" "validate_environment"
            return 1
        fi
    fi
    
    if [[ -n "$pattern" ]] && [[ ! "${!env_var}" =~ $pattern ]]; then
        log_framework "ERROR" "Environment variable '$env_var' does not match pattern '$pattern': ${!env_var}" "validate_environment"
        return 1
    fi
    
    log_framework "DEBUG" "Environment validation passed: $env_var" "validate_environment"
    return 0
}

# === SAFE EXECUTION ===
safe_execute() {
    local command="$1"
    local error_message="${2:-Command failed}"
    local retry_count="${3:-0}"
    local retry_delay="${4:-1}"
    
    log_framework "DEBUG" "Executing command: $command" "safe_execute"
    
    local attempt=0
    while [[ $attempt -le $retry_count ]]; do
        if [[ $attempt -gt 0 ]]; then
            log_framework "WARN" "Retrying command (attempt $((attempt + 1))): $command" "safe_execute"
            sleep "$retry_delay"
        fi
        
        if eval "$command" 2>>"$ERROR_LOG"; then
            log_framework "DEBUG" "Command executed successfully: $command" "safe_execute"
            return 0
        fi
        
        ((attempt++))
    done
    
    log_framework "ERROR" "$error_message: $command" "safe_execute"
    return 1
}

# === FILE OPERATIONS WITH VALIDATION ===
safe_file_operation() {
    local operation="$1"
    local source="$2"
    local destination="${3:-}"
    
    log_framework "DEBUG" "Safe file operation: $operation $source $destination" "safe_file_operation"
    
    case "$operation" in
        read)
            if [[ ! -f "$source" ]]; then
                log_framework "ERROR" "Cannot read file - does not exist: $source" "safe_file_operation"
                return 1
            fi
            if [[ ! -r "$source" ]]; then
                log_framework "ERROR" "Cannot read file - no read permission: $source" "safe_file_operation"
                return 1
            fi
            ;;
        write)
            local dir="$(dirname "$source")"
            if [[ ! -d "$dir" ]]; then
                log_framework "ERROR" "Cannot write file - directory does not exist: $dir" "safe_file_operation"
                return 1
            fi
            if [[ ! -w "$dir" ]]; then
                log_framework "ERROR" "Cannot write file - no write permission: $dir" "safe_file_operation"
                return 1
            fi
            ;;
        copy)
            if [[ ! -f "$source" ]]; then
                log_framework "ERROR" "Cannot copy file - source does not exist: $source" "safe_file_operation"
                return 1
            fi
            local dest_dir="$(dirname "$destination")"
            if [[ ! -d "$dest_dir" ]]; then
                mkdir -p "$dest_dir" || {
                    log_framework "ERROR" "Cannot create destination directory: $dest_dir" "safe_file_operation"
                    return 1
                }
            fi
            ;;
        move)
            if [[ ! -f "$source" ]]; then
                log_framework "ERROR" "Cannot move file - source does not exist: $source" "safe_file_operation"
                return 1
            fi
            local dest_dir="$(dirname "$destination")"
            if [[ ! -d "$dest_dir" ]]; then
                mkdir -p "$dest_dir" || {
                    log_framework "ERROR" "Cannot create destination directory: $dest_dir" "safe_file_operation"
                    return 1
                }
            fi
            ;;
        delete)
            if [[ ! -e "$source" ]]; then
                log_framework "WARN" "Cannot delete - file does not exist: $source" "safe_file_operation"
                return 0  # Not an error if file doesn't exist
            fi
            ;;
    esac
    
    log_framework "DEBUG" "File operation validation passed: $operation" "safe_file_operation"
    return 0
}

# === NETWORK VALIDATION ===
validate_network_connectivity() {
    local host="${1:-google.com}"
    local port="${2:-80}"
    local timeout="${3:-5}"
    
    log_framework "DEBUG" "Validating network connectivity to $host:$port" "validate_network_connectivity"
    
    if command -v nc >/dev/null 2>&1; then
        if timeout "$timeout" nc -z "$host" "$port" 2>/dev/null; then
            log_framework "DEBUG" "Network connectivity validated: $host:$port" "validate_network_connectivity"
            return 0
        fi
    elif command -v curl >/dev/null 2>&1; then
        if curl -s --connect-timeout "$timeout" "http://$host:$port" >/dev/null 2>&1; then
            log_framework "DEBUG" "Network connectivity validated: $host:$port" "validate_network_connectivity"
            return 0
        fi
    fi
    
    log_framework "ERROR" "Network connectivity failed: $host:$port" "validate_network_connectivity"
    return 1
}

# === FUNCTION ARGUMENT VALIDATION ===
validate_function_args() {
    local function_name="$1"
    local expected_count="$2"
    local actual_count="$3"
    
    log_framework "DEBUG" "Validating function arguments: $function_name expects $expected_count, got $actual_count" "validate_function_args"
    
    if [[ $actual_count -lt $expected_count ]]; then
        log_framework "ERROR" "Function '$function_name' requires $expected_count arguments, got $actual_count" "validate_function_args"
        return 1
    fi
    
    log_framework "DEBUG" "Function argument validation passed: $function_name" "validate_function_args"
    return 0
}

# === PROCESS VALIDATION ===
validate_process_running() {
    local process_name="$1"
    local required="${2:-false}"
    
    log_framework "DEBUG" "Validating process running: $process_name" "validate_process_running"
    
    if ! pgrep -f "$process_name" >/dev/null 2>&1; then
        if [[ "$required" == "true" ]]; then
            log_framework "ERROR" "Required process not running: $process_name" "validate_process_running"
            return 1
        else
            log_framework "INFO" "Process not running: $process_name" "validate_process_running"
            return 1
        fi
    fi
    
    log_framework "DEBUG" "Process validation passed: $process_name" "validate_process_running"
    return 0
}

# === DISK SPACE VALIDATION ===
validate_disk_space() {
    local path="$1"
    local required_mb="$2"
    
    log_framework "DEBUG" "Validating disk space: $path requires ${required_mb}MB" "validate_disk_space"
    
    if ! command -v df >/dev/null 2>&1; then
        log_framework "WARN" "Cannot validate disk space - 'df' command not available" "validate_disk_space"
        return 0
    fi
    
    local available_kb
    available_kb=$(df "$path" | awk 'NR==2 {print $4}')
    local available_mb=$((available_kb / 1024))
    
    if [[ $available_mb -lt $required_mb ]]; then
        log_framework "ERROR" "Insufficient disk space: $path has ${available_mb}MB, requires ${required_mb}MB" "validate_disk_space"
        return 1
    fi
    
    log_framework "DEBUG" "Disk space validation passed: $path has ${available_mb}MB available" "validate_disk_space"
    return 0
}

# === ERROR RECOVERY ===
setup_error_trap() {
    local cleanup_function="${1:-default_cleanup}"
    
    trap "handle_script_error \$? \$LINENO \"$cleanup_function\"" ERR
    trap "handle_script_exit \"$cleanup_function\"" EXIT
    
    log_framework "DEBUG" "Error trap setup with cleanup function: $cleanup_function" "setup_error_trap"
}

handle_script_error() {
    local exit_code="$1"
    local line_number="$2"
    local cleanup_function="$3"
    
    log_framework "CRITICAL" "Script error at line $line_number with exit code $exit_code" "handle_script_error"
    log_framework "INFO" "Call stack:" "handle_script_error"
    
    # Print call stack
    local frame=0
    while caller $frame >> "$ERROR_LOG" 2>&1; do
        ((frame++))
    done
    
    # Run cleanup
    if declare -f "$cleanup_function" >/dev/null 2>&1; then
        log_framework "INFO" "Running cleanup function: $cleanup_function" "handle_script_error"
        "$cleanup_function" || log_framework "WARN" "Cleanup function failed" "handle_script_error"
    fi
    
    generate_error_report
    exit "$exit_code"
}

handle_script_exit() {
    local cleanup_function="$1"
    
    log_framework "INFO" "Script exiting normally" "handle_script_exit"
    
    # Run cleanup
    if declare -f "$cleanup_function" >/dev/null 2>&1; then
        log_framework "DEBUG" "Running cleanup function: $cleanup_function" "handle_script_exit"
        "$cleanup_function" || log_framework "WARN" "Cleanup function failed" "handle_script_exit"
    fi
    
    generate_error_report
}

default_cleanup() {
    log_framework "DEBUG" "Running default cleanup" "default_cleanup"
    # Override this function in your scripts for custom cleanup
    return 0
}

# === ERROR REPORTING ===
generate_error_report() {
    local report_file="${ERROR_LOG_DIR}/error_report_${ERROR_TIMESTAMP}.txt"
    
    cat > "$report_file" << EOF
# Professional Error Framework Report
# Generated: $(date -Iseconds)
# Script: ${BASH_SOURCE[1]:-unknown}
# Session: $ERROR_TIMESTAMP

## Summary
- Errors: $ERROR_COUNT
- Warnings: $WARNING_COUNT  
- Validations: $VALIDATION_COUNT

## Error Categories
EOF

    for category in "${!ERROR_CATEGORIES[@]}"; do
        echo "- $category: ${ERROR_CATEGORIES[$category]}" >> "$report_file"
    done
    
    echo -e "\n## Detailed Log" >> "$report_file"
    cat "$ERROR_LOG" >> "$report_file" 2>/dev/null || true
    
    log_framework "INFO" "Error report generated: $report_file" "generate_error_report"
}

# === COMPREHENSIVE VALIDATION SUITE ===
run_comprehensive_validation() {
    local validation_config="${1:-}"
    
    log_framework "INFO" "Running comprehensive validation suite" "run_comprehensive_validation"
    
    # System validation
    validate_command_exists "bash" true
    validate_command_exists "git" true
    validate_command_exists "curl" false
    
    # Environment validation
    validate_environment "HOME" true
    validate_environment "USER" true
    validate_environment "PATH" true
    
    # Network validation (if needed)
    if [[ "${VALIDATE_NETWORK:-false}" == "true" ]]; then
        validate_network_connectivity "github.com" 443 10
    fi
    
    # Disk space validation
    validate_disk_space "." 100  # Require 100MB free space
    
    log_framework "INFO" "Comprehensive validation completed" "run_comprehensive_validation"
    
    if [[ $ERROR_COUNT -gt 0 ]]; then
        log_framework "ERROR" "Validation failed with $ERROR_COUNT errors" "run_comprehensive_validation"
        return 1
    fi
    
    return 0
}

# === INITIALIZATION ===
# Auto-initialize when sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    init_error_framework
fi