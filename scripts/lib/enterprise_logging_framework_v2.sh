#!/usr/bin/env bash
#
# Enterprise-Grade Logging Framework v2.0 - Security Hardened
# Comprehensive function tracking, output recording, and error management
# 
# SECURITY IMPROVEMENTS:
# - Eliminated eval usage for security
# - Enhanced input validation and sanitization
# - Secure temporary file handling
# - Proper variable quoting throughout
# - Reduced function complexity
# - Added security logging for sensitive operations
#

set -euo pipefail
IFS=$'\n\t'

# === FRAMEWORK CONFIGURATION ===
readonly ENTERPRISE_LOGGING_VERSION="2.1.0"
readonly LOGGING_NAMESPACE="${LOGGING_NAMESPACE:-cursor_bundle}"
readonly LOG_BASE_DIR="${LOG_BASE_DIR:-${HOME}/.cache/cursor/enterprise-logs}"
readonly SESSION_ID="${SESSION_ID:-$(date +%s)_$$_$(openssl rand -hex 4 2>/dev/null || echo $(($$ * RANDOM)))}"
readonly CORRELATION_ID="${CORRELATION_ID:-$(uuidgen 2>/dev/null || echo "corr_$(date +%s)_$$")}"

# Log directories structure
readonly LOG_STRUCTURED_DIR="${LOG_BASE_DIR}/structured"
readonly LOG_AUDIT_DIR="${LOG_BASE_DIR}/audit" 
readonly LOG_PERFORMANCE_DIR="${LOG_BASE_DIR}/performance"
readonly LOG_SECURITY_DIR="${LOG_BASE_DIR}/security"
readonly LOG_FUNCTION_DIR="${LOG_BASE_DIR}/function-traces"
readonly LOG_ERROR_DIR="${LOG_BASE_DIR}/errors"
readonly LOG_ARCHIVE_DIR="${LOG_BASE_DIR}/archive"

# Log files with proper quoting
readonly LOG_MAIN="${LOG_STRUCTURED_DIR}/main_${SESSION_ID}.jsonl"
readonly LOG_AUDIT="${LOG_AUDIT_DIR}/audit_${SESSION_ID}.jsonl"
readonly LOG_PERFORMANCE="${LOG_PERFORMANCE_DIR}/perf_${SESSION_ID}.jsonl"
readonly LOG_SECURITY="${LOG_SECURITY_DIR}/security_${SESSION_ID}.jsonl"
readonly LOG_FUNCTION_TRACE="${LOG_FUNCTION_DIR}/functions_${SESSION_ID}.jsonl"
readonly LOG_ERROR_DETAIL="${LOG_ERROR_DIR}/errors_${SESSION_ID}.jsonl"

# Configuration with safe defaults
declare -g ENTERPRISE_LOG_LEVEL="${ENTERPRISE_LOG_LEVEL:-INFO}"
declare -g ENABLE_FUNCTION_TRACING="${ENABLE_FUNCTION_TRACING:-true}"
declare -g ENABLE_PERFORMANCE_MONITORING="${ENABLE_PERFORMANCE_MONITORING:-true}"
declare -g ENABLE_SECURITY_LOGGING="${ENABLE_SECURITY_LOGGING:-true}"
declare -g ENABLE_AUDIT_LOGGING="${ENABLE_AUDIT_LOGGING:-true}"
declare -g LOG_RETENTION_DAYS="${LOG_RETENTION_DAYS:-90}"
declare -g MAX_LOG_SIZE_MB="${MAX_LOG_SIZE_MB:-100}"
declare -g ALERT_ON_ERRORS="${ALERT_ON_ERRORS:-true}"

# Log levels mapping
declare -A LOG_LEVELS=(
    ["TRACE"]=0
    ["DEBUG"]=1
    ["INFO"]=2
    ["WARN"]=3
    ["ERROR"]=4
    ["FATAL"]=5
)

# Error categories with initialization
declare -A ERROR_CATEGORIES=(
    ["VALIDATION"]=0
    ["AUTHENTICATION"]=0
    ["AUTHORIZATION"]=0
    ["NETWORK"]=0
    ["FILE_SYSTEM"]=0
    ["DATABASE"]=0
    ["EXTERNAL_SERVICE"]=0
    ["SYSTEM_RESOURCE"]=0
    ["BUSINESS_LOGIC"]=0
    ["SECURITY"]=0
    ["GENERAL"]=0
)

# Performance tracking with proper initialization
declare -A FUNCTION_START_TIMES=()
declare -A FUNCTION_CALL_COUNTS=()
declare -A FUNCTION_TOTAL_TIME=()
declare -g CALL_STACK_DEPTH=0

# System information with safe extraction
readonly HOSTNAME="${HOSTNAME:-$(hostname 2>/dev/null || echo 'unknown')}"
readonly USERNAME="${USER:-$(whoami 2>/dev/null || echo 'unknown')}"
readonly PROCESS_ID="$$"
readonly PARENT_PROCESS_ID="${PPID:-0}"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[-1]}" 2>/dev/null || echo 'unknown')"
readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[-1]}")" 2>/dev/null && pwd || echo 'unknown')"

# === SECURITY FUNCTIONS ===

# Sanitize input for logging (prevent log injection)
sanitize_log_input() {
    local input="$1"
    local max_length="${2:-1000}"
    
    # Remove control characters and limit length
    printf '%s' "$input" | tr -d '\000-\031\177' | cut -c1-"$max_length"
}

# Validate session and correlation IDs
validate_session_id() {
    local session_id="$1"
    
    # Session ID should be alphanumeric with underscores and limited length
    if [[ "$session_id" =~ ^[a-zA-Z0-9_]{10,50}$ ]]; then
        return 0
    else
        return 1
    fi
}

# Secure temporary file creation
create_secure_temp_file() {
    local temp_file
    temp_file=$(mktemp) || {
        echo "ERROR: Cannot create secure temporary file" >&2
        return 1
    }
    
    # Set secure permissions
    chmod 600 "$temp_file" || {
        rm -f "$temp_file"
        return 1
    }
    
    echo "$temp_file"
}

# === INITIALIZATION ===
init_enterprise_logging() {
    # Validate session ID
    if ! validate_session_id "$SESSION_ID"; then
        echo "ERROR: Invalid session ID format" >&2
        return 1
    fi
    
    # Create directory structure with proper error handling
    local dirs=(
        "$LOG_STRUCTURED_DIR" "$LOG_AUDIT_DIR" "$LOG_PERFORMANCE_DIR"
        "$LOG_SECURITY_DIR" "$LOG_FUNCTION_DIR" "$LOG_ERROR_DIR" "$LOG_ARCHIVE_DIR"
    )
    
    for dir in "${dirs[@]}"; do
        if ! mkdir -p "$dir" 2>/dev/null; then
            echo "ERROR: Cannot create log directory: $dir" >&2
            return 1
        fi
        # Set secure permissions for log directories
        chmod 700 "$dir" 2>/dev/null || true
    done
    
    # Initialize log files with headers
    init_structured_log_file "$LOG_MAIN" || return 1
    init_structured_log_file "$LOG_AUDIT" || return 1
    init_structured_log_file "$LOG_PERFORMANCE" || return 1
    init_structured_log_file "$LOG_SECURITY" || return 1
    init_structured_log_file "$LOG_FUNCTION_TRACE" || return 1
    init_structured_log_file "$LOG_ERROR_DETAIL" || return 1
    
    # Log session initialization
    enterprise_log "INFO" "Enterprise logging framework v${ENTERPRISE_LOGGING_VERSION} initialized" \
        "logging_framework" \
        "{\"version\":\"${ENTERPRISE_LOGGING_VERSION}\",\"session_id\":\"${SESSION_ID}\",\"correlation_id\":\"${CORRELATION_ID}\"}"
    
    # Setup log rotation and cleanup
    setup_log_rotation
    trap cleanup_enterprise_logging EXIT
    
    return 0
}

# Initialize structured log file with error handling
init_structured_log_file() {
    local log_file="$1"
    
    if [[ -z "$log_file" ]]; then
        echo "ERROR: Log file path not provided" >&2
        return 1
    fi
    
    # Create log file with proper error handling
    cat > "$log_file" << EOF || return 1
{"log_type":"session_start","timestamp":"$(iso8601_timestamp)","session_id":"${SESSION_ID}","correlation_id":"${CORRELATION_ID}","hostname":"${HOSTNAME}","username":"${USERNAME}","process_id":"${PROCESS_ID}","script_name":"${SCRIPT_NAME}","script_path":"${SCRIPT_PATH}","framework_version":"${ENTERPRISE_LOGGING_VERSION}"}
EOF
    
    # Set secure permissions
    chmod 600 "$log_file" 2>/dev/null || true
    
    return 0
}

# === CORE LOGGING FUNCTIONS ===

# Main enterprise logging function with enhanced security
enterprise_log() {
    local level="$1"
    local message="$2"
    local component="${3:-general}"
    local additional_data="${4:-{}}"
    local caller_info="${5:-}"
    
    # Input validation
    if [[ -z "$level" || -z "$message" ]]; then
        echo "ERROR: Level and message are required for logging" >&2
        return 1
    fi
    
    # Validate log level
    if [[ -z "${LOG_LEVELS[$level]:-}" ]]; then
        echo "ERROR: Invalid log level: $level" >&2
        return 1
    fi
    
    # Check if we should log this level
    if ! should_log "$level"; then
        return 0
    fi
    
    # Sanitize inputs to prevent log injection
    level=$(sanitize_log_input "$level" 10)
    message=$(sanitize_log_input "$message" 1000)
    component=$(sanitize_log_input "$component" 50)
    
    # Generate timestamp and caller information
    local timestamp
    timestamp=$(iso8601_timestamp) || {
        echo "ERROR: Cannot generate timestamp" >&2
        return 1
    }
    
    if [[ -z "$caller_info" ]]; then
        caller_info=$(get_caller_info 2)
    fi
    
    # Create structured log entry
    local log_entry
    log_entry=$(create_log_entry \
        "$timestamp" \
        "$level" \
        "$message" \
        "$component" \
        "$caller_info" \
        "$additional_data") || {
        echo "ERROR: Cannot create log entry" >&2
        return 1
    }
    
    # Write to appropriate log files with error handling
    {
        echo "$log_entry" >> "$LOG_MAIN"
    } || {
        echo "ERROR: Cannot write to main log file" >&2
        return 1
    }
    
    # Route to specialized logs based on level and component
    route_specialized_logs "$level" "$component" "$log_entry"
    
    # Console output with formatting
    output_console_log "$level" "$message" "$component" "$timestamp"
    
    return 0
}

# Route logs to specialized log files
route_specialized_logs() {
    local level="$1"
    local component="$2"
    local log_entry="$3"
    
    # Error and fatal logs
    case "$level" in
        "ERROR"|"FATAL")
            echo "$log_entry" >> "$LOG_ERROR_DETAIL" 2>/dev/null || true
            if [[ "$ALERT_ON_ERRORS" == "true" ]]; then
                trigger_error_alert "$log_entry"
            fi
            # Increment error category counter safely
            local category="${component^^}"
            if [[ -n "${ERROR_CATEGORIES[$category]:-}" ]]; then
                ((ERROR_CATEGORIES["$category"]++))
            else
                ((ERROR_CATEGORIES["GENERAL"]++))
            fi
            ;;
    esac
    
    # Security events
    if [[ "$component" =~ ^(security|auth|validation)$ ]] && [[ "$ENABLE_SECURITY_LOGGING" == "true" ]]; then
        echo "$log_entry" >> "$LOG_SECURITY" 2>/dev/null || true
    fi
}

# Function tracing with improved security
trace_function_enter() {
    local function_name="$1"
    local args="$2"
    
    [[ "$ENABLE_FUNCTION_TRACING" != "true" ]] && return 0
    
    # Validate function name
    if [[ ! "$function_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "ERROR: Invalid function name for tracing: $function_name" >&2
        return 1
    fi
    
    # Safely increment counters
    ((CALL_STACK_DEPTH++))
    FUNCTION_START_TIMES["$function_name"]=$(get_high_precision_timestamp)
    FUNCTION_CALL_COUNTS["$function_name"]=$((${FUNCTION_CALL_COUNTS["$function_name"]:-0} + 1))
    
    # Sanitize arguments for logging
    local sanitized_args
    sanitized_args=$(sanitize_log_input "$args" 500)
    
    local trace_data
    trace_data=$(create_trace_data \
        "$function_name" \
        "enter" \
        "$CALL_STACK_DEPTH" \
        "$sanitized_args" \
        "${FUNCTION_CALL_COUNTS["$function_name"]}")
    
    enterprise_log "TRACE" "Function entered: $function_name" "function_trace" "$trace_data"
    
    # Write to function trace log if enabled
    if [[ "$ENABLE_FUNCTION_TRACING" == "true" ]]; then
        write_function_trace_log "enter" "$function_name" "$trace_data"
    fi
}

# Function exit tracing with improved security
trace_function_exit() {
    local function_name="$1"
    local exit_code="${2:-0}"
    local return_value="${3:-}"
    
    [[ "$ENABLE_FUNCTION_TRACING" != "true" ]] && return 0
    
    # Validate function name
    if [[ ! "$function_name" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
        echo "ERROR: Invalid function name for tracing: $function_name" >&2
        return 1
    fi
    
    local end_time
    end_time=$(get_high_precision_timestamp)
    local start_time="${FUNCTION_START_TIMES["$function_name"]:-$end_time}"
    local execution_time
    execution_time=$(calculate_execution_time "$start_time" "$end_time")
    
    # Update total time safely
    FUNCTION_TOTAL_TIME["$function_name"]=$(echo "${FUNCTION_TOTAL_TIME["$function_name"]:-0} + $execution_time" | bc -l 2>/dev/null || echo "0")
    ((CALL_STACK_DEPTH > 0)) && ((CALL_STACK_DEPTH--))
    
    # Sanitize return value for logging
    local sanitized_return_value
    sanitized_return_value=$(sanitize_log_input "$return_value" 200)
    
    local trace_data
    trace_data=$(create_trace_data \
        "$function_name" \
        "exit" \
        "$CALL_STACK_DEPTH" \
        "" \
        "${FUNCTION_CALL_COUNTS["$function_name"]:-0}" \
        "$exit_code" \
        "$sanitized_return_value" \
        "$execution_time")
    
    enterprise_log "TRACE" "Function exited: $function_name (${execution_time}s)" "function_trace" "$trace_data"
    
    # Write to function trace log
    if [[ "$ENABLE_FUNCTION_TRACING" == "true" ]]; then
        write_function_trace_log "exit" "$function_name" "$trace_data"
    fi
    
    # Performance monitoring
    if [[ "$ENABLE_PERFORMANCE_MONITORING" == "true" ]]; then
        log_performance_metrics "$function_name" "$execution_time" "$exit_code"
    fi
}

# Create trace data structure
create_trace_data() {
    local function_name="$1"
    local action="$2"
    local call_depth="$3"
    local arguments="${4:-}"
    local call_count="${5:-0}"
    local exit_code="${6:-}"
    local return_value="${7:-}"
    local execution_time="${8:-}"
    
    local memory_usage
    memory_usage=$(get_memory_usage)
    local cpu_usage
    cpu_usage=$(get_cpu_usage)
    
    cat << EOF
{
    "function_name": "$function_name",
    "action": "$action",
    "call_depth": $call_depth,
    "arguments": "$arguments",
    "call_count": $call_count,
    "exit_code": "$exit_code",
    "return_value": "$return_value",
    "execution_time_seconds": "$execution_time",
    "total_time_seconds": "${FUNCTION_TOTAL_TIME["$function_name"]:-0}",
    "memory_usage": $memory_usage,
    "cpu_usage": $cpu_usage
}
EOF
}

# Write to function trace log
write_function_trace_log() {
    local action="$1"
    local function_name="$2"
    local trace_data="$3"
    
    local function_log_entry
    function_log_entry=$(create_log_entry \
        "$(iso8601_timestamp)" \
        "TRACE" \
        "Function $action: $function_name" \
        "function_trace" \
        "$(get_caller_info 3)" \
        "$trace_data")
    
    echo "$function_log_entry" >> "$LOG_FUNCTION_TRACE" 2>/dev/null || true
}

# Calculate execution time safely
calculate_execution_time() {
    local start_time="$1"
    local end_time="$2"
    
    if command -v bc >/dev/null 2>&1; then
        echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0"
    else
        # Fallback calculation for systems without bc
        local start_int="${start_time%.*}"
        local end_int="${end_time%.*}"
        echo "$((end_int - start_int))"
    fi
}

# === AUDIT LOGGING ===

# Audit logging with enhanced validation
audit_log() {
    local action="$1"
    local resource="$2"
    local result="$3"
    local additional_data="${4:-{}}"
    
    [[ "$ENABLE_AUDIT_LOGGING" != "true" ]] && return 0
    
    # Validate required parameters
    if [[ -z "$action" || -z "$resource" || -z "$result" ]]; then
        echo "ERROR: Action, resource, and result are required for audit logging" >&2
        return 1
    fi
    
    # Sanitize inputs
    action=$(sanitize_log_input "$action" 100)
    resource=$(sanitize_log_input "$resource" 200)
    result=$(sanitize_log_input "$result" 50)
    
    local audit_data
    audit_data=$(cat << EOF
{
    "action": "$action",
    "resource": "$resource",
    "result": "$result",
    "user": "$USERNAME",
    "hostname": "$HOSTNAME",
    "process_id": "$PROCESS_ID",
    "additional_data": $additional_data
}
EOF
)
    
    local audit_entry
    audit_entry=$(create_log_entry \
        "$(iso8601_timestamp)" \
        "AUDIT" \
        "Audit: $action on $resource -> $result" \
        "audit" \
        "$(get_caller_info 2)" \
        "$audit_data")
    
    echo "$audit_entry" >> "$LOG_AUDIT" 2>/dev/null || true
    enterprise_log "INFO" "Audit event: $action" "audit" "$audit_data"
}

# === SECURITY LOGGING ===

# Security logging with enhanced validation
security_log() {
    local event_type="$1"
    local description="$2"
    local severity="${3:-MEDIUM}"
    local additional_data="${4:-{}}"
    
    [[ "$ENABLE_SECURITY_LOGGING" != "true" ]] && return 0
    
    # Validate inputs
    if [[ -z "$event_type" || -z "$description" ]]; then
        echo "ERROR: Event type and description are required for security logging" >&2
        return 1
    fi
    
    # Validate severity level
    if [[ ! "$severity" =~ ^(LOW|MEDIUM|HIGH|CRITICAL)$ ]]; then
        echo "ERROR: Invalid severity level: $severity" >&2
        return 1
    fi
    
    # Sanitize inputs
    event_type=$(sanitize_log_input "$event_type" 100)
    description=$(sanitize_log_input "$description" 500)
    
    local security_data
    security_data=$(cat << EOF
{
    "event_type": "$event_type",
    "description": "$description",
    "severity": "$severity",
    "source_ip": "$(get_source_ip)",
    "user_agent": "${HTTP_USER_AGENT:-shell}",
    "additional_data": $additional_data
}
EOF
)
    
    local log_level="WARN"
    case "$severity" in
        "HIGH"|"CRITICAL") log_level="ERROR" ;;
        "MEDIUM") log_level="WARN" ;;
        "LOW") log_level="INFO" ;;
    esac
    
    enterprise_log "$log_level" "Security event: $event_type - $description" "security" "$security_data"
}

# === PERFORMANCE MONITORING ===

# Performance monitoring with validation
log_performance_metrics() {
    local operation="$1"
    local execution_time="$2"
    local exit_code="${3:-0}"
    
    [[ "$ENABLE_PERFORMANCE_MONITORING" != "true" ]] && return 0
    
    # Validate inputs
    if [[ -z "$operation" || -z "$execution_time" ]]; then
        echo "ERROR: Operation and execution time are required for performance logging" >&2
        return 1
    fi
    
    # Sanitize operation name
    operation=$(sanitize_log_input "$operation" 100)
    
    local perf_data
    perf_data=$(cat << EOF
{
    "operation": "$operation",
    "execution_time_seconds": $execution_time,
    "exit_code": $exit_code,
    "memory_usage_mb": $(get_memory_usage),
    "cpu_usage_percent": $(get_cpu_usage),
    "disk_usage_mb": $(get_disk_usage),
    "load_average": "$(get_load_average)",
    "open_files": $(get_open_files_count)
}
EOF
)
    
    local perf_entry
    perf_entry=$(create_log_entry \
        "$(iso8601_timestamp)" \
        "PERFORMANCE" \
        "Performance metrics for: $operation" \
        "performance" \
        "$(get_caller_info 2)" \
        "$perf_data")
    
    echo "$perf_entry" >> "$LOG_PERFORMANCE" 2>/dev/null || true
}

# === UTILITY FUNCTIONS ===

# Create log entry with improved error handling
create_log_entry() {
    local timestamp="$1"
    local level="$2"
    local message="$3"
    local component="$4"
    local caller_info="$5"
    local additional_data="$6"
    
    # Validate required parameters
    if [[ -z "$timestamp" || -z "$level" || -z "$message" ]]; then
        echo "ERROR: Timestamp, level, and message are required" >&2
        return 1
    fi
    
    # Escape message for JSON safely
    local escaped_message
    escaped_message=$(echo "$message" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\x08/\\b/g; s/\x0c/\\f/g; s/\n/\\n/g; s/\r/\\r/g; s/\t/\\t/g')
    
    cat << EOF
{"timestamp":"$timestamp","level":"$level","message":"$escaped_message","component":"$component","session_id":"$SESSION_ID","correlation_id":"$CORRELATION_ID","hostname":"$HOSTNAME","username":"$USERNAME","process_id":"$PROCESS_ID","script_name":"$SCRIPT_NAME","caller_info":$caller_info,"additional_data":$additional_data}
EOF
}

# Get caller information with validation
get_caller_info() {
    local depth="${1:-1}"
    local caller_function="${FUNCNAME[$((depth + 1))]:-main}"
    local caller_file="${BASH_SOURCE[$((depth + 1))]:-unknown}"
    local caller_line="${BASH_LINENO[$depth]:-0}"
    
    # Sanitize file path for security
    caller_file=$(basename "$caller_file" 2>/dev/null || echo "unknown")
    
    cat << EOF
{"function":"$caller_function","file":"$caller_file","line":$caller_line,"full_path":"$(sanitize_log_input "${BASH_SOURCE[$((depth + 1))]:-unknown}" 200)"}
EOF
}

# Check if we should log this level
should_log() {
    local level="$1"
    local level_num="${LOG_LEVELS[$level]:-2}"
    local configured_level_num="${LOG_LEVELS[$ENTERPRISE_LOG_LEVEL]:-2}"
    
    [[ $level_num -ge $configured_level_num ]]
}

# Generate ISO8601 timestamp
iso8601_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%S.%3NZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# Get high precision timestamp
get_high_precision_timestamp() {
    date +%s.%N 2>/dev/null || date +%s
}

# System monitoring functions with error handling
get_memory_usage() {
    if command -v ps >/dev/null 2>&1; then
        ps -o rss= -p $$ 2>/dev/null | awk '{print $1/1024}' || echo "0"
    else
        echo "0"
    fi
}

get_cpu_usage() {
    if command -v ps >/dev/null 2>&1; then
        ps -o %cpu= -p $$ 2>/dev/null | awk '{print $1}' || echo "0"
    else
        echo "0"
    fi
}

get_disk_usage() {
    if command -v df >/dev/null 2>&1; then
        df "$LOG_BASE_DIR" 2>/dev/null | awk 'NR==2 {print $3/1024}' || echo "0"
    else
        echo "0"
    fi
}

get_load_average() {
    if [[ -f /proc/loadavg ]]; then
        cut -d' ' -f1-3 /proc/loadavg 2>/dev/null || echo "0 0 0"
    else
        uptime 2>/dev/null | awk -F'load average:' '{print $2}' | sed 's/^[[:space:]]*//' || echo "0 0 0"
    fi
}

get_open_files_count() {
    if command -v lsof >/dev/null 2>&1; then
        lsof -p $$ 2>/dev/null | wc -l || echo "0"
    else
        echo "0"
    fi
}

get_source_ip() {
    echo "${SSH_CLIENT%% *}" 2>/dev/null || echo "127.0.0.1"
}

# Console output with improved formatting
output_console_log() {
    local level="$1"
    local message="$2"
    local component="$3"
    local timestamp="$4"
    
    # Color codes for different log levels
    local color=""
    case "$level" in
        "TRACE") color="\033[0;37m" ;;      # Light gray
        "DEBUG") color="\033[0;36m" ;;      # Cyan
        "INFO") color="\033[0;32m" ;;       # Green
        "WARN") color="\033[1;33m" ;;       # Yellow
        "ERROR") color="\033[0;31m" ;;      # Red
        "FATAL") color="\033[1;31m" ;;      # Bold red
        "AUDIT") color="\033[0;35m" ;;      # Magenta
        "PERFORMANCE") color="\033[0;34m" ;; # Blue
    esac
    
    local reset="\033[0m"
    local formatted_time
    formatted_time=$(echo "$timestamp" | cut -d'T' -f2 | cut -d'.' -f1)
    
    printf "${color}[%s] [%s] [%s]${reset} %s\n" "$formatted_time" "$level" "$component" "$message"
}

# === ERROR HANDLING ===

# Trigger error alert with validation
trigger_error_alert() {
    local log_entry="$1"
    
    if [[ -z "$log_entry" ]]; then
        echo "ERROR: Log entry required for alert" >&2
        return 1
    fi
    
    # Extract key information safely
    local level="UNKNOWN"
    local message="Unknown error"
    local component="unknown"
    
    if command -v jq >/dev/null 2>&1; then
        level=$(echo "$log_entry" | jq -r '.level // "UNKNOWN"' 2>/dev/null || echo "UNKNOWN")
        message=$(echo "$log_entry" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Unknown error")
        component=$(echo "$log_entry" | jq -r '.component // "unknown"' 2>/dev/null || echo "unknown")
    fi
    
    # Write to alert file for external monitoring systems
    local alert_file="${LOG_ERROR_DIR}/alerts_$(date +%Y%m%d).log"
    echo "[$(iso8601_timestamp)] ALERT: [$level] [$component] $message" >> "$alert_file" 2>/dev/null || true
}

# === LOG ROTATION AND CLEANUP ===

# Setup log rotation with error handling
setup_log_rotation() {
    # Remove old logs beyond retention period
    if command -v find >/dev/null 2>&1; then
        find "$LOG_BASE_DIR" -name "*.jsonl" -mtime +"$LOG_RETENTION_DAYS" -type f -exec mv {} "$LOG_ARCHIVE_DIR/" \; 2>/dev/null || true
        find "$LOG_ARCHIVE_DIR" -name "*.jsonl" -mtime +$((LOG_RETENTION_DAYS * 2)) -type f -delete 2>/dev/null || true
    fi
    
    # Rotate large log files
    rotate_large_logs
}

# Rotate large log files
rotate_large_logs() {
    local log_files=("$LOG_MAIN" "$LOG_AUDIT" "$LOG_PERFORMANCE" "$LOG_SECURITY" "$LOG_FUNCTION_TRACE" "$LOG_ERROR_DETAIL")
    
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            local size_mb
            size_mb=$(du -m "$log_file" 2>/dev/null | cut -f1 || echo "0")
            if [[ $size_mb -gt $MAX_LOG_SIZE_MB ]]; then
                local rotated_file="${log_file}.$(date +%Y%m%d_%H%M%S)"
                if mv "$log_file" "$rotated_file" 2>/dev/null; then
                    init_structured_log_file "$log_file"
                    enterprise_log "INFO" "Log file rotated: $(basename "$log_file")" "logging_framework" \
                        "{\"original_file\":\"$log_file\",\"rotated_file\":\"$rotated_file\",\"size_mb\":$size_mb}"
                fi
            fi
        fi
    done
}

# Cleanup function
cleanup_enterprise_logging() {
    # Log session end
    local end_timestamp
    end_timestamp=$(iso8601_timestamp)
    local session_duration=$(($(date +%s) - ${SESSION_ID%%_*}))
    
    # Calculate total function calls safely
    local total_function_calls=0
    for count in "${FUNCTION_CALL_COUNTS[@]}"; do
        ((total_function_calls += count))
    done
    
    local cleanup_data
    cleanup_data=$(cat << EOF
{
    "session_duration_seconds": $session_duration,
    "total_function_calls": $total_function_calls,
    "error_categories": {},
    "final_memory_usage": $(get_memory_usage),
    "final_cpu_usage": $(get_cpu_usage)
}
EOF
)
    
    enterprise_log "INFO" "Enterprise logging session ended" "logging_framework" "$cleanup_data"
    
    # Write session end markers to all log files
    local log_files=("$LOG_MAIN" "$LOG_AUDIT" "$LOG_PERFORMANCE" "$LOG_SECURITY" "$LOG_FUNCTION_TRACE" "$LOG_ERROR_DETAIL")
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            echo "{\"log_type\":\"session_end\",\"timestamp\":\"$end_timestamp\",\"session_id\":\"$SESSION_ID\",\"correlation_id\":\"$CORRELATION_ID\",\"cleanup_data\":$cleanup_data}" >> "$log_file" 2>/dev/null || true
        fi
    done
}

# === HIGH-LEVEL CONVENIENCE FUNCTIONS ===
log_trace() { enterprise_log "TRACE" "$1" "${2:-general}" "${3:-{}}" "${4:-}"; }
log_debug() { enterprise_log "DEBUG" "$1" "${2:-general}" "${3:-{}}" "${4:-}"; }
log_info() { enterprise_log "INFO" "$1" "${2:-general}" "${3:-{}}" "${4:-}"; }
log_warn() { enterprise_log "WARN" "$1" "${2:-general}" "${3:-{}}" "${4:-}"; }
log_error() { enterprise_log "ERROR" "$1" "${2:-general}" "${3:-{}}" "${4:-}"; }
log_fatal() { enterprise_log "FATAL" "$1" "${2:-general}" "${3:-{}}" "${4:-}"; }

# === INITIALIZATION ===
# Auto-initialize when sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    if ! init_enterprise_logging; then
        echo "WARNING: Enterprise logging initialization failed, logging disabled" >&2
    fi
fi