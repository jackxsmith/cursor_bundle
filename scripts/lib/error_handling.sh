#!/usr/bin/env bash
# Enhanced Error Handling Library for Cursor Bundle
# Provides comprehensive error handling, logging, and recovery mechanisms

set -euo pipefail
IFS=$'\n\t'

# Global error handling configuration
declare -g ERROR_LOG_FILE="${ERROR_LOG_FILE:-/tmp/cursor_bundle_errors.log}"
declare -g ERROR_CONTEXT_DEPTH="${ERROR_CONTEXT_DEPTH:-3}"
declare -g ERROR_NOTIFICATION_ENABLED="${ERROR_NOTIFICATION_ENABLED:-true}"
declare -g ERROR_RECOVERY_ENABLED="${ERROR_RECOVERY_ENABLED:-true}"

# Error severity levels
declare -A ERROR_LEVELS=(
    ["CRITICAL"]=0
    ["ERROR"]=1
    ["WARNING"]=2
    ["INFO"]=3
    ["DEBUG"]=4
)

# Color codes for error output
declare -A ERROR_COLORS=(
    ["CRITICAL"]="\033[1;31m"  # Bold Red
    ["ERROR"]="\033[0;31m"     # Red
    ["WARNING"]="\033[0;33m"   # Yellow
    ["INFO"]="\033[0;36m"      # Cyan
    ["DEBUG"]="\033[0;90m"     # Dark Gray
    ["RESET"]="\033[0m"        # Reset
)

# Error context stack
declare -a ERROR_CONTEXT_STACK=()

# Initialize error handling
init_error_handling() {
    local log_dir
    log_dir="$(dirname "$ERROR_LOG_FILE")"
    
    # Create log directory if it doesn't exist
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" || {
            echo "WARNING: Cannot create error log directory: $log_dir" >&2
            ERROR_LOG_FILE="/tmp/cursor_bundle_errors_$$.log"
        }
    fi
    
    # Initialize log file
    touch "$ERROR_LOG_FILE" || {
        echo "WARNING: Cannot create error log file: $ERROR_LOG_FILE" >&2
        ERROR_LOG_FILE="/dev/stderr"
    }
    
    # Set up signal handlers for cleanup
    trap 'handle_exit_signal $?' EXIT
    trap 'handle_interrupt_signal' INT TERM
    
    log_error "INFO" "Error handling initialized" "init_error_handling"
}

# Enhanced logging function with context
log_error() {
    local level="${1:-INFO}"
    local message="${2:-Unknown error}"
    local context="${3:-${FUNCNAME[2]:-unknown}}"
    local additional_context="${4:-}"
    
    # Use comprehensive logging if available
    if declare -f log_comprehensive >/dev/null 2>&1; then
        log_comprehensive "$level" "$message" "$context" "$additional_context"
        return
    fi
    
    # Fallback to original logging
    local timestamp
    local log_entry
    local stack_trace=""
    
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Build stack trace if enabled and severity is high enough
    if [[ "${ERROR_LEVELS[$level]:-3}" -le 1 ]] && [[ "$ERROR_CONTEXT_DEPTH" -gt 0 ]]; then
        stack_trace=$(get_stack_trace "$ERROR_CONTEXT_DEPTH")
    fi
    
    # Format log entry
    log_entry="[$timestamp] [$level] [$context] $message"
    if [[ -n "$stack_trace" ]]; then
        log_entry="${log_entry}\nStack trace:\n${stack_trace}"
    fi
    
    # Write to log file
    if [[ "$ERROR_LOG_FILE" != "/dev/stderr" ]]; then
        echo -e "$log_entry" >> "$ERROR_LOG_FILE"
    fi
    
    # Write to stderr with colors
    echo -e "${ERROR_COLORS[$level]:-}[$level] $message${ERROR_COLORS[RESET]}" >&2
    
    # Add to context stack for later reference
    ERROR_CONTEXT_STACK+=("$log_entry")
    
    # Keep only recent context entries
    if [[ ${#ERROR_CONTEXT_STACK[@]} -gt 50 ]]; then
        ERROR_CONTEXT_STACK=("${ERROR_CONTEXT_STACK[@]:25}")
    fi
}

# Get stack trace
get_stack_trace() {
    local depth="${1:-3}"
    local i
    local stack_info=""
    
    for ((i = 2; i < depth + 2; i++)); do
        if [[ -n "${BASH_SOURCE[$i]:-}" ]]; then
            stack_info="${stack_info}  at ${FUNCNAME[$i]:-main} (${BASH_SOURCE[$i]##*/}:${BASH_LINENO[$((i-1))]})\n"
        fi
    done
    
    echo -e "$stack_info"
}

# Enhanced error handler with recovery options
handle_error() {
    local exit_code="${1:-1}"
    local error_message="${2:-Unspecified error occurred}"
    local context="${3:-${FUNCNAME[1]:-unknown}}"
    local recovery_action="${4:-}"
    
    log_error "ERROR" "$error_message (exit code: $exit_code)" "$context"
    
    # Attempt recovery if enabled and recovery action provided
    if [[ "$ERROR_RECOVERY_ENABLED" == "true" ]] && [[ -n "$recovery_action" ]]; then
        log_error "INFO" "Attempting recovery: $recovery_action" "$context"
        
        if eval "$recovery_action"; then
            log_error "INFO" "Recovery successful" "$context"
            return 0
        else
            log_error "ERROR" "Recovery failed" "$context"
        fi
    fi
    
    # Send notification if enabled
    if [[ "$ERROR_NOTIFICATION_ENABLED" == "true" ]]; then
        send_error_notification "$error_message" "$context" "$exit_code"
    fi
    
    return "$exit_code"
}

# Critical error handler (always exits)
handle_critical_error() {
    local error_message="${1:-Critical error occurred}"
    local context="${2:-${FUNCNAME[1]:-unknown}}"
    
    log_error "CRITICAL" "$error_message" "$context"
    
    # Send critical notification
    send_error_notification "$error_message" "$context" "CRITICAL"
    
    # Create error dump
    create_error_dump
    
    exit 1
}

# Warning handler (doesn't exit)
handle_warning() {
    local warning_message="${1:-Warning condition detected}"
    local context="${2:-${FUNCNAME[1]:-unknown}}"
    local recovery_action="${3:-}"
    
    log_error "WARNING" "$warning_message" "$context"
    
    # Attempt automatic recovery for warnings
    if [[ -n "$recovery_action" ]]; then
        log_error "INFO" "Attempting automatic recovery: $recovery_action" "$context"
        eval "$recovery_action" || log_error "WARNING" "Automatic recovery failed" "$context"
    fi
}

# Safe execution wrapper
safe_execute() {
    local command="$1"
    local error_message="${2:-Command execution failed}"
    local recovery_action="${3:-}"
    local context="${4:-${FUNCNAME[1]:-unknown}}"
    
    log_error "DEBUG" "Executing: $command" "$context"
    
    if eval "$command"; then
        log_error "DEBUG" "Command executed successfully" "$context"
        return 0
    else
        local exit_code=$?
        handle_error "$exit_code" "$error_message" "$context" "$recovery_action"
        return $exit_code
    fi
}

# Safe execution with retry
safe_execute_with_retry() {
    local command="$1"
    local max_retries="${2:-3}"
    local retry_delay="${3:-1}"
    local error_message="${4:-Command execution failed after retries}"
    local context="${5:-${FUNCNAME[1]:-unknown}}"
    
    local attempt=1
    local exit_code
    
    while [[ $attempt -le $max_retries ]]; do
        log_error "DEBUG" "Executing (attempt $attempt/$max_retries): $command" "$context"
        
        if eval "$command"; then
            log_error "DEBUG" "Command executed successfully on attempt $attempt" "$context"
            return 0
        else
            exit_code=$?
            if [[ $attempt -lt $max_retries ]]; then
                log_error "WARNING" "Command failed on attempt $attempt, retrying in ${retry_delay}s" "$context"
                sleep "$retry_delay"
            else
                handle_error "$exit_code" "$error_message" "$context"
                return $exit_code
            fi
        fi
        
        ((attempt++))
    done
}

# Enhanced || true replacement with proper error handling
safe_ignore() {
    local command="$1"
    local reason="${2:-Command allowed to fail safely}"
    local context="${3:-${FUNCNAME[1]:-unknown}}"
    
    log_error "DEBUG" "Executing (allowed to fail): $command" "$context"
    
    if eval "$command"; then
        log_error "DEBUG" "Command executed successfully" "$context"
        return 0
    else
        local exit_code=$?
        log_error "INFO" "Command failed as expected: $reason (exit code: $exit_code)" "$context"
        return 0  # Always return success for ignored commands
    fi
}

# Conditional execution based on success/failure
safe_conditional() {
    local condition="$1"
    local success_action="$2"
    local failure_action="${3:-}"
    local context="${4:-${FUNCNAME[1]:-unknown}}"
    
    log_error "DEBUG" "Evaluating condition: $condition" "$context"
    
    if eval "$condition"; then
        log_error "DEBUG" "Condition succeeded, executing: $success_action" "$context"
        eval "$success_action"
    elif [[ -n "$failure_action" ]]; then
        log_error "DEBUG" "Condition failed, executing: $failure_action" "$context"
        eval "$failure_action"
    else
        log_error "DEBUG" "Condition failed, no failure action specified" "$context"
        return 1
    fi
}

# Resource cleanup handler
cleanup_resources() {
    local resources=("$@")
    local resource
    
    log_error "INFO" "Cleaning up resources" "cleanup_resources"
    
    for resource in "${resources[@]}"; do
        if [[ -f "$resource" ]] || [[ -d "$resource" ]]; then
            safe_ignore "rm -rf '$resource'" "Cleanup of temporary resource" "cleanup_resources"
        fi
    done
}

# Signal handlers
handle_exit_signal() {
    local exit_code="${1:-0}"
    
    if [[ $exit_code -ne 0 ]]; then
        log_error "ERROR" "Script exited with non-zero code: $exit_code" "exit_handler"
        create_error_dump
    else
        log_error "INFO" "Script completed successfully" "exit_handler"
    fi
    
    # Cleanup if needed
    if [[ -n "${CLEANUP_RESOURCES:-}" ]]; then
        cleanup_resources "${CLEANUP_RESOURCES[@]}"
    fi
}

handle_interrupt_signal() {
    log_error "WARNING" "Script interrupted by signal" "interrupt_handler"
    create_error_dump
    exit 130
}

# Create comprehensive error dump
create_error_dump() {
    local dump_file="/tmp/cursor_bundle_error_dump_$(date +%s).txt"
    
    {
        echo "=== Cursor Bundle Error Dump ==="
        echo "Timestamp: $(date)"
        echo "Script: ${BASH_SOURCE[1]}"
        echo "Working Directory: $(pwd)"
        echo "User: $(whoami)"
        echo "Environment: ${ENVIRONMENT:-unknown}"
        echo ""
        
        echo "=== Recent Error Context ==="
        printf '%s\n' "${ERROR_CONTEXT_STACK[@]}"
        echo ""
        
        echo "=== Environment Variables ==="
        env | sort
        echo ""
        
        echo "=== Git Status ==="
        if command -v git >/dev/null && git rev-parse --git-dir >/dev/null 2>&1; then
            git status --porcelain || echo "Git status unavailable"
            echo ""
            echo "Current branch: $(git branch --show-current 2>/dev/null || echo 'unknown')"
            echo "Last commit: $(git log -1 --oneline 2>/dev/null || echo 'unknown')"
        else
            echo "Not in a git repository"
        fi
        echo ""
        
        echo "=== System Information ==="
        uname -a
        echo "Disk usage: $(df -h . 2>/dev/null | tail -1 || echo 'unknown')"
        echo "Memory usage: $(free -h 2>/dev/null | head -2 | tail -1 || echo 'unknown')"
        echo ""
        
        echo "=== Process Tree ==="
        ps aux --forest 2>/dev/null | head -20 || echo "Process information unavailable"
        
    } > "$dump_file"
    
    log_error "INFO" "Error dump created: $dump_file" "create_error_dump"
}

# Send error notifications
send_error_notification() {
    local message="$1"
    local context="$2"
    local severity="$3"
    
    # Placeholder for notification system integration
    # Could be extended to send to Slack, email, PagerDuty, etc.
    log_error "DEBUG" "Notification: [$severity] $message in $context" "send_error_notification"
    
    # Example: Send to syslog if available
    if command -v logger >/dev/null; then
        logger -t "cursor-bundle" -p "daemon.err" "[$severity] $message in $context"
    fi
}

# Validation helpers
validate_required_var() {
    local var_name="$1"
    local var_value="${!var_name:-}"
    local context="${2:-${FUNCNAME[1]:-unknown}}"
    
    if [[ -z "$var_value" ]]; then
        handle_critical_error "Required variable '$var_name' is not set or empty" "$context"
    fi
    
    log_error "DEBUG" "Variable '$var_name' is properly set" "$context"
}

validate_file_exists() {
    local file_path="$1"
    local context="${2:-${FUNCNAME[1]:-unknown}}"
    
    if [[ ! -f "$file_path" ]]; then
        handle_error 1 "Required file does not exist: $file_path" "$context"
        return 1
    fi
    
    log_error "DEBUG" "File exists: $file_path" "$context"
}

validate_command_exists() {
    local command_name="$1"
    local context="${2:-${FUNCNAME[1]:-unknown}}"
    
    if ! command -v "$command_name" >/dev/null 2>&1; then
        handle_error 1 "Required command not found: $command_name" "$context"
        return 1
    fi
    
    log_error "DEBUG" "Command available: $command_name" "$context"
}

# Export all functions for use in other scripts
export -f init_error_handling log_error handle_error handle_critical_error handle_warning
export -f safe_execute safe_execute_with_retry safe_ignore safe_conditional
export -f cleanup_resources validate_required_var validate_file_exists validate_command_exists

# Auto-initialize if sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    init_error_handling
fi