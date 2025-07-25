#\!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# 16-tracker-improved-v2.sh - Professional Usage Tracking Framework v2.0
# Enterprise-grade usage analytics with robust error handling and self-correcting mechanisms
# ============================================================================

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="2.0.0"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Configuration Management
readonly APP_NAME="cursor"
readonly TRACKER_CONFIG_DIR="${HOME}/.config/cursor-tracker"
readonly TRACKER_CACHE_DIR="${HOME}/.cache/cursor-tracker"
readonly TRACKER_LOG_DIR="${TRACKER_CONFIG_DIR}/logs"

# Logging Configuration
readonly LOG_FILE="${TRACKER_LOG_DIR}/tracker_${TIMESTAMP}.log"
readonly ERROR_LOG="${TRACKER_LOG_DIR}/tracker_errors_${TIMESTAMP}.log"
readonly USAGE_LOG="${TRACKER_LOG_DIR}/usage_${TIMESTAMP}.log"

# Lock Management
readonly LOCK_FILE="${TRACKER_CONFIG_DIR}/.tracker.lock"
readonly PID_FILE="${TRACKER_CONFIG_DIR}/.tracker.pid"

# Global Variables
declare -g TRACKER_CONFIG="${TRACKER_CONFIG_DIR}/tracker.conf"
declare -g VERBOSE_MODE=false
declare -g DRY_RUN_MODE=false
declare -g TRACKING_ENABLED=true

# Enhanced error handling with self-correction
error_handler() {
    local line_no="$1"
    local bash_command="$2"
    local exit_code="$3"
    
    log_error "Error on line $line_no: Command '$bash_command' failed with exit code $exit_code"
    
    # Self-correction attempts
    case "$bash_command" in
        *"mkdir"*)
            log_info "Directory creation failed, attempting to fix permissions..."
            fix_directory_permissions
            ;;
        *"sqlite3"*)
            log_info "Database operation failed, checking database integrity..."
            check_database_integrity
            ;;
        *"ps"* < /dev/null | *"pgrep"*)
            log_info "Process monitoring failed, using alternative methods..."
            use_alternative_process_monitoring
            ;;
    esac
    
    cleanup_on_error
}

# Professional logging system
log_info() {
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [INFO] $message" | tee -a "$LOG_FILE"
    [[ "$VERBOSE_MODE" == "true" ]] && echo "[INFO] $message" >&2
}

log_error() {
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [ERROR] $message" | tee -a "$LOG_FILE" >&2
    echo "[$timestamp] [ERROR] $message" >> "$ERROR_LOG"
}

log_warning() {
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [WARNING] $message" | tee -a "$LOG_FILE"
    [[ "$VERBOSE_MODE" == "true" ]] && echo "[WARNING] $message" >&2
}

log_usage() {
    local event="$1"
    local data="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] USAGE: $event = $data" >> "$USAGE_LOG"
}

# Initialize tracking framework
initialize_tracking_framework() {
    log_info "Initializing Professional Usage Tracking Framework v${VERSION}"
    
    # Set up error handling
    trap 'error_handler ${LINENO} "$BASH_COMMAND" $?' ERR
    trap 'cleanup_on_exit' EXIT
    trap 'log_info "Received interrupt signal, cleaning up..."; cleanup_on_exit; exit 130' INT TERM
    
    # Create directory structure
    create_directory_structure
    
    # Load configuration
    load_configuration
    
    # Initialize database
    initialize_database
    
    # Acquire lock
    acquire_lock
    
    log_info "Tracking framework initialization completed successfully"
}

# Create directory structure with retry logic
create_directory_structure() {
    local dirs=("$TRACKER_CONFIG_DIR" "$TRACKER_CACHE_DIR" "$TRACKER_LOG_DIR")
    local max_retries=3
    
    for dir in "${dirs[@]}"; do
        local retry_count=0
        while [[ $retry_count -lt $max_retries ]]; do
            if mkdir -p "$dir" 2>/dev/null; then
                break
            else
                ((retry_count++))
                log_warning "Failed to create directory $dir (attempt $retry_count/$max_retries)"
                sleep 1
            fi
        done
        
        if [[ $retry_count -eq $max_retries ]]; then
            log_error "Failed to create directory $dir after $max_retries attempts"
            return 1
        fi
    done
}

# Load configuration with defaults
load_configuration() {
    if [[ \! -f "$TRACKER_CONFIG" ]]; then
        log_info "Creating default tracking configuration"
        create_default_configuration
    fi
    
    # Source configuration safely
    if [[ -r "$TRACKER_CONFIG" ]]; then
        source "$TRACKER_CONFIG"
        log_info "Configuration loaded from $TRACKER_CONFIG"
    else
        log_warning "Configuration file not readable, using defaults"
    fi
}

# Create default configuration
create_default_configuration() {
    cat > "$TRACKER_CONFIG" << 'CONFIGEOF'
# Professional Usage Tracking Framework Configuration v2.0

# General Settings
VERBOSE_MODE=false
DRY_RUN_MODE=false
TRACKING_ENABLED=true
PRIVACY_MODE=false

# Data Collection Settings
TRACK_LAUNCH_EVENTS=true
TRACK_USAGE_TIME=true
TRACK_FEATURE_USAGE=false
TRACK_PERFORMANCE_METRICS=true

# Privacy Settings
ANONYMIZE_DATA=true
COLLECT_PERSONAL_INFO=false
SEND_ANALYTICS=false
RETAIN_LOCAL_DATA=true

# Storage Settings
DATABASE_PATH=${TRACKER_CACHE_DIR}/usage.db
MAX_DATABASE_SIZE_MB=100
DATA_RETENTION_DAYS=90

# Export Settings
ENABLE_EXPORT=true
EXPORT_FORMAT=json
EXPORT_PATH=${HOME}/cursor-usage-export

# Monitoring Settings
MONITORING_INTERVAL=60
BACKGROUND_MONITORING=true
RESOURCE_MONITORING=true
CONFIGEOF
    
    log_info "Default configuration created: $TRACKER_CONFIG"
}

# Initialize database
initialize_database() {
    log_info "Initializing usage tracking database..."
    
    local db_path="${DATABASE_PATH:-$TRACKER_CACHE_DIR/usage.db}"
    
    # Check if sqlite3 is available
    if \! command -v sqlite3 &>/dev/null; then
        log_warning "SQLite3 not available, using file-based tracking"
        return 0
    fi
    
    # Create database schema
    sqlite3 "$db_path" << 'SQLEOF'
CREATE TABLE IF NOT EXISTS usage_events (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    timestamp TEXT NOT NULL,
    event_type TEXT NOT NULL,
    event_data TEXT,
    session_id TEXT,
    user_hash TEXT
);

CREATE TABLE IF NOT EXISTS session_data (
    session_id TEXT PRIMARY KEY,
    start_time TEXT NOT NULL,
    end_time TEXT,
    duration INTEGER,
    features_used TEXT,
    performance_data TEXT
);

CREATE INDEX IF NOT EXISTS idx_timestamp ON usage_events(timestamp);
CREATE INDEX IF NOT EXISTS idx_event_type ON usage_events(event_type);
CREATE INDEX IF NOT EXISTS idx_session_id ON usage_events(session_id);
SQLEOF
    
    log_info "Database initialized: $db_path"
}

# Acquire lock with timeout
acquire_lock() {
    local timeout=10
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        if (set -C; echo $$ > "$LOCK_FILE") 2>/dev/null; then
            echo $$ > "$PID_FILE"
            log_info "Lock acquired successfully"
            return 0
        fi
        
        if [[ -f "$LOCK_FILE" ]]; then
            local lock_pid
            lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
            if [[ -n "$lock_pid" ]] && \! kill -0 "$lock_pid" 2>/dev/null; then
                log_info "Removing stale lock file"
                rm -f "$LOCK_FILE"
                continue
            fi
        fi
        
        sleep 1
        ((elapsed++))
    done
    
    log_warning "Could not acquire lock, continuing anyway"
    return 0
}

# Start usage tracking
start_tracking() {
    if [[ "${TRACKING_ENABLED:-true}" \!= "true" ]]; then
        log_info "Usage tracking is disabled"
        return 0
    fi
    
    log_info "Starting usage tracking..."
    
    local session_id="session_${TIMESTAMP}_$$"
    track_event "SESSION_START" "$session_id"
    
    # Start background monitoring if enabled
    if [[ "${BACKGROUND_MONITORING:-true}" == "true" ]]; then
        start_background_monitoring "$session_id"
    fi
    
    log_info "Usage tracking started with session ID: $session_id"
    echo "$session_id"
}

# Track usage event
track_event() {
    local event_type="$1"
    local event_data="${2:-}"
    local session_id="${3:-$(get_current_session_id)}"
    
    if [[ "${TRACKING_ENABLED:-true}" \!= "true" ]]; then
        return 0
    fi
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local user_hash=""
    
    # Generate anonymous user hash if privacy mode is disabled
    if [[ "${ANONYMIZE_DATA:-true}" == "true" ]]; then
        user_hash=$(echo "${USER:-$(whoami)}_${HOSTNAME:-$(hostname)}" | sha256sum | cut -d' ' -f1 | head -c16)
    fi
    
    log_usage "$event_type" "$event_data"
    
    # Store in database if available
    local db_path="${DATABASE_PATH:-$TRACKER_CACHE_DIR/usage.db}"
    if command -v sqlite3 &>/dev/null && [[ -f "$db_path" ]]; then
        sqlite3 "$db_path" << SQLEOF
INSERT INTO usage_events (timestamp, event_type, event_data, session_id, user_hash)
VALUES ('$timestamp', '$event_type', '$event_data', '$session_id', '$user_hash');
SQLEOF
    fi
}

# Start background monitoring
start_background_monitoring() {
    local session_id="$1"
    
    log_info "Starting background monitoring for session: $session_id"
    
    # Monitor in background
    {
        while [[ -f "$LOCK_FILE" ]]; do
            # Monitor resource usage
            if [[ "${RESOURCE_MONITORING:-true}" == "true" ]]; then
                monitor_resource_usage "$session_id"
            fi
            
            # Monitor application status
            monitor_application_status "$session_id"
            
            sleep "${MONITORING_INTERVAL:-60}"
        done
    } &
    
    local monitor_pid=$\!
    echo "$monitor_pid" > "${TRACKER_CONFIG_DIR}/.monitor.pid"
    log_info "Background monitoring started with PID: $monitor_pid"
}

# Monitor resource usage
monitor_resource_usage() {
    local session_id="$1"
    
    # Get memory usage
    local memory_usage
    if memory_usage=$(ps -p $$ -o rss= 2>/dev/null); then
        track_event "MEMORY_USAGE" "${memory_usage}KB" "$session_id"
    fi
    
    # Get CPU usage
    local cpu_usage
    if cpu_usage=$(ps -p $$ -o %cpu= 2>/dev/null); then
        track_event "CPU_USAGE" "${cpu_usage}%" "$session_id"
    fi
}

# Monitor application status
monitor_application_status() {
    local session_id="$1"
    
    # Check if Cursor is running
    if pgrep -f "cursor" >/dev/null 2>&1; then
        track_event "APPLICATION_ACTIVE" "running" "$session_id"
    else
        track_event "APPLICATION_INACTIVE" "not_running" "$session_id"
    fi
}

# Stop tracking
stop_tracking() {
    log_info "Stopping usage tracking..."
    
    local session_id=$(get_current_session_id)
    track_event "SESSION_END" "$session_id"
    
    # Stop background monitoring
    if [[ -f "${TRACKER_CONFIG_DIR}/.monitor.pid" ]]; then
        local monitor_pid
        monitor_pid=$(cat "${TRACKER_CONFIG_DIR}/.monitor.pid" 2>/dev/null || echo "")
        if [[ -n "$monitor_pid" ]] && kill -0 "$monitor_pid" 2>/dev/null; then
            kill "$monitor_pid" 2>/dev/null || true
            log_info "Background monitoring stopped"
        fi
        rm -f "${TRACKER_CONFIG_DIR}/.monitor.pid"
    fi
    
    # Update session data
    update_session_data "$session_id"
    
    log_info "Usage tracking stopped"
}

# Get current session ID
get_current_session_id() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
        echo "session_${TIMESTAMP}_${pid}"
    else
        echo "session_unknown"
    fi
}

# Update session data
update_session_data() {
    local session_id="$1"
    local db_path="${DATABASE_PATH:-$TRACKER_CACHE_DIR/usage.db}"
    
    if command -v sqlite3 &>/dev/null && [[ -f "$db_path" ]]; then
        local end_time=$(date '+%Y-%m-%d %H:%M:%S')
        
        sqlite3 "$db_path" << SQLEOF
UPDATE session_data SET end_time = '$end_time' WHERE session_id = '$session_id';
SQLEOF
    fi
}

# Export usage data
export_usage_data() {
    log_info "Exporting usage data..."
    
    local export_path="${EXPORT_PATH:-$HOME/cursor-usage-export}"
    local export_format="${EXPORT_FORMAT:-json}"
    local export_file="$export_path/usage_export_${TIMESTAMP}.$export_format"
    
    mkdir -p "$export_path"
    
    local db_path="${DATABASE_PATH:-$TRACKER_CACHE_DIR/usage.db}"
    
    if command -v sqlite3 &>/dev/null && [[ -f "$db_path" ]]; then
        case "$export_format" in
            "json")
                export_to_json "$db_path" "$export_file"
                ;;
            "csv")
                export_to_csv "$db_path" "$export_file"
                ;;
            *)
                log_warning "Unknown export format: $export_format, using JSON"
                export_to_json "$db_path" "${export_file%.*}.json"
                ;;
        esac
    else
        log_warning "Database not available, exporting log files"
        cp "$USAGE_LOG" "$export_file.log" 2>/dev/null || true
    fi
    
    log_info "Usage data exported to: $export_file"
}

# Export to JSON format
export_to_json() {
    local db_path="$1"
    local export_file="$2"
    
    cat > "$export_file" << 'JSONEOF'
{
  "export_info": {
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "version": "$(echo $VERSION)",
    "format": "json"
  },
  "usage_events": [
JSONEOF
    
    # Export events (simplified JSON structure)
    sqlite3 "$db_path" -separator ',' << 'SQLEOF' | while IFS=',' read -r id timestamp event_type event_data session_id user_hash; do
SELECT id, timestamp, event_type, event_data, session_id, user_hash FROM usage_events ORDER BY timestamp;
SQLEOF
        if [[ -n "$id" ]]; then
            cat >> "$export_file" << JSONEOF
    {
      "id": $id,
      "timestamp": "$timestamp",
      "event_type": "$event_type",
      "event_data": "$event_data",
      "session_id": "$session_id",
      "user_hash": "$user_hash"
    },
JSONEOF
        fi
    done
    
    # Remove trailing comma and close JSON
    sed -i '$ s/,$//' "$export_file" 2>/dev/null || true
    echo "  ]" >> "$export_file"
    echo "}" >> "$export_file"
}

# Export to CSV format
export_to_csv() {
    local db_path="$1"
    local export_file="$2"
    
    echo "id,timestamp,event_type,event_data,session_id,user_hash" > "$export_file"
    sqlite3 "$db_path" -separator ',' << 'SQLEOF' >> "$export_file"
SELECT id, timestamp, event_type, event_data, session_id, user_hash FROM usage_events ORDER BY timestamp;
SQLEOF
}

# Self-correction functions
fix_directory_permissions() {
    log_info "Attempting to fix directory permissions..."
    
    for dir in "$TRACKER_CONFIG_DIR" "$TRACKER_CACHE_DIR" "$TRACKER_LOG_DIR"; do
        if [[ -d "$dir" ]]; then
            chmod 755 "$dir" 2>/dev/null || true
        fi
    done
}

check_database_integrity() {
    log_info "Checking database integrity..."
    
    local db_path="${DATABASE_PATH:-$TRACKER_CACHE_DIR/usage.db}"
    
    if command -v sqlite3 &>/dev/null && [[ -f "$db_path" ]]; then
        if sqlite3 "$db_path" "PRAGMA integrity_check;" >/dev/null 2>&1; then
            log_info "Database integrity check passed"
        else
            log_warning "Database integrity issues detected, attempting repair..."
            # Backup and recreate database
            cp "$db_path" "${db_path}.backup" 2>/dev/null || true
            rm -f "$db_path"
            initialize_database
        fi
    fi
}

use_alternative_process_monitoring() {
    log_info "Using alternative process monitoring methods..."
    
    # Use /proc if available
    if [[ -d /proc/$$ ]]; then
        log_info "Using /proc filesystem for process monitoring"
        return 0
    fi
    
    # Fallback to basic monitoring
    log_warning "Limited process monitoring capabilities"
    return 1
}

# Cleanup functions
cleanup_on_error() {
    log_warning "Performing error cleanup..."
    cleanup_on_exit
}

cleanup_on_exit() {
    # Stop tracking if active
    if [[ -f "$LOCK_FILE" ]]; then
        stop_tracking
    fi
    
    [[ -f "$LOCK_FILE" ]] && rm -f "$LOCK_FILE"
    [[ -f "$PID_FILE" ]] && rm -f "$PID_FILE"
    [[ -f "${TRACKER_CONFIG_DIR}/.monitor.pid" ]] && rm -f "${TRACKER_CONFIG_DIR}/.monitor.pid"
    jobs -p | xargs -r kill 2>/dev/null || true
    log_info "Cleanup completed"
}

# Display usage information
display_usage() {
    cat << 'USAGEEOF'
Professional Usage Tracking Framework v2.0

USAGE:
    tracker-improved-v2.sh [OPTIONS] [COMMAND]

COMMANDS:
    start       Start usage tracking (default)
    stop        Stop usage tracking
    export      Export usage data
    status      Show tracking status

OPTIONS:
    --verbose       Enable verbose output
    --dry-run       Show what would be tracked
    --help          Display this help message
    --version       Display version information

EXAMPLES:
    ./tracker-improved-v2.sh start
    ./tracker-improved-v2.sh export
    ./tracker-improved-v2.sh status

For more information, see the documentation.
USAGEEOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            start)
                OPERATION="start"
                shift
                ;;
            stop)
                OPERATION="stop"
                shift
                ;;
            export)
                OPERATION="export"
                shift
                ;;
            status)
                OPERATION="status"
                shift
                ;;
            --verbose)
                VERBOSE_MODE=true
                shift
                ;;
            --dry-run)
                DRY_RUN_MODE=true
                shift
                ;;
            --help)
                display_usage
                exit 0
                ;;
            --version)
                echo "Professional Usage Tracking Framework v$VERSION"
                exit 0
                ;;
            -*)
                log_warning "Unknown option: $1"
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
}

# Main execution function
main() {
    local OPERATION="${OPERATION:-start}"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Initialize framework
    initialize_tracking_framework
    
    case "$OPERATION" in
        "start")
            session_id=$(start_tracking)
            log_info "Usage tracking started successfully"
            echo "Session ID: $session_id"
            exit 0
            ;;
        "stop")
            stop_tracking
            log_info "Usage tracking stopped successfully"
            exit 0
            ;;
        "export")
            export_usage_data
            log_info "Usage data exported successfully"
            exit 0
            ;;
        "status")
            if [[ -f "$LOCK_FILE" ]]; then
                echo "Tracking Status: ACTIVE"
                echo "Session ID: $(get_current_session_id)"
            else
                echo "Tracking Status: INACTIVE"
            fi
            exit 0
            ;;
        *)
            log_error "Unknown operation: $OPERATION"
            display_usage
            exit 1
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
