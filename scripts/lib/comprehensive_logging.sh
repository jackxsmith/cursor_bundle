#!/usr/bin/env bash
# Comprehensive Logging System for Cursor Bundle
# Provides detailed function tracking, error logging, update logs, and todo logs

set -euo pipefail
IFS=$'\n\t'

# Source error handling library if not already loaded
if ! declare -f log_error >/dev/null 2>&1; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "$SCRIPT_DIR/error_handling.sh" ]]; then
        source "$SCRIPT_DIR/error_handling.sh"
    fi
fi

# Logging configuration
declare -g LOG_BASE_DIR="${LOG_BASE_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/cursor-bundle/logs}"
declare -g LOG_DATE="$(date '+%Y%m%d')"
declare -g LOG_SESSION="$(date '+%Y%m%d_%H%M%S')"

# Log files
declare -g FUNCTION_LOG="$LOG_BASE_DIR/functions/function_${LOG_SESSION}.log"
declare -g ERROR_LOG="$LOG_BASE_DIR/errors/error_${LOG_SESSION}.log"
declare -g UPDATE_LOG="$LOG_BASE_DIR/updates/update_${LOG_SESSION}.log"
declare -g TODO_LOG="$LOG_BASE_DIR/todos/todo_${LOG_SESSION}.log"
declare -g PERFORMANCE_LOG="$LOG_BASE_DIR/performance/performance_${LOG_SESSION}.log"
declare -g AUDIT_LOG="$LOG_BASE_DIR/audit/audit_${LOG_SESSION}.log"

# Logging levels and configuration
declare -A LOG_LEVELS=(
    ["TRACE"]=0
    ["DEBUG"]=1
    ["INFO"]=2
    ["WARN"]=3
    ["ERROR"]=4
    ["FATAL"]=5
)

declare -A LOG_COLORS=(
    ["TRACE"]="\\033[0;90m"     # Dark Gray
    ["DEBUG"]="\\033[0;94m"     # Blue
    ["INFO"]="\\033[0;92m"      # Green
    ["WARN"]="\\033[0;93m"      # Yellow
    ["ERROR"]="\\033[0;91m"     # Red
    ["FATAL"]="\\033[1;91m"     # Bold Red
    ["RESET"]="\\033[0m"        # Reset
)

declare -g LOG_LEVEL="${LOG_LEVEL:-INFO}"
declare -g LOG_FUNCTION_CALLS="${LOG_FUNCTION_CALLS:-true}"
declare -g LOG_PERFORMANCE="${LOG_PERFORMANCE:-true}"
declare -g LOG_TO_CONSOLE="${LOG_TO_CONSOLE:-true}"
declare -g LOG_JSON_FORMAT="${LOG_JSON_FORMAT:-false}"

# Function call stack tracking
declare -a FUNCTION_CALL_STACK=()
declare -A FUNCTION_START_TIMES=()
declare -A FUNCTION_CALL_COUNT=()

# Initialize comprehensive logging
init_comprehensive_logging() {
    local context="init_comprehensive_logging"
    
    # Create log directories
    local log_dirs=(
        "$LOG_BASE_DIR/functions"
        "$LOG_BASE_DIR/errors"
        "$LOG_BASE_DIR/updates"
        "$LOG_BASE_DIR/todos"
        "$LOG_BASE_DIR/performance"
        "$LOG_BASE_DIR/audit"
    )
    
    for dir in "${log_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir" || {
                echo "WARNING: Cannot create log directory: $dir" >&2
                return 1
            }
        fi
    done
    
    # Initialize log files with headers
    init_log_file "$FUNCTION_LOG" "FUNCTION CALLS"
    init_log_file "$ERROR_LOG" "ERROR TRACKING"
    init_log_file "$UPDATE_LOG" "UPDATE HISTORY"
    init_log_file "$TODO_LOG" "TODO TRACKING"
    init_log_file "$PERFORMANCE_LOG" "PERFORMANCE METRICS"
    init_log_file "$AUDIT_LOG" "AUDIT TRAIL"
    
    # Set up signal handlers
    trap 'cleanup_logging' EXIT
    trap 'handle_logging_interrupt' INT TERM
    
    log_comprehensive "INFO" "Comprehensive logging initialized" "$context" \
        "session=$LOG_SESSION" "log_level=$LOG_LEVEL"
}

# Initialize individual log file
init_log_file() {
    local log_file="$1"
    local log_type="$2"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    cat > "$log_file" <<EOF
# $log_type LOG - Session: $LOG_SESSION
# Started: $timestamp
# Format: [timestamp] [level] [function] [context] message [metadata]
EOF
}

# Core comprehensive logging function
log_comprehensive() {
    local level="${1:-INFO}"
    local message="${2:-}"
    local context="${3:-${FUNCNAME[2]:-unknown}}"
    local metadata="${4:-}"
    local log_file="${5:-}"
    
    # Check if logging level is enabled
    if [[ "${LOG_LEVELS[$level]:-2}" -lt "${LOG_LEVELS[$LOG_LEVEL]:-2}" ]]; then
        return 0
    fi
    
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S.%3N')"
    local pid="$$"
    local thread_id="${BASH_SUBSHELL:-0}"
    
    # Format log entry
    local log_entry
    if [[ "$LOG_JSON_FORMAT" == "true" ]]; then
        log_entry=$(format_json_log_entry "$timestamp" "$level" "$context" "$message" "$metadata" "$pid" "$thread_id")
    else
        log_entry=$(format_text_log_entry "$timestamp" "$level" "$context" "$message" "$metadata" "$pid" "$thread_id")
    fi
    
    # Write to appropriate log files
    write_to_log_files "$log_entry" "$level" "$log_file"
    
    # Write to console if enabled
    if [[ "$LOG_TO_CONSOLE" == "true" ]]; then
        write_to_console "$level" "$context" "$message" "$timestamp"
    fi
}

# Format JSON log entry
format_json_log_entry() {
    local timestamp="$1" level="$2" context="$3" message="$4" metadata="$5" pid="$6" thread_id="$7"
    local call_stack_json="$(printf '%s\n' "${FUNCTION_CALL_STACK[@]}" | jq -R . | jq -s .)"
    
    jq -n \
        --arg timestamp "$timestamp" \
        --arg level "$level" \
        --arg context "$context" \
        --arg message "$message" \
        --arg metadata "$metadata" \
        --arg pid "$pid" \
        --arg thread_id "$thread_id" \
        --arg session "$LOG_SESSION" \
        --argjson call_stack "$call_stack_json" \
        '{
            timestamp: $timestamp,
            level: $level,
            context: $context,
            message: $message,
            metadata: $metadata,
            process: {
                pid: $pid,
                thread_id: $thread_id,
                session: $session
            },
            call_stack: $call_stack
        }'
}

# Format text log entry
format_text_log_entry() {
    local timestamp="$1" level="$2" context="$3" message="$4" metadata="$5" pid="$6" thread_id="$7"
    local stack_depth="${#FUNCTION_CALL_STACK[@]}"
    local indent="$(printf "%*s" $((stack_depth * 2)) "")"
    
    printf "[%s] [%s] [%s:%s:%s] %s%s %s" \
        "$timestamp" \
        "$level" \
        "$pid" \
        "$thread_id" \
        "$context" \
        "$indent" \
        "$message" \
        "${metadata:+[$metadata]}"
}

# Write to log files
write_to_log_files() {
    local log_entry="$1"
    local level="$2"
    local specific_log="$3"
    
    # Write to main function log
    echo "$log_entry" >> "$FUNCTION_LOG"
    
    # Write to specific log file if provided
    if [[ -n "$specific_log" ]] && [[ -f "$specific_log" ]]; then
        echo "$log_entry" >> "$specific_log"
    fi
    
    # Write to error log for errors and warnings
    if [[ "$level" == "ERROR" ]] || [[ "$level" == "FATAL" ]] || [[ "$level" == "WARN" ]]; then
        echo "$log_entry" >> "$ERROR_LOG"
    fi
    
    # Write to audit log for important events
    if [[ "$level" == "INFO" ]] || [[ "$level" == "WARN" ]] || [[ "$level" == "ERROR" ]] || [[ "$level" == "FATAL" ]]; then
        echo "$log_entry" >> "$AUDIT_LOG"
    fi
}

# Write to console with colors
write_to_console() {
    local level="$1" context="$2" message="$3" timestamp="$4"
    local color="${LOG_COLORS[$level]:-}"
    local reset="${LOG_COLORS[RESET]}"
    local stack_depth="${#FUNCTION_CALL_STACK[@]}"
    local indent="$(printf "%*s" $((stack_depth * 2)) "")"
    
    printf "${color}[%s] [%s] %s%s${reset}\n" \
        "$level" \
        "$context" \
        "$indent" \
        "$message" >&2
}

# Function call tracking
track_function_entry() {
    local function_name="${1:-${FUNCNAME[1]:-unknown}}"
    local args="$2"
    local context="track_function_entry"
    
    if [[ "$LOG_FUNCTION_CALLS" != "true" ]]; then
        return 0
    fi
    
    local start_time="$(date +%s.%N)"
    local call_id="${function_name}_${start_time}"
    
    # Add to call stack
    FUNCTION_CALL_STACK+=("$function_name")
    FUNCTION_START_TIMES["$call_id"]="$start_time"
    FUNCTION_CALL_COUNT["$function_name"]=$((${FUNCTION_CALL_COUNT["$function_name"]:-0} + 1))
    
    # Log function entry
    log_comprehensive "TRACE" "→ ENTER $function_name" "$function_name" \
        "args=[$args] call_count=${FUNCTION_CALL_COUNT["$function_name"]} call_id=$call_id"
    
    echo "$call_id"
}

# Function exit tracking
track_function_exit() {
    local function_name="${1:-${FUNCNAME[1]:-unknown}}"
    local call_id="$2"
    local exit_code="${3:-0}"
    local return_value="$4"
    local context="track_function_exit"
    
    if [[ "$LOG_FUNCTION_CALLS" != "true" ]]; then
        return 0
    fi
    
    local end_time="$(date +%s.%N)"
    local start_time="${FUNCTION_START_TIMES["$call_id"]:-$end_time}"
    local duration="$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")"
    
    # Remove from call stack
    if [[ ${#FUNCTION_CALL_STACK[@]} -gt 0 ]]; then
        unset 'FUNCTION_CALL_STACK[-1]'
    fi
    
    # Clean up timing data
    unset FUNCTION_START_TIMES["$call_id"]
    
    # Log function exit
    log_comprehensive "TRACE" "← EXIT $function_name" "$function_name" \
        "exit_code=$exit_code duration=${duration}s return=[$return_value] call_id=$call_id"
    
    # Log performance data
    if [[ "$LOG_PERFORMANCE" == "true" ]]; then
        log_performance "$function_name" "$duration" "$exit_code" "$call_id"
    fi
}

# Performance logging
log_performance() {
    local function_name="$1"
    local duration="$2"
    local exit_code="$3"
    local call_id="$4"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S.%3N')"
    
    local perf_entry="$timestamp,$function_name,$duration,$exit_code,$call_id,${FUNCTION_CALL_COUNT["$function_name"]:-0}"
    echo "$perf_entry" >> "$PERFORMANCE_LOG"
}

# Error logging with enhanced context
log_error_enhanced() {
    local level="$1"
    local error_message="$2"
    local context="${3:-${FUNCNAME[1]:-unknown}}"
    local error_code="${4:-1}"
    local additional_context="$5"
    
    local stack_trace="$(get_detailed_stack_trace)"
    local system_info="$(get_system_context)"
    local git_info="$(get_git_context)"
    
    local metadata="error_code=$error_code pid=$$ $(date +%s) stack_depth=${#FUNCTION_CALL_STACK[@]}"
    [[ -n "$additional_context" ]] && metadata="$metadata $additional_context"
    
    log_comprehensive "$level" "$error_message" "$context" "$metadata" "$ERROR_LOG"
    
    # Add detailed context to error log
    if [[ "$level" == "ERROR" ]] || [[ "$level" == "FATAL" ]]; then
        {
            echo "--- ERROR CONTEXT START ---"
            echo "Stack Trace:"
            echo "$stack_trace"
            echo "System Info:"
            echo "$system_info"
            echo "Git Context:"
            echo "$git_info"
            echo "Function Call Stack: ${FUNCTION_CALL_STACK[*]}"
            echo "--- ERROR CONTEXT END ---"
            echo ""
        } >> "$ERROR_LOG"
    fi
}

# Update logging
log_update() {
    local update_type="$1"
    local old_value="$2"
    local new_value="$3"
    local context="${4:-${FUNCNAME[1]:-unknown}}"
    local additional_info="$5"
    
    local metadata="type=$update_type old=[$old_value] new=[$new_value]"
    [[ -n "$additional_info" ]] && metadata="$metadata $additional_info"
    
    log_comprehensive "INFO" "UPDATE: $update_type" "$context" "$metadata" "$UPDATE_LOG"
}

# Todo logging
log_todo() {
    local action="$1"        # CREATE, UPDATE, COMPLETE, DELETE
    local todo_id="$2"
    local todo_content="$3"
    local status="$4"
    local priority="$5"
    local context="${6:-${FUNCNAME[1]:-unknown}}"
    
    local metadata="action=$action id=$todo_id status=$status priority=$priority"
    
    log_comprehensive "INFO" "TODO $action: $todo_content" "$context" "$metadata" "$TODO_LOG"
}

# Get detailed stack trace
get_detailed_stack_trace() {
    local i
    local stack_info=""
    
    for ((i = 1; i < ${#BASH_SOURCE[@]}; i++)); do
        if [[ -n "${BASH_SOURCE[$i]:-}" ]]; then
            stack_info="${stack_info}  Frame $i: ${FUNCNAME[$i]:-main}() at ${BASH_SOURCE[$i]##*/}:${BASH_LINENO[$((i-1))]}\n"
        fi
    done
    
    echo -e "$stack_info"
}

# Get system context
get_system_context() {
    cat <<EOF
  PID: $$
  PPID: $PPID
  User: $(whoami)
  Working Directory: $(pwd)
  Shell: $BASH_VERSION
  Date: $(date)
  Uptime: $(uptime)
  Memory: $(free -h 2>/dev/null | head -2 | tail -1 || echo "unknown")
EOF
}

# Get git context
get_git_context() {
    if git rev-parse --git-dir >/dev/null 2>&1; then
        cat <<EOF
  Repository: $(git remote get-url origin 2>/dev/null || echo "unknown")
  Branch: $(git branch --show-current 2>/dev/null || echo "unknown")
  Commit: $(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
  Status: $(git status --porcelain 2>/dev/null | wc -l) files modified
  Last Commit: $(git log -1 --oneline 2>/dev/null || echo "unknown")
EOF
    else
        echo "  Not in a git repository"
    fi
}

# Function wrapper for automatic logging
wrap_function_with_logging() {
    local function_name="$1"
    local original_function="${function_name}_original"
    
    # Check if function exists
    if ! declare -f "$function_name" >/dev/null; then
        log_error_enhanced "WARN" "Cannot wrap non-existent function: $function_name" "wrap_function_with_logging"
        return 1
    fi
    
    # Create backup of original function
    eval "${original_function}() $(declare -f "$function_name" | sed '1d')"
    
    # Create wrapped version
    eval "$function_name() {
        local call_id=\$(track_function_entry '$function_name' \"\$*\")
        local result=0
        local output=''
        
        # Execute original function and capture output and exit code
        if output=\$($original_function \"\$@\" 2>&1); then
            result=\$?
        else
            result=\$?
        fi
        
        track_function_exit '$function_name' \"\$call_id\" \"\$result\" \"\$output\"
        
        # Return output and preserve exit code
        [[ -n \"\$output\" ]] && echo \"\$output\"
        return \$result
    }"
}

# Batch function wrapping
wrap_all_functions() {
    local functions_to_wrap=("$@")
    local wrapped_count=0
    
    if [[ ${#functions_to_wrap[@]} -eq 0 ]]; then
        # Auto-detect functions to wrap
        functions_to_wrap=($(declare -F | grep -v "declare -f _" | awk '{print $3}' | grep -E '^[a-zA-Z_][a-zA-Z0-9_]*$'))
    fi
    
    for func in "${functions_to_wrap[@]}"; do
        if wrap_function_with_logging "$func"; then
            ((wrapped_count++))
        fi
    done
    
    log_comprehensive "INFO" "Wrapped $wrapped_count functions with logging" "wrap_all_functions"
}

# Log rotation and cleanup
rotate_logs() {
    local max_log_files="${1:-10}"
    local max_log_age_days="${2:-7}"
    local context="rotate_logs"
    
    log_comprehensive "INFO" "Starting log rotation" "$context" "max_files=$max_log_files max_age=${max_log_age_days}d"
    
    # Rotate each log type
    local log_types=("functions" "errors" "updates" "todos" "performance" "audit")
    
    for log_type in "${log_types[@]}"; do
        local log_dir="$LOG_BASE_DIR/$log_type"
        if [[ -d "$log_dir" ]]; then
            # Remove old logs
            find "$log_dir" -name "*.log" -type f -mtime +$max_log_age_days -delete 2>/dev/null || true
            
            # Keep only recent logs
            ls -t "$log_dir"/*.log 2>/dev/null | tail -n +$((max_log_files + 1)) | xargs rm -f 2>/dev/null || true
        fi
    done
    
    log_comprehensive "INFO" "Log rotation completed" "$context"
}

# Generate logging report
generate_logging_report() {
    local report_file="${1:-$LOG_BASE_DIR/report_${LOG_SESSION}.html}"
    local context="generate_logging_report"
    
    log_comprehensive "INFO" "Generating logging report" "$context" "output=$report_file"
    
    cat > "$report_file" <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Cursor Bundle Logging Report - Session $LOG_SESSION</title>
    <style>
        body { font-family: monospace; margin: 20px; }
        .section { margin: 20px 0; border: 1px solid #ccc; padding: 10px; }
        .error { color: red; }
        .warn { color: orange; }
        .info { color: blue; }
        .debug { color: gray; }
        .trace { color: lightgray; }
        pre { background: #f5f5f5; padding: 10px; overflow-x: auto; }
    </style>
</head>
<body>
    <h1>Cursor Bundle Logging Report</h1>
    <p>Session: $LOG_SESSION</p>
    <p>Generated: $(date)</p>
    
    <div class="section">
        <h2>Function Call Summary</h2>
        <pre>$(generate_function_summary)</pre>
    </div>
    
    <div class="section">
        <h2>Error Summary</h2>
        <pre>$(generate_error_summary)</pre>
    </div>
    
    <div class="section">
        <h2>Performance Summary</h2>
        <pre>$(generate_performance_summary)</pre>
    </div>
    
    <div class="section">
        <h2>Update History</h2>
        <pre>$(tail -50 "$UPDATE_LOG" 2>/dev/null || echo "No updates logged")</pre>
    </div>
    
    <div class="section">
        <h2>Todo Activity</h2>
        <pre>$(tail -50 "$TODO_LOG" 2>/dev/null || echo "No todo activity logged")</pre>
    </div>
</body>
</html>
EOF
    
    log_comprehensive "INFO" "Logging report generated" "$context" "file=$report_file"
}

# Generate function call summary
generate_function_summary() {
    if [[ -f "$FUNCTION_LOG" ]]; then
        echo "Top 10 Most Called Functions:"
        grep "→ ENTER" "$FUNCTION_LOG" | awk '{print $6}' | sort | uniq -c | sort -nr | head -10
        echo ""
        echo "Function Call Timeline:"
        grep -E "→ ENTER|← EXIT" "$FUNCTION_LOG" | tail -20
    else
        echo "No function calls logged"
    fi
}

# Generate error summary
generate_error_summary() {
    if [[ -f "$ERROR_LOG" ]]; then
        echo "Error Count by Level:"
        grep -E "^\[.*\] \[(ERROR|WARN|FATAL)\]" "$ERROR_LOG" | awk '{print $3}' | tr -d '[]' | sort | uniq -c
        echo ""
        echo "Recent Errors:"
        grep -E "^\[.*\] \[(ERROR|FATAL)\]" "$ERROR_LOG" | tail -10
    else
        echo "No errors logged"
    fi
}

# Generate performance summary
generate_performance_summary() {
    if [[ -f "$PERFORMANCE_LOG" ]]; then
        echo "Top 10 Slowest Functions:"
        tail -n +2 "$PERFORMANCE_LOG" | sort -t, -k3 -nr | head -10 | while IFS=, read -r timestamp func duration exit_code call_id count; do
            printf "%-20s %8.3fs (call #%s)\n" "$func" "$duration" "$count"
        done
        echo ""
        echo "Average Execution Times:"
        tail -n +2 "$PERFORMANCE_LOG" | awk -F, '{sum[$2]+=$3; count[$2]++} END {for(func in sum) printf "%-20s %8.3fs (avg of %d calls)\n", func, sum[func]/count[func], count[func]}' | sort -k2 -nr | head -10
    else
        echo "No performance data logged"
    fi
}

# Cleanup logging resources
cleanup_logging() {
    log_comprehensive "INFO" "Cleaning up logging resources" "cleanup_logging"
    
    # Generate final report
    generate_logging_report
    
    # Clear function call stack
    FUNCTION_CALL_STACK=()
    FUNCTION_START_TIMES=()
    
    log_comprehensive "INFO" "Logging cleanup completed" "cleanup_logging"
}

# Handle logging interrupts
handle_logging_interrupt() {
    log_comprehensive "WARN" "Logging interrupted by signal" "handle_logging_interrupt"
    cleanup_logging
    exit 130
}

# Export all logging functions
export -f init_comprehensive_logging log_comprehensive log_error_enhanced log_update log_todo
export -f track_function_entry track_function_exit wrap_function_with_logging wrap_all_functions
export -f rotate_logs generate_logging_report cleanup_logging

# Auto-initialize if sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    init_comprehensive_logging
fi