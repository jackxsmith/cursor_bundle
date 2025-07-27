#!/usr/bin/env bash
#
# Enterprise Logging Integration Layer
# Comprehensive function interception and automatic logging
#
# This layer automatically instruments ALL functions and commands
# to provide complete visibility into system operations
#

set -euo pipefail
IFS=$'\n\t'

# Source the enterprise logging framework
source "$(dirname "${BASH_SOURCE[0]}")/enterprise_logging_framework.sh"

# === FUNCTION INTERCEPTION FRAMEWORK ===

# Store original function definitions
declare -A ORIGINAL_FUNCTIONS=()
declare -A INSTRUMENTED_FUNCTIONS=()
declare -g INSTRUMENTATION_ENABLED=true

# Intercept and instrument function calls
instrument_function() {
    local func_name="$1"
    
    # Skip if already instrumented
    if [[ "${INSTRUMENTED_FUNCTIONS[$func_name]:-false}" == "true" ]]; then
        return 0
    fi
    
    # Check if function exists
    if ! declare -f "$func_name" >/dev/null 2>&1; then
        log_warn "Cannot instrument non-existent function: $func_name" "instrumentation"
        return 1
    fi
    
    # Store original function
    ORIGINAL_FUNCTIONS["$func_name"]=$(declare -f "$func_name")
    
    # Create instrumented version
    eval "
    ${func_name}_original() {
        $(declare -f "$func_name" | sed '1d;$d')
    }
    
    $func_name() {
        if [[ \"\$INSTRUMENTATION_ENABLED\" == \"true\" ]]; then
            local func_args=\"\$*\"
            local func_start_time=\$(get_high_precision_timestamp)
            
            trace_function_enter \"$func_name\" \"\$func_args\"
            log_debug \"Calling function: $func_name with args: \$func_args\" \"function_call\"
            
            local result=0
            local output=\"\"
            local error_output=\"\"
            
            # Capture both stdout and stderr
            {
                output=\$(${func_name}_original \"\$@\" 2>&1) && result=\$? || result=\$?
            } 2> >(error_output=\$(cat))
            
            local func_end_time=\$(get_high_precision_timestamp)
            local execution_time=\$(echo \"\$func_end_time - \$func_start_time\" | bc -l 2>/dev/null || echo \"0\")
            
            # Log function completion
            if [[ \$result -eq 0 ]]; then
                log_debug \"Function completed successfully: $func_name (${execution_time}s)\" \"function_call\" \
                    \"{\\\"execution_time\\\":\$execution_time,\\\"output_length\\\":\${#output},\\\"exit_code\\\":\$result}\"
            else
                log_error \"Function failed: $func_name (exit code: \$result)\" \"function_call\" \
                    \"{\\\"execution_time\\\":\$execution_time,\\\"output\\\":\\\"\$output\\\",\\\"error_output\\\":\\\"\$error_output\\\",\\\"exit_code\\\":\$result}\"
            fi
            
            trace_function_exit \"$func_name\" \"\$result\" \"\$output\"
            
            # Output the results
            [[ -n \"\$output\" ]] && echo \"\$output\"
            [[ -n \"\$error_output\" ]] && echo \"\$error_output\" >&2
            
            return \$result
        else
            ${func_name}_original \"\$@\"
        fi
    }
    "
    
    INSTRUMENTED_FUNCTIONS["$func_name"]="true"
    log_info "Function instrumented: $func_name" "instrumentation"
}

# Restore original function
restore_function() {
    local func_name="$1"
    
    if [[ "${INSTRUMENTED_FUNCTIONS[$func_name]:-false}" == "true" ]]; then
        # Restore original function definition
        eval "${ORIGINAL_FUNCTIONS[$func_name]}"
        unset INSTRUMENTED_FUNCTIONS["$func_name"]
        unset ORIGINAL_FUNCTIONS["$func_name"]
        
        # Remove instrumented version
        unset -f "${func_name}_original" 2>/dev/null || true
        
        log_info "Function restored: $func_name" "instrumentation"
    fi
}

# Auto-instrument common functions
auto_instrument_common_functions() {
    local common_functions=(
        "validate_required_param"
        "validate_command_exists" 
        "validate_environment"
        "safe_execute"
        "safe_file_operation"
        "validate_network_connectivity"
        "validate_disk_space"
        "git"
        "curl"
        "wget"
        "cp"
        "mv"
        "rm"
        "mkdir"
        "chmod"
        "chown"
    )
    
    log_info "Auto-instrumenting common functions" "instrumentation"
    
    for func in "${common_functions[@]}"; do
        if declare -f "$func" >/dev/null 2>&1; then
            instrument_function "$func" 2>/dev/null || true
        fi
    done
}

# === COMMAND INTERCEPTION ===

# Intercept system commands
setup_command_interception() {
    log_info "Setting up command interception" "command_interception"
    
    # Override common commands with logging versions
    create_logged_command "git"
    create_logged_command "curl" 
    create_logged_command "wget"
    create_logged_command "docker"
    create_logged_command "npm"
    create_logged_command "pip"
    create_logged_command "apt"
    create_logged_command "yum"
    create_logged_command "systemctl"
    create_logged_command "ssh"
    create_logged_command "scp"
    create_logged_command "rsync"
}

create_logged_command() {
    local cmd="$1"
    local original_cmd
    
    # Find the original command
    original_cmd=$(command -v "$cmd" 2>/dev/null) || {
        log_debug "Command not found, skipping interception: $cmd" "command_interception"
        return 0
    }
    
    # Create wrapper function
    eval "
    ${cmd}_logged() {
        local cmd_args=\"\$*\"
        local cmd_start_time=\$(get_high_precision_timestamp)
        local cmd_pwd=\"\$(pwd)\"
        
        log_info \"Executing command: $cmd \$cmd_args\" \"command_execution\" \
            \"{\\\"command\\\":\\\"$cmd\\\",\\\"arguments\\\":\\\"\$cmd_args\\\",\\\"working_directory\\\":\\\"\$cmd_pwd\\\"}\"
        
        audit_log \"COMMAND_EXECUTION\" \"$cmd \$cmd_args\" \"STARTED\" \
            \"{\\\"working_directory\\\":\\\"\$cmd_pwd\\\",\\\"user\\\":\\\"\$USER\\\"}\"
        
        local result=0
        local output=\"\"
        local error_output=\"\"
        
        # Execute the original command and capture output
        {
            output=\$('$original_cmd' \"\$@\" 2>&1) && result=\$? || result=\$?
        } 2> >(error_output=\$(cat))
        
        local cmd_end_time=\$(get_high_precision_timestamp)
        local execution_time=\$(echo \"\$cmd_end_time - \$cmd_start_time\" | bc -l 2>/dev/null || echo \"0\")
        
        # Log command completion
        if [[ \$result -eq 0 ]]; then
            log_info \"Command completed successfully: $cmd (${execution_time}s)\" \"command_execution\" \
                \"{\\\"execution_time\\\":\$execution_time,\\\"exit_code\\\":\$result,\\\"output_lines\\\":\$(echo \"\$output\" | wc -l)}\"
            audit_log \"COMMAND_EXECUTION\" \"$cmd \$cmd_args\" \"SUCCESS\" \
                \"{\\\"execution_time\\\":\$execution_time,\\\"exit_code\\\":\$result}\"
        else
            log_error \"Command failed: $cmd (exit code: \$result)\" \"command_execution\" \
                \"{\\\"execution_time\\\":\$execution_time,\\\"exit_code\\\":\$result,\\\"output\\\":\\\"\$output\\\",\\\"error_output\\\":\\\"\$error_output\\\"}\"
            audit_log \"COMMAND_EXECUTION\" \"$cmd \$cmd_args\" \"FAILURE\" \
                \"{\\\"execution_time\\\":\$execution_time,\\\"exit_code\\\":\$result,\\\"error_output\\\":\\\"\$error_output\\\"}\"
        fi
        
        # Log performance metrics
        log_performance_metrics \"command_\$cmd\" \"\$execution_time\" \"\$result\"
        
        # Output the results
        [[ -n \"\$output\" ]] && echo \"\$output\"
        [[ -n \"\$error_output\" ]] && echo \"\$error_output\" >&2
        
        return \$result
    }
    
    # Create alias to override the command
    alias $cmd='${cmd}_logged'
    "
    
    log_debug "Created logged wrapper for command: $cmd" "command_interception"
}

# === FILE OPERATION LOGGING ===

# Log all file operations with detailed metadata
log_file_operation() {
    local operation="$1"
    local source_file="$2"
    local destination_file="${3:-}"
    local result="${4:-SUCCESS}"
    local additional_data="${5:-{}}"
    
    local file_metadata="{}"
    
    # Gather file metadata
    if [[ -e "$source_file" ]]; then
        local file_size=$(stat -f%z "$source_file" 2>/dev/null || stat -c%s "$source_file" 2>/dev/null || echo "unknown")
        local file_perms=$(stat -f%Mp%Lp "$source_file" 2>/dev/null || stat -c%a "$source_file" 2>/dev/null || echo "unknown")
        local file_owner=$(stat -f%Su "$source_file" 2>/dev/null || stat -c%U "$source_file" 2>/dev/null || echo "unknown")
        local file_modified=$(stat -f%Sm "$source_file" 2>/dev/null || stat -c%y "$source_file" 2>/dev/null || echo "unknown")
        
        file_metadata=$(cat << EOF
{
    "file_size": "$file_size",
    "permissions": "$file_perms", 
    "owner": "$file_owner",
    "last_modified": "$file_modified",
    "file_type": "$(file "$source_file" 2>/dev/null | cut -d: -f2- | sed 's/^[[:space:]]*//' || echo 'unknown')"
}
EOF
)
    fi
    
    local operation_data=$(cat << EOF
{
    "operation": "$operation",
    "source_file": "$source_file",
    "destination_file": "$destination_file",
    "result": "$result",
    "working_directory": "$(pwd)",
    "file_metadata": $file_metadata,
    "additional_data": $additional_data
}
EOF
)
    
    if [[ "$result" == "SUCCESS" ]]; then
        log_info "File operation: $operation on $source_file" "file_operations" "$operation_data"
    else
        log_error "File operation failed: $operation on $source_file" "file_operations" "$operation_data"
    fi
    
    audit_log "FILE_OPERATION" "$source_file" "$result" "$operation_data"
    
    # Security logging for sensitive operations
    case "$operation" in
        "chmod"|"chown"|"delete"|"move")
            security_log "FILE_PERMISSION_CHANGE" "$operation on $source_file" "MEDIUM" "$operation_data"
            ;;
    esac
}

# === VARIABLE AND ENVIRONMENT MONITORING ===

# Track environment variable changes
monitor_environment_changes() {
    local var_name="$1"
    local old_value="${2:-}"
    local new_value="${3:-}"
    
    local env_data=$(cat << EOF
{
    "variable_name": "$var_name",
    "old_value": "$old_value",
    "new_value": "$new_value",
    "process_id": "$$",
    "parent_process": "$PPID"
}
EOF
)
    
    log_info "Environment variable changed: $var_name" "environment" "$env_data"
    audit_log "ENV_VAR_CHANGE" "$var_name" "MODIFIED" "$env_data"
    
    # Security monitoring for sensitive variables
    case "$var_name" in
        *PASSWORD*|*SECRET*|*TOKEN*|*KEY*|*AUTH*)
            security_log "SENSITIVE_VAR_CHANGE" "Sensitive environment variable modified: $var_name" "HIGH" \
                "{\"variable_name\":\"$var_name\",\"change_detected\":true}"
            ;;
    esac
}

# === NETWORK OPERATION LOGGING ===

# Log network operations with detailed connection info
log_network_operation() {
    local operation="$1"
    local target="$2"
    local port="${3:-}"
    local protocol="${4:-}"
    local result="${5:-}"
    local additional_data="${6:-{}}"
    
    local network_data=$(cat << EOF
{
    "operation": "$operation",
    "target": "$target", 
    "port": "$port",
    "protocol": "$protocol",
    "result": "$result",
    "source_ip": "$(get_source_ip)",
    "timestamp": "$(iso8601_timestamp)",
    "additional_data": $additional_data
}
EOF
)
    
    if [[ "$result" == "SUCCESS" ]]; then
        log_info "Network operation: $operation to $target:$port" "network" "$network_data"
    else
        log_warn "Network operation failed: $operation to $target:$port" "network" "$network_data"
    fi
    
    audit_log "NETWORK_OPERATION" "$target:$port" "$result" "$network_data"
    
    # Security monitoring for external connections
    if [[ "$target" != "127.0.0.1" && "$target" != "localhost" ]]; then
        security_log "EXTERNAL_CONNECTION" "$operation to external host $target:$port" "LOW" "$network_data"
    fi
}

# === PROCESS MONITORING ===

# Monitor process lifecycle
log_process_event() {
    local event_type="$1"    # START, STOP, KILL, SPAWN
    local process_name="$2"
    local process_id="${3:-}"
    local parent_id="${4:-}"
    local additional_data="${5:-{}}"
    
    local process_data=$(cat << EOF
{
    "event_type": "$event_type",
    "process_name": "$process_name",
    "process_id": "$process_id",
    "parent_process_id": "$parent_id",
    "user": "$USER",
    "hostname": "$HOSTNAME",
    "additional_data": $additional_data
}
EOF
)
    
    log_info "Process event: $event_type for $process_name (PID: $process_id)" "process_monitoring" "$process_data"
    audit_log "PROCESS_EVENT" "$process_name" "$event_type" "$process_data"
    
    # Security monitoring for sensitive processes
    case "$process_name" in
        *ssh*|*sudo*|*su|*cron*|*systemd*)
            security_log "SENSITIVE_PROCESS_EVENT" "$event_type for sensitive process $process_name" "MEDIUM" "$process_data"
            ;;
    esac
}

# === ERROR AND EXCEPTION TRACKING ===

# Comprehensive error tracking with stack traces
log_comprehensive_error() {
    local error_type="$1"
    local error_message="$2"
    local error_code="${3:-1}"
    local function_stack="${4:-}"
    local additional_context="${5:-{}}"
    
    # Get detailed stack trace
    local stack_trace=""
    local frame=1
    while caller $frame >/dev/null 2>&1; do
        local line_info=$(caller $frame)
        stack_trace+="$line_info;"
        ((frame++))
    done
    
    local error_data=$(cat << EOF
{
    "error_type": "$error_type",
    "error_message": "$error_message",
    "error_code": $error_code,
    "stack_trace": "$stack_trace",
    "function_stack": "$function_stack",
    "process_id": "$$",
    "working_directory": "$(pwd)",
    "environment_summary": {
        "user": "$USER",
        "hostname": "$HOSTNAME",
        "shell": "$SHELL",
        "path": "$PATH"
    },
    "system_state": {
        "memory_usage": $(get_memory_usage),
        "cpu_usage": $(get_cpu_usage),
        "load_average": "$(get_load_average)",
        "disk_usage": $(get_disk_usage)
    },
    "additional_context": $additional_context
}
EOF
)
    
    log_error "Comprehensive error: $error_type - $error_message" "error_tracking" "$error_data"
    
    # Create detailed error report file
    local error_report_file="$LOG_ERROR_DIR/error_detail_$(date +%Y%m%d_%H%M%S)_$$.json"
    echo "$error_data" > "$error_report_file"
    
    log_info "Detailed error report created: $error_report_file" "error_tracking"
}

# === BUSINESS LOGIC LOGGING ===

# Log business rule validations and decisions
log_business_logic() {
    local rule_name="$1"
    local input_data="$2"
    local result="$3"
    local decision_factors="${4:-{}}"
    
    local business_data=$(cat << EOF
{
    "rule_name": "$rule_name",
    "input_data": "$input_data",
    "result": "$result",
    "decision_factors": $decision_factors,
    "execution_context": {
        "user": "$USER",
        "session_id": "$SESSION_ID",
        "correlation_id": "$CORRELATION_ID",
        "timestamp": "$(iso8601_timestamp)"
    }
}
EOF
)
    
    log_info "Business rule evaluation: $rule_name -> $result" "business_logic" "$business_data"
    audit_log "BUSINESS_RULE" "$rule_name" "$result" "$business_data"
}

# === INTEGRATION HOOKS ===

# Setup comprehensive logging integration
setup_comprehensive_logging() {
    log_info "Setting up comprehensive logging integration" "integration"
    
    # Auto-instrument functions
    auto_instrument_common_functions
    
    # Setup command interception  
    setup_command_interception
    
    # Setup error trap for comprehensive error logging
    setup_comprehensive_error_trap
    
    # Monitor key environment variables
    setup_environment_monitoring
    
    log_info "Comprehensive logging integration completed" "integration"
}

setup_comprehensive_error_trap() {
    trap 'log_comprehensive_error "SCRIPT_ERROR" "Script error at line $LINENO" "$?" "${FUNCNAME[*]}"' ERR
    trap 'log_info "Script exiting normally" "script_lifecycle"' EXIT
    trap 'log_warn "Script interrupted by user" "script_lifecycle"' INT
    trap 'log_warn "Script terminated" "script_lifecycle"' TERM
}

setup_environment_monitoring() {
    # Monitor changes to key environment variables
    local monitored_vars=("PATH" "HOME" "USER" "SHELL" "PWD")
    
    for var in "${monitored_vars[@]}"; do
        if [[ -n "${!var:-}" ]]; then
            # Store initial value
            declare -g "INITIAL_$var=${!var}"
        fi
    done
}

# === PERFORMANCE PROFILING ===

# Start performance profiling for a code block
start_performance_profile() {
    local profile_name="$1"
    local profile_start_time=$(get_high_precision_timestamp)
    
    declare -g "PROFILE_START_$profile_name=$profile_start_time"
    
    log_debug "Started performance profile: $profile_name" "performance_profiling" \
        "{\"profile_name\":\"$profile_name\",\"start_time\":$profile_start_time}"
}

# End performance profiling and log results
end_performance_profile() {
    local profile_name="$1"
    local profile_end_time=$(get_high_precision_timestamp)
    
    local start_var="PROFILE_START_$profile_name"
    local profile_start_time="${!start_var:-$profile_end_time}"
    local execution_time=$(echo "$profile_end_time - $profile_start_time" | bc -l 2>/dev/null || echo "0")
    
    local profile_data=$(cat << EOF
{
    "profile_name": "$profile_name",
    "start_time": $profile_start_time,
    "end_time": $profile_end_time,
    "execution_time_seconds": $execution_time,
    "memory_usage_mb": $(get_memory_usage),
    "cpu_usage_percent": $(get_cpu_usage)
}
EOF
)
    
    log_info "Performance profile completed: $profile_name (${execution_time}s)" "performance_profiling" "$profile_data"
    log_performance_metrics "$profile_name" "$execution_time" "0"
    
    unset "PROFILE_START_$profile_name"
}

# === INITIALIZATION ===

# Auto-setup when sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    log_info "Loading enterprise logging integration layer" "integration"
    setup_comprehensive_logging
    log_info "Enterprise logging integration layer loaded successfully" "integration"
fi