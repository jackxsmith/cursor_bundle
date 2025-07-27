#!/usr/bin/env bash
#
# Enterprise Logging Configuration System
# Centralized configuration management for all logging components
#

set -euo pipefail
IFS=$'\n\t'

# === GLOBAL CONFIGURATION ===
readonly LOGGING_CONFIG_VERSION="1.0.0"
readonly CONFIG_FILE="${CURSOR_LOGGING_CONFIG:-$HOME/.cursor_logging_config.json}"
readonly DEFAULT_CONFIG_FILE="$(dirname "${BASH_SOURCE[0]}")/../config/default_logging_config.json"

# Default configuration
declare -A LOGGING_CONFIG=(
    # Framework settings
    ["framework.version"]="2.0.0"
    ["framework.namespace"]="cursor_bundle"
    ["framework.session_timeout"]="3600"
    
    # Log levels
    ["logging.level.default"]="INFO"
    ["logging.level.security"]="WARN"
    ["logging.level.performance"]="INFO"
    ["logging.level.audit"]="INFO"
    ["logging.level.function_trace"]="DEBUG"
    ["logging.level.command_execution"]="INFO"
    
    # Feature toggles
    ["features.function_tracing"]="true"
    ["features.command_interception"]="true"
    ["features.performance_monitoring"]="true"
    ["features.security_logging"]="true"
    ["features.audit_logging"]="true"
    ["features.error_alerting"]="true"
    ["features.file_operation_logging"]="true"
    ["features.network_logging"]="true"
    ["features.environment_monitoring"]="true"
    ["features.business_logic_logging"]="true"
    ["features.compression"]="true"
    ["features.encryption"]="false"
    
    # Performance settings
    ["performance.max_log_size_mb"]="100"
    ["performance.log_rotation_interval"]="daily"
    ["performance.retention_days"]="90"
    ["performance.archive_retention_days"]="365"
    ["performance.buffer_size"]="1024"
    ["performance.flush_interval"]="30"
    
    # Security settings
    ["security.encrypt_sensitive_logs"]="true"
    ["security.mask_passwords"]="true"
    ["security.mask_tokens"]="true"
    ["security.secure_file_permissions"]="true"
    ["security.audit_config_changes"]="true"
    ["security.require_authentication"]="false"
    
    # Alert settings
    ["alerts.enabled"]="true"
    ["alerts.error_threshold"]="5"
    ["alerts.performance_threshold"]="10.0"
    ["alerts.disk_usage_threshold"]="90"
    ["alerts.memory_threshold"]="85"
    ["alerts.webhook_url"]=""
    ["alerts.email_recipients"]=""
    ["alerts.slack_channel"]=""
    
    # Output formats
    ["output.format"]="json"
    ["output.console_format"]="colored"
    ["output.timestamp_format"]="iso8601"
    ["output.include_caller_info"]="true"
    ["output.include_stack_trace"]="true"
    ["output.include_system_info"]="true"
    
    # Storage settings
    ["storage.base_directory"]="$HOME/.cache/cursor/enterprise-logs"
    ["storage.structured_logs"]="true" 
    ["storage.separate_log_types"]="true"
    ["storage.use_subdirectories"]="true"
    ["storage.compress_archives"]="true"
    
    # Integration settings
    ["integration.elasticsearch.enabled"]="false"
    ["integration.elasticsearch.url"]=""
    ["integration.splunk.enabled"]="false"
    ["integration.splunk.url"]=""
    ["integration.datadog.enabled"]="false"
    ["integration.datadog.api_key"]=""
    ["integration.prometheus.enabled"]="false"
    ["integration.prometheus.port"]="9090"
    
    # Development settings
    ["development.debug_mode"]="false"
    ["development.verbose_logging"]="false"
    ["development.log_internal_operations"]="false"
    ["development.performance_profiling"]="false"
    ["development.memory_tracking"]="false"
)

# === CONFIGURATION MANAGEMENT ===

# Load configuration from file
load_logging_config() {
    local config_file="${1:-$CONFIG_FILE}"
    
    if [[ -f "$config_file" ]]; then
        log_debug "Loading logging configuration from: $config_file" "config"
        
        # Parse JSON configuration
        if command -v jq >/dev/null 2>&1; then
            while IFS='=' read -r key value; do
                if [[ -n "$key" && -n "$value" ]]; then
                    LOGGING_CONFIG["$key"]="$value"
                fi
            done < <(jq -r 'to_entries[] | "\(.key)=\(.value)"' "$config_file" 2>/dev/null || true)
        else
            log_warn "jq not available, using default configuration" "config"
        fi
    else
        log_debug "Configuration file not found, using defaults: $config_file" "config"
        create_default_config_file "$config_file"
    fi
    
    # Apply configuration to environment
    apply_configuration
    
    log_info "Logging configuration loaded successfully" "config" \
        "{\"config_file\":\"$config_file\",\"total_settings\":${#LOGGING_CONFIG[@]}}"
}

# Save current configuration to file
save_logging_config() {
    local config_file="${1:-$CONFIG_FILE}"
    local config_dir=$(dirname "$config_file")
    
    mkdir -p "$config_dir" 2>/dev/null || {
        log_error "Cannot create config directory: $config_dir" "config"
        return 1
    }
    
    # Create JSON configuration
    local json_config="{"
    local first=true
    
    for key in "${!LOGGING_CONFIG[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            json_config+=","
        fi
        
        # Escape value for JSON
        local escaped_value=$(echo "${LOGGING_CONFIG[$key]}" | sed 's/\\/\\\\/g; s/"/\\"/g')
        json_config+="\"$key\":\"$escaped_value\""
    done
    
    json_config+="}"
    
    # Pretty print if jq is available
    if command -v jq >/dev/null 2>&1; then
        echo "$json_config" | jq '.' > "$config_file"
    else
        echo "$json_config" > "$config_file"
    fi
    
    log_info "Logging configuration saved: $config_file" "config"
    
    # Audit configuration change
    audit_log "CONFIG_SAVE" "$config_file" "SUCCESS" \
        "{\"config_entries\":${#LOGGING_CONFIG[@]},\"file_size\":$(wc -c < "$config_file" 2>/dev/null || echo 0)}"
}

# Create default configuration file
create_default_config_file() {
    local config_file="$1"
    
    log_info "Creating default configuration file: $config_file" "config"
    
    # Ensure directory exists
    mkdir -p "$(dirname "$config_file")" 2>/dev/null || true
    
    # Save current (default) configuration
    save_logging_config "$config_file"
}

# Apply configuration to environment
apply_configuration() {
    log_debug "Applying logging configuration to environment" "config"
    
    # Export key configuration as environment variables
    export ENTERPRISE_LOG_LEVEL="${LOGGING_CONFIG["logging.level.default"]}"
    export ENABLE_FUNCTION_TRACING="${LOGGING_CONFIG["features.function_tracing"]}"
    export ENABLE_PERFORMANCE_MONITORING="${LOGGING_CONFIG["features.performance_monitoring"]}"
    export ENABLE_SECURITY_LOGGING="${LOGGING_CONFIG["features.security_logging"]}"
    export ENABLE_AUDIT_LOGGING="${LOGGING_CONFIG["features.audit_logging"]}"
    export LOG_RETENTION_DAYS="${LOGGING_CONFIG["performance.retention_days"]}"
    export MAX_LOG_SIZE_MB="${LOGGING_CONFIG["performance.max_log_size_mb"]}"
    export ALERT_ON_ERRORS="${LOGGING_CONFIG["features.error_alerting"]}"
    export LOG_BASE_DIR="${LOGGING_CONFIG["storage.base_directory"]}"
    
    # Apply security settings
    if [[ "${LOGGING_CONFIG["security.secure_file_permissions"]}" == "true" ]]; then
        umask 0077  # Restrict file permissions
    fi
    
    log_debug "Configuration applied to environment" "config"
}

# Get configuration value
get_config() {
    local key="$1"
    local default_value="${2:-}"
    
    echo "${LOGGING_CONFIG[$key]:-$default_value}"
}

# Set configuration value
set_config() {
    local key="$1"
    local value="$2"
    local persist="${3:-false}"
    
    local old_value="${LOGGING_CONFIG[$key]:-}"
    LOGGING_CONFIG["$key"]="$value"
    
    log_debug "Configuration updated: $key = $value (was: $old_value)" "config"
    
    # Audit configuration change
    audit_log "CONFIG_CHANGE" "$key" "UPDATED" \
        "{\"old_value\":\"$old_value\",\"new_value\":\"$value\",\"persist\":\"$persist\"}"
    
    # Persist if requested
    if [[ "$persist" == "true" ]]; then
        save_logging_config
    fi
    
    # Re-apply configuration
    apply_configuration
}

# === FEATURE TOGGLES ===

# Check if feature is enabled
is_feature_enabled() {
    local feature="$1"
    local enabled=$(get_config "features.$feature" "false")
    [[ "$enabled" == "true" ]]
}

# Enable feature
enable_feature() {
    local feature="$1"
    local persist="${2:-false}"
    
    set_config "features.$feature" "true" "$persist"
    log_info "Feature enabled: $feature" "config"
}

# Disable feature
disable_feature() {
    local feature="$1" 
    local persist="${2:-false}"
    
    set_config "features.$feature" "false" "$persist"
    log_info "Feature disabled: $feature" "config"
}

# === LOG LEVEL MANAGEMENT ===

# Set log level for component
set_log_level() {
    local component="$1"
    local level="$2"
    local persist="${3:-false}"
    
    # Validate log level
    if [[ ! "${LOG_LEVELS[$level]:-}" ]]; then
        log_error "Invalid log level: $level" "config"
        return 1
    fi
    
    set_config "logging.level.$component" "$level" "$persist"
    log_info "Log level set for $component: $level" "config"
}

# Get log level for component
get_log_level() {
    local component="$1"
    get_config "logging.level.$component" "${LOGGING_CONFIG["logging.level.default"]}"
}

# === ALERT CONFIGURATION ===

# Configure alert thresholds
set_alert_threshold() {
    local metric="$1"
    local threshold="$2"
    local persist="${3:-false}"
    
    set_config "alerts.${metric}_threshold" "$threshold" "$persist"
    log_info "Alert threshold set for $metric: $threshold" "config"
}

# Configure alert destination
set_alert_destination() {
    local type="$1"      # webhook, email, slack
    local destination="$2"
    local persist="${3:-false}"
    
    case "$type" in
        webhook)
            set_config "alerts.webhook_url" "$destination" "$persist"
            ;;
        email)
            set_config "alerts.email_recipients" "$destination" "$persist"
            ;;
        slack)
            set_config "alerts.slack_channel" "$destination" "$persist"
            ;;
        *)
            log_error "Invalid alert destination type: $type" "config"
            return 1
            ;;
    esac
    
    log_info "Alert destination configured: $type -> $destination" "config"
}

# === INTEGRATION CONFIGURATION ===

# Configure external integration
configure_integration() {
    local service="$1"    # elasticsearch, splunk, datadog, prometheus
    local enabled="$2"    # true/false
    local config_data="$3" # JSON configuration
    local persist="${4:-false}"
    
    set_config "integration.$service.enabled" "$enabled" "$persist"
    
    # Parse and set service-specific configuration
    if command -v jq >/dev/null 2>&1 && [[ -n "$config_data" ]]; then
        while IFS='=' read -r key value; do
            if [[ -n "$key" && -n "$value" ]]; then
                set_config "integration.$service.$key" "$value" "$persist"
            fi
        done < <(echo "$config_data" | jq -r 'to_entries[] | "\(.key)=\(.value)"' 2>/dev/null || true)
    fi
    
    log_info "Integration configured: $service (enabled: $enabled)" "config"
}

# === VALIDATION ===

# Validate configuration
validate_configuration() {
    local validation_errors=0
    
    log_info "Validating logging configuration" "config"
    
    # Validate log levels
    for key in "${!LOGGING_CONFIG[@]}"; do
        if [[ "$key" =~ ^logging\.level\. ]]; then
            local level="${LOGGING_CONFIG[$key]}"
            if [[ ! "${LOG_LEVELS[$level]:-}" ]]; then
                log_error "Invalid log level in configuration: $key = $level" "config"
                ((validation_errors++))
            fi
        fi
    done
    
    # Validate boolean values
    local boolean_keys=(
        "features.function_tracing"
        "features.command_interception"
        "features.performance_monitoring"
        "features.security_logging"
        "features.audit_logging"
        "features.error_alerting"
        "security.encrypt_sensitive_logs"
        "security.mask_passwords"
        "security.mask_tokens"
        "security.secure_file_permissions"
        "alerts.enabled"
    )
    
    for key in "${boolean_keys[@]}"; do
        local value="${LOGGING_CONFIG[$key]:-}"
        if [[ "$value" != "true" && "$value" != "false" ]]; then
            log_error "Invalid boolean value in configuration: $key = $value" "config"
            ((validation_errors++))
        fi
    done
    
    # Validate numeric values
    local numeric_keys=(
        "performance.max_log_size_mb"
        "performance.retention_days"
        "performance.archive_retention_days"
        "performance.buffer_size"
        "performance.flush_interval"
        "alerts.error_threshold"
        "alerts.performance_threshold"
        "alerts.disk_usage_threshold"
        "alerts.memory_threshold"
    )
    
    for key in "${numeric_keys[@]}"; do
        local value="${LOGGING_CONFIG[$key]:-}"
        if ! [[ "$value" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            log_error "Invalid numeric value in configuration: $key = $value" "config"
            ((validation_errors++))
        fi
    done
    
    # Validate directories
    local base_dir="${LOGGING_CONFIG["storage.base_directory"]}"
    if [[ ! -d "$base_dir" ]]; then
        mkdir -p "$base_dir" 2>/dev/null || {
            log_error "Cannot create log base directory: $base_dir" "config"
            ((validation_errors++))
        }
    fi
    
    if [[ $validation_errors -eq 0 ]]; then
        log_info "Configuration validation passed" "config"
        return 0
    else
        log_error "Configuration validation failed with $validation_errors errors" "config"
        return 1
    fi
}

# === CONFIGURATION PROFILES ===

# Load predefined configuration profile
load_config_profile() {
    local profile="$1"
    
    case "$profile" in
        "development")
            load_development_profile
            ;;
        "production")
            load_production_profile
            ;;
        "debugging")
            load_debugging_profile
            ;;
        "minimal")
            load_minimal_profile
            ;;
        "security")
            load_security_profile
            ;;
        *)
            log_error "Unknown configuration profile: $profile" "config"
            return 1
            ;;
    esac
    
    log_info "Configuration profile loaded: $profile" "config"
}

load_development_profile() {
    set_config "logging.level.default" "DEBUG"
    set_config "features.function_tracing" "true"
    set_config "features.performance_monitoring" "true"
    set_config "development.debug_mode" "true"
    set_config "development.verbose_logging" "true"
    set_config "development.log_internal_operations" "true"
    set_config "output.include_caller_info" "true"
    set_config "output.include_stack_trace" "true"
}

load_production_profile() {
    set_config "logging.level.default" "INFO"
    set_config "features.function_tracing" "false"
    set_config "features.performance_monitoring" "true"
    set_config "features.security_logging" "true"
    set_config "features.audit_logging" "true"
    set_config "security.encrypt_sensitive_logs" "true"
    set_config "security.secure_file_permissions" "true"
    set_config "alerts.enabled" "true"
    set_config "performance.retention_days" "30"
}

load_debugging_profile() {
    set_config "logging.level.default" "TRACE"
    set_config "features.function_tracing" "true"
    set_config "features.command_interception" "true"
    set_config "development.debug_mode" "true"
    set_config "development.verbose_logging" "true"
    set_config "development.performance_profiling" "true"
    set_config "development.memory_tracking" "true"
    set_config "output.include_caller_info" "true"
    set_config "output.include_stack_trace" "true"
    set_config "output.include_system_info" "true"
}

load_minimal_profile() {
    set_config "logging.level.default" "ERROR"
    set_config "features.function_tracing" "false"
    set_config "features.command_interception" "false"
    set_config "features.performance_monitoring" "false"
    set_config "features.file_operation_logging" "false"
    set_config "features.network_logging" "false"
    set_config "features.environment_monitoring" "false"
    set_config "output.include_caller_info" "false"
    set_config "output.include_stack_trace" "false"
}

load_security_profile() {
    set_config "logging.level.default" "INFO"
    set_config "logging.level.security" "DEBUG"
    set_config "features.security_logging" "true"
    set_config "features.audit_logging" "true"
    set_config "security.encrypt_sensitive_logs" "true"
    set_config "security.mask_passwords" "true"
    set_config "security.mask_tokens" "true"
    set_config "security.secure_file_permissions" "true"
    set_config "security.audit_config_changes" "true"
    set_config "alerts.enabled" "true"
    set_config "alerts.error_threshold" "1"
}

# === REPORTING ===

# Generate configuration report
generate_config_report() {
    local report_file="$LOG_BASE_DIR/config_report_$(date +%Y%m%d_%H%M%S).json"
    
    local config_summary=$(cat << EOF
{
    "report_type": "configuration_summary",
    "generated_at": "$(iso8601_timestamp)",
    "configuration": {
$(for key in "${!LOGGING_CONFIG[@]}"; do
    echo "        \"$key\": \"${LOGGING_CONFIG[$key]}\","
done | sed '$s/,$//')
    },
    "validation_status": "$(validate_configuration >/dev/null 2>&1 && echo "VALID" || echo "INVALID")",
    "total_settings": ${#LOGGING_CONFIG[@]},
    "enabled_features": [
$(for key in "${!LOGGING_CONFIG[@]}"; do
    if [[ "$key" =~ ^features\. && "${LOGGING_CONFIG[$key]}" == "true" ]]; then
        echo "        \"${key#features.}\","
    fi
done | sed '$s/,$//')
    ]
}
EOF
)
    
    echo "$config_summary" > "$report_file"
    log_info "Configuration report generated: $report_file" "config"
    echo "$report_file"
}

# === INITIALIZATION ===

# Initialize configuration system
init_logging_config() {
    # Load configuration
    load_logging_config
    
    # Validate configuration
    if ! validate_configuration; then
        log_warn "Configuration validation failed, using safe defaults" "config"
        # Reset to safe defaults on validation failure
        declare -A LOGGING_CONFIG=(
            ["logging.level.default"]="INFO"
            ["features.function_tracing"]="false"
            ["features.security_logging"]="true"
            ["storage.base_directory"]="$HOME/.cache/cursor/enterprise-logs"
        )
        apply_configuration
    fi
    
    log_info "Logging configuration system initialized" "config" \
        "{\"config_entries\":${#LOGGING_CONFIG[@]},\"profile\":\"${LOGGING_PROFILE:-default}\"}"
}

# Auto-initialize when sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    init_logging_config
fi