#!/usr/bin/env bash
#
# Enterprise-Grade Logging Framework
# Comprehensive function tracking, output recording, and error management
# 
# Features:
# - Structured JSON logging with correlation IDs
# - Function entry/exit tracking with call stacks
# - Performance metrics and resource monitoring
# - Error categorization and escalation
# - Audit trails with security compliance
# - Log rotation and archival
# - Real-time alerting integration
# - Distributed tracing support
#

set -euo pipefail
IFS=$'\n\t'

# === FRAMEWORK CONFIGURATION ===
readonly ENTERPRISE_LOGGING_VERSION="2.0.0"
readonly LOGGING_NAMESPACE="${LOGGING_NAMESPACE:-cursor_bundle}"
readonly LOG_BASE_DIR="${LOG_BASE_DIR:-$HOME/.cache/cursor/enterprise-logs}"
readonly SESSION_ID="${SESSION_ID:-$(date +%s)_$$_$(openssl rand -hex 4 2>/dev/null || echo $(($RANDOM * $RANDOM)))}"
readonly CORRELATION_ID="${CORRELATION_ID:-$(uuidgen 2>/dev/null || echo "corr_$(date +%s)_$$")}"

# Log directories structure
readonly LOG_STRUCTURED_DIR="$LOG_BASE_DIR/structured"
readonly LOG_AUDIT_DIR="$LOG_BASE_DIR/audit" 
readonly LOG_PERFORMANCE_DIR="$LOG_BASE_DIR/performance"
readonly LOG_SECURITY_DIR="$LOG_BASE_DIR/security"
readonly LOG_FUNCTION_DIR="$LOG_BASE_DIR/function-traces"
readonly LOG_ERROR_DIR="$LOG_BASE_DIR/errors"
readonly LOG_ARCHIVE_DIR="$LOG_BASE_DIR/archive"

# Log files
readonly LOG_MAIN="$LOG_STRUCTURED_DIR/main_${SESSION_ID}.jsonl"
readonly LOG_AUDIT="$LOG_AUDIT_DIR/audit_${SESSION_ID}.jsonl"
readonly LOG_PERFORMANCE="$LOG_PERFORMANCE_DIR/perf_${SESSION_ID}.jsonl"
readonly LOG_SECURITY="$LOG_SECURITY_DIR/security_${SESSION_ID}.jsonl"
readonly LOG_FUNCTION_TRACE="$LOG_FUNCTION_DIR/functions_${SESSION_ID}.jsonl"
readonly LOG_ERROR_DETAIL="$LOG_ERROR_DIR/errors_${SESSION_ID}.jsonl"

# Configuration
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

# Error categories
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
)

# Performance tracking
declare -A FUNCTION_START_TIMES=()
declare -A FUNCTION_CALL_COUNTS=()
declare -A FUNCTION_TOTAL_TIME=()
declare -g CALL_STACK_DEPTH=0

# System information
readonly HOSTNAME="${HOSTNAME:-$(hostname 2>/dev/null || echo 'unknown')}"
readonly USERNAME="${USER:-$(whoami 2>/dev/null || echo 'unknown')}"
readonly PROCESS_ID="$$"
readonly PARENT_PROCESS_ID="${PPID:-0}"
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[-1]}" 2>/dev/null || echo 'unknown')"
readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[-1]}")" 2>/dev/null && pwd || echo 'unknown')"

# === INITIALIZATION ===
init_enterprise_logging() {
    # Create directory structure
    local dirs=(
        "$LOG_STRUCTURED_DIR" "$LOG_AUDIT_DIR" "$LOG_PERFORMANCE_DIR"
        "$LOG_SECURITY_DIR" "$LOG_FUNCTION_DIR" "$LOG_ERROR_DIR" "$LOG_ARCHIVE_DIR"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir" 2>/dev/null || {
            echo "ERROR: Cannot create log directory: $dir" >&2
            return 1
        }
    done
    
    # Initialize log files with headers
    init_structured_log_file "$LOG_MAIN"
    init_structured_log_file "$LOG_AUDIT"
    init_structured_log_file "$LOG_PERFORMANCE"
    init_structured_log_file "$LOG_SECURITY"
    init_structured_log_file "$LOG_FUNCTION_TRACE"
    init_structured_log_file "$LOG_ERROR_DETAIL"
    
    # Log session initialization
    enterprise_log "INFO" "Enterprise logging framework initialized" \
        "logging_framework" \
        "{\"version\":\"$ENTERPRISE_LOGGING_VERSION\",\"session_id\":\"$SESSION_ID\",\"correlation_id\":\"$CORRELATION_ID\"}"
    
    # Setup log rotation
    setup_log_rotation
    
    # Setup cleanup on exit
    trap cleanup_enterprise_logging EXIT
    
    return 0
}

init_structured_log_file() {
    local log_file="$1"
    
    cat > "$log_file" << EOF
{"log_type":"session_start","timestamp":"$(iso8601_timestamp)","session_id":"$SESSION_ID","correlation_id":"$CORRELATION_ID","hostname":"$HOSTNAME","username":"$USERNAME","process_id":"$PROCESS_ID","script_name":"$SCRIPT_NAME","script_path":"$SCRIPT_PATH","framework_version":"$ENTERPRISE_LOGGING_VERSION"}
EOF
}

# === CORE LOGGING FUNCTIONS ===
enterprise_log() {
    local level="$1"
    local message="$2"
    local component="${3:-general}"
    local additional_data="${4:-{}}"
    local caller_info="${5:-}"
    
    # Check log level
    if ! should_log "$level"; then
        return 0
    fi
    
    # Generate timestamp and caller information
    local timestamp=$(iso8601_timestamp)
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
        "$additional_data")
    
    # Write to appropriate log files
    echo "$log_entry" >> "$LOG_MAIN"
    
    # Route to specialized logs
    case "$level" in
        "ERROR"|"FATAL")
            echo "$log_entry" >> "$LOG_ERROR_DETAIL"
            [[ "$ALERT_ON_ERRORS" == "true" ]] && trigger_error_alert "$log_entry"
            ((ERROR_CATEGORIES["${component^^}"]++)) 2>/dev/null || ERROR_CATEGORIES["GENERAL"]=$((${ERROR_CATEGORIES["GENERAL"]:-0} + 1))
            ;;
    esac
    
    # Security events
    if [[ "$component" =~ ^(security|auth|validation)$ ]] && [[ "$ENABLE_SECURITY_LOGGING" == "true" ]]; then
        echo "$log_entry" >> "$LOG_SECURITY"
    fi
    
    # Console output with formatting
    output_console_log "$level" "$message" "$component" "$timestamp"
    
    return 0
}

# Function tracing
trace_function_enter() {
    local function_name="$1"
    local args="$2"
    
    [[ "$ENABLE_FUNCTION_TRACING" != "true" ]] && return 0
    
    ((CALL_STACK_DEPTH++))
    FUNCTION_START_TIMES["$function_name"]=$(get_high_precision_timestamp)
    FUNCTION_CALL_COUNTS["$function_name"]=$((${FUNCTION_CALL_COUNTS["$function_name"]:-0} + 1))
    
    local trace_data=$(cat << EOF
{
    "function_name": "$function_name",
    "action": "enter",
    "call_depth": $CALL_STACK_DEPTH,
    "arguments": "$args",
    "call_count": ${FUNCTION_CALL_COUNTS["$function_name"]},
    "memory_usage": $(get_memory_usage),
    "cpu_usage": $(get_cpu_usage)
}
EOF
)
    
    enterprise_log "TRACE" "Function entered: $function_name" "function_trace" "$trace_data"
    
    if [[ "$ENABLE_FUNCTION_TRACING" == "true" ]]; then
        local function_log_entry=$(create_log_entry \
            "$(iso8601_timestamp)" \
            "TRACE" \
            "Function entered: $function_name" \
            "function_trace" \
            "$(get_caller_info 2)" \
            "$trace_data")
        echo "$function_log_entry" >> "$LOG_FUNCTION_TRACE"
    fi
}

trace_function_exit() {
    local function_name="$1"
    local exit_code="${2:-0}"
    local return_value="${3:-}"
    
    [[ "$ENABLE_FUNCTION_TRACING" != "true" ]] && return 0
    
    local end_time=$(get_high_precision_timestamp)
    local start_time="${FUNCTION_START_TIMES["$function_name"]:-$end_time}"
    local execution_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    
    FUNCTION_TOTAL_TIME["$function_name"]=$(echo "${FUNCTION_TOTAL_TIME["$function_name"]:-0} + $execution_time" | bc -l 2>/dev/null || echo "0")
    ((CALL_STACK_DEPTH > 0)) && ((CALL_STACK_DEPTH--))
    
    local trace_data=$(cat << EOF
{
    "function_name": "$function_name",
    "action": "exit",
    "call_depth": $CALL_STACK_DEPTH,
    "exit_code": $exit_code,
    "return_value": "$return_value",
    "execution_time_seconds": $execution_time,
    "total_time_seconds": ${FUNCTION_TOTAL_TIME["$function_name"]},
    "memory_usage": $(get_memory_usage),
    "cpu_usage": $(get_cpu_usage)
}
EOF
)
    
    enterprise_log "TRACE" "Function exited: $function_name (${execution_time}s)" "function_trace" "$trace_data"
    
    if [[ "$ENABLE_FUNCTION_TRACING" == "true" ]]; then
        local function_log_entry=$(create_log_entry \
            "$(iso8601_timestamp)" \
            "TRACE" \
            "Function exited: $function_name" \
            "function_trace" \
            "$(get_caller_info 2)" \
            "$trace_data")
        echo "$function_log_entry" >> "$LOG_FUNCTION_TRACE"
    fi
    
    # Performance monitoring
    if [[ "$ENABLE_PERFORMANCE_MONITORING" == "true" ]]; then
        log_performance_metrics "$function_name" "$execution_time" "$exit_code"
    fi
}

# Audit logging
audit_log() {
    local action="$1"
    local resource="$2"
    local result="$3"
    local additional_data="${4:-{}}"
    
    [[ "$ENABLE_AUDIT_LOGGING" != "true" ]] && return 0
    
    local audit_data=$(cat << EOF
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
    
    local audit_entry=$(create_log_entry \
        "$(iso8601_timestamp)" \
        "AUDIT" \
        "Audit: $action on $resource -> $result" \
        "audit" \
        "$(get_caller_info 2)" \
        "$audit_data")
    
    echo "$audit_entry" >> "$LOG_AUDIT"
    enterprise_log "INFO" "Audit event: $action" "audit" "$audit_data"
}

# Security logging
security_log() {
    local event_type="$1"
    local description="$2"
    local severity="${3:-MEDIUM}"
    local additional_data="${4:-{}}"
    
    [[ "$ENABLE_SECURITY_LOGGING" != "true" ]] && return 0
    
    local security_data=$(cat << EOF
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

# Performance monitoring
log_performance_metrics() {
    local operation="$1"
    local execution_time="$2"
    local exit_code="${3:-0}"
    
    [[ "$ENABLE_PERFORMANCE_MONITORING" != "true" ]] && return 0
    
    local perf_data=$(cat << EOF
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
    
    local perf_entry=$(create_log_entry \
        "$(iso8601_timestamp)" \
        "PERFORMANCE" \
        "Performance metrics for: $operation" \
        "performance" \
        "$(get_caller_info 2)" \
        "$perf_data")
    
    echo "$perf_entry" >> "$LOG_PERFORMANCE"
}

# === UTILITY FUNCTIONS ===
create_log_entry() {
    local timestamp="$1"
    local level="$2"
    local message="$3"
    local component="$4"
    local caller_info="$5"
    local additional_data="$6"
    
    # Escape message for JSON
    local escaped_message=$(echo "$message" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\x08/\\b/g; s/\x0c/\\f/g; s/\n/\\n/g; s/\r/\\r/g; s/\t/\\t/g')
    
    cat << EOF
{"timestamp":"$timestamp","level":"$level","message":"$escaped_message","component":"$component","session_id":"$SESSION_ID","correlation_id":"$CORRELATION_ID","hostname":"$HOSTNAME","username":"$USERNAME","process_id":"$PROCESS_ID","script_name":"$SCRIPT_NAME","caller_info":$caller_info,"additional_data":$additional_data}
EOF
}

get_caller_info() {
    local depth="${1:-1}"
    local caller_function="${FUNCNAME[$((depth + 1))]:-main}"
    local caller_file="${BASH_SOURCE[$((depth + 1))]:-unknown}"
    local caller_line="${BASH_LINENO[$depth]:-0}"
    
    cat << EOF
{"function":"$caller_function","file":"$(basename "$caller_file")","line":$caller_line,"full_path":"$caller_file"}
EOF
}

should_log() {
    local level="$1"
    local level_num="${LOG_LEVELS[$level]:-2}"
    local configured_level_num="${LOG_LEVELS[$ENTERPRISE_LOG_LEVEL]:-2}"
    
    [[ $level_num -ge $configured_level_num ]]
}

iso8601_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%S.%3NZ" 2>/dev/null || date -u +"%Y-%m-%dT%H:%M:%SZ"
}

get_high_precision_timestamp() {
    date +%s.%N 2>/dev/null || date +%s
}

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
        cat /proc/loadavg 2>/dev/null | cut -d' ' -f1-3 || echo "0 0 0"
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

output_console_log() {
    local level="$1"
    local message="$2"
    local component="$3"
    local timestamp="$4"
    
    # Color codes
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
    local formatted_time=$(echo "$timestamp" | cut -d'T' -f2 | cut -d'.' -f1)
    
    printf "${color}[%s] [%s] [%s]${reset} %s\n" "$formatted_time" "$level" "$component" "$message"
}

# === ERROR HANDLING ===
trigger_error_alert() {
    local log_entry="$1"
    
    # Extract key information
    local level=$(echo "$log_entry" | jq -r '.level // "UNKNOWN"' 2>/dev/null || echo "UNKNOWN")
    local message=$(echo "$log_entry" | jq -r '.message // "Unknown error"' 2>/dev/null || echo "Unknown error")
    local component=$(echo "$log_entry" | jq -r '.component // "unknown"' 2>/dev/null || echo "unknown")
    
    # Write to alert file for external monitoring systems
    local alert_file="$LOG_ERROR_DIR/alerts_$(date +%Y%m%d).log"
    echo "[$(iso8601_timestamp)] ALERT: [$level] [$component] $message" >> "$alert_file"
    
    # Integrate with external alerting systems
    if command -v send_external_alert >/dev/null 2>&1; then
        # Extract alert details from log entry
        local alert_severity="HIGH"
        case "$level" in
            "CRITICAL"|"FATAL") alert_severity="CRITICAL" ;;
            "ERROR") alert_severity="HIGH" ;;
            "WARN") alert_severity="MEDIUM" ;;
            *) alert_severity="LOW" ;;
        esac
        
        send_external_alert "$alert_severity" "System Alert: $component" "$message" "$component"
    else
        # Fallback: source the external alerting system if available
        local alerting_script="$(dirname "${BASH_SOURCE[0]}")/external_alerting_system.sh"
        if [[ -f "$alerting_script" ]]; then
            source "$alerting_script"
            local alert_severity="HIGH"
            case "$level" in
                "CRITICAL"|"FATAL") alert_severity="CRITICAL" ;;
                "ERROR") alert_severity="HIGH" ;;
                "WARN") alert_severity="MEDIUM" ;;
                *) alert_severity="LOW" ;;
            esac
            send_external_alert "$alert_severity" "System Alert: $component" "$message" "$component"
        fi
    fi
}

# === LOG ROTATION AND CLEANUP ===
setup_log_rotation() {
    # Remove old logs beyond retention period
    if command -v find >/dev/null 2>&1; then
        find "$LOG_BASE_DIR" -name "*.jsonl" -mtime +$LOG_RETENTION_DAYS -exec mv {} "$LOG_ARCHIVE_DIR/" \; 2>/dev/null || true
        find "$LOG_ARCHIVE_DIR" -name "*.jsonl" -mtime +$((LOG_RETENTION_DAYS * 2)) -delete 2>/dev/null || true
    fi
    
    # Rotate large log files
    rotate_large_logs
}

rotate_large_logs() {
    local log_files=("$LOG_MAIN" "$LOG_AUDIT" "$LOG_PERFORMANCE" "$LOG_SECURITY" "$LOG_FUNCTION_TRACE" "$LOG_ERROR_DETAIL")
    
    for log_file in "${log_files[@]}"; do
        if [[ -f "$log_file" ]]; then
            local size_mb=$(du -m "$log_file" 2>/dev/null | cut -f1 || echo "0")
            if [[ $size_mb -gt $MAX_LOG_SIZE_MB ]]; then
                local rotated_file="${log_file}.$(date +%Y%m%d_%H%M%S)"
                mv "$log_file" "$rotated_file"
                init_structured_log_file "$log_file"
                enterprise_log "INFO" "Log file rotated: $(basename "$log_file")" "logging_framework" \
                    "{\"original_file\":\"$log_file\",\"rotated_file\":\"$rotated_file\",\"size_mb\":$size_mb}"
            fi
        fi
    done
}

cleanup_enterprise_logging() {
    # Log session end
    local end_timestamp=$(iso8601_timestamp)
    local session_duration=$(($(date +%s) - ${SESSION_ID%%_*}))
    
    local cleanup_data=$(cat << EOF
{
    "session_duration_seconds": $session_duration,
    "total_function_calls": $(( $(IFS=+; echo "${FUNCTION_CALL_COUNTS[*]:-0}") )),
    "error_categories": $(printf '%s\n' "${!ERROR_CATEGORIES[@]}" "${ERROR_CATEGORIES[@]}" | paste -d: - - | jq -Rs 'split("\n")[:-1] | map(split(":")) | from_entries' 2>/dev/null || echo '{}'),
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
            echo "{\"log_type\":\"session_end\",\"timestamp\":\"$end_timestamp\",\"session_id\":\"$SESSION_ID\",\"correlation_id\":\"$CORRELATION_ID\",\"cleanup_data\":$cleanup_data}" >> "$log_file"
        fi
    done
}

# === FUNCTION DECORATORS ===
# Automatically trace function calls
trace_function() {
    local func_name="$1"
    shift
    local args="$*"
    
    trace_function_enter "$func_name" "$args"
    local result=0
    local output=""
    
    # Execute function and capture output and exit code
    if output=$("$func_name" "$@" 2>&1); then
        result=0
    else
        result=$?
    fi
    
    trace_function_exit "$func_name" "$result" "$output"
    
    # Return the output and preserve exit code
    echo "$output"
    return $result
}

# === REPORTING FUNCTIONS ===
generate_enterprise_log_report() {
    local report_file="$LOG_BASE_DIR/enterprise_log_report_$(date +%Y%m%d_%H%M%S).json"
    
    local total_errors=$(grep -c '"level":"ERROR"' "$LOG_MAIN" 2>/dev/null || echo "0")
    local total_warnings=$(grep -c '"level":"WARN"' "$LOG_MAIN" 2>/dev/null || echo "0")
    local total_info=$(grep -c '"level":"INFO"' "$LOG_MAIN" 2>/dev/null || echo "0")
    local total_functions=$(wc -l < "$LOG_FUNCTION_TRACE" 2>/dev/null || echo "0")
    
    cat > "$report_file" << EOF
{
    "report_type": "enterprise_logging_summary",
    "generated_at": "$(iso8601_timestamp)",
    "session_id": "$SESSION_ID",
    "correlation_id": "$CORRELATION_ID",
    "summary": {
        "total_errors": $total_errors,
        "total_warnings": $total_warnings,
        "total_info_messages": $total_info,
        "total_function_calls": $total_functions,
        "error_categories": $(printf '%s\n' "${!ERROR_CATEGORIES[@]}" "${ERROR_CATEGORIES[@]}" | paste -d: - - | jq -Rs 'split("\n")[:-1] | map(split(":")) | from_entries' 2>/dev/null || echo '{}'),
        "function_performance": $(generate_function_performance_summary)
    },
    "log_files": {
        "main_log": "$LOG_MAIN",
        "audit_log": "$LOG_AUDIT",
        "performance_log": "$LOG_PERFORMANCE", 
        "security_log": "$LOG_SECURITY",
        "function_trace": "$LOG_FUNCTION_TRACE",
        "error_details": "$LOG_ERROR_DETAIL"
    }
}
EOF
    
    enterprise_log "INFO" "Enterprise log report generated: $report_file" "logging_framework" \
        "{\"report_file\":\"$report_file\",\"total_errors\":$total_errors,\"total_warnings\":$total_warnings}"
    
    echo "$report_file"
}

generate_function_performance_summary() {
    if [[ ${#FUNCTION_TOTAL_TIME[@]} -eq 0 ]]; then
        echo "{}"
        return
    fi
    
    local performance_data="{"
    local first=true
    
    for func_name in "${!FUNCTION_TOTAL_TIME[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            performance_data+=","
        fi
        
        performance_data+="\"$func_name\":{\"total_time\":${FUNCTION_TOTAL_TIME[$func_name]},\"call_count\":${FUNCTION_CALL_COUNTS[$func_name]:-0}}"
    done
    
    performance_data+="}"
    echo "$performance_data"
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
    init_enterprise_logging
fi