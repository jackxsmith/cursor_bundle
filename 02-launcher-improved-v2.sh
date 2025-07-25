#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# 02-launcher-improved-v2.sh - Professional Cursor IDE Launcher v2.0
# Enterprise-grade application launcher with robust error handling and self-correcting mechanisms
# ============================================================================

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="2.0.0"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Configuration Management
readonly APP_NAME="cursor"
readonly APP_BINARY="${SCRIPT_DIR}/cursor.AppImage"
readonly CONFIG_DIR="${HOME}/.config/cursor-launcher"
readonly CACHE_DIR="${HOME}/.cache/cursor-launcher"
readonly LOGS_DIR="${CONFIG_DIR}/logs"

# Logging Configuration
readonly LOG_FILE="${LOGS_DIR}/launcher_${TIMESTAMP}.log"
readonly ERROR_LOG="${LOGS_DIR}/launcher_errors_${TIMESTAMP}.log"
readonly PERFORMANCE_LOG="${LOGS_DIR}/launcher_performance_${TIMESTAMP}.log"

# Lock Management
readonly LOCK_FILE="${CONFIG_DIR}/.launcher.lock"
readonly PID_FILE="${CONFIG_DIR}/.launcher.pid"

# Global Variables
declare -g LAUNCHER_CONFIG="${CONFIG_DIR}/launcher.conf"
declare -g DEBUG_MODE=false
declare -g VERBOSE_MODE=false
declare -g PERFORMANCE_MONITORING=true

# Enhanced error handling with self-correction
error_handler() {
    local line_no="$1"
    local bash_command="$2"
    local exit_code="$3"
    
    log_error "Error on line $line_no: Command '$bash_command' failed with exit code $exit_code"
    
    # Self-correction attempts
    case "$bash_command" in
        *"cursor.AppImage"*)
            log_info "AppImage execution failed, checking permissions and integrity..."
            fix_appimage_issues
            ;;
        *"mkdir"*)
            log_info "Directory creation failed, attempting to fix permissions..."
            fix_directory_permissions
            ;;
        *"config"*)
            log_info "Configuration issue detected, attempting to recreate defaults..."
            create_default_configuration
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

log_debug() {
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    [[ "$DEBUG_MODE" == "true" ]] && echo "[$timestamp] [DEBUG] $message" | tee -a "$LOG_FILE"
}

log_performance() {
    local operation="$1"
    local duration="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] PERF: $operation took ${duration}ms" >> "$PERFORMANCE_LOG"
}

# Initialize launcher with robust setup
initialize_launcher() {
    log_info "Initializing Professional Cursor IDE Launcher v${VERSION}"
    
    # Set up error handling
    trap 'error_handler ${LINENO} "$BASH_COMMAND" $?' ERR
    trap 'cleanup_on_exit' EXIT
    trap 'log_info "Received interrupt signal, cleaning up..."; cleanup_on_exit; exit 130' INT TERM
    
    # Create directory structure
    create_directory_structure
    
    # Load configuration
    load_configuration
    
    # Validate system requirements
    validate_system_requirements
    
    # Acquire lock
    acquire_lock
    
    log_info "Launcher initialization completed successfully"
}

# Create directory structure with retry logic
create_directory_structure() {
    local dirs=("$CONFIG_DIR" "$CACHE_DIR" "$LOGS_DIR")
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
    if [[ ! -f "$LAUNCHER_CONFIG" ]]; then
        log_info "Creating default launcher configuration"
        create_default_configuration
    fi
    
    # Source configuration safely
    if [[ -r "$LAUNCHER_CONFIG" ]]; then
        source "$LAUNCHER_CONFIG"
        log_info "Configuration loaded from $LAUNCHER_CONFIG"
    else
        log_warning "Configuration file not readable, using defaults"
    fi
}

# Create default configuration
create_default_configuration() {
    cat > "$LAUNCHER_CONFIG" << 'EOF'
# Professional Cursor IDE Launcher Configuration v2.0

# General Settings
DEBUG_MODE=false
VERBOSE_MODE=false
PERFORMANCE_MONITORING=true
AUTO_UPDATE_CHECK=true

# Launch Options
ENABLE_HARDWARE_ACCELERATION=true
ENABLE_GPU_RENDERING=true
MEMORY_LIMIT=2048
STARTUP_TIMEOUT=30

# Security Settings
ENABLE_SANDBOX=true
VALIDATE_SIGNATURES=true
RESTRICT_NETWORK_ACCESS=false

# Performance Settings
ENABLE_PRELOADING=true
CACHE_CLEANUP_INTERVAL=7
LOG_RETENTION_DAYS=30
EOF
    
    log_info "Default configuration created: $LAUNCHER_CONFIG"
}

# Validate system requirements with auto-correction
validate_system_requirements() {
    log_info "Validating system requirements..."
    
    # Check if AppImage exists
    if [[ ! -f "$APP_BINARY" ]]; then
        log_error "Cursor AppImage not found: $APP_BINARY"
        # Try to find AppImage in current directory
        local found_appimage
        found_appimage=$(find "$SCRIPT_DIR" -name "*.AppImage" -type f | head -1)
        if [[ -n "$found_appimage" ]]; then
            log_info "Found alternative AppImage: $found_appimage"
            APP_BINARY="$found_appimage"
        else
            return 1
        fi
    fi
    
    # Check AppImage permissions
    if [[ ! -x "$APP_BINARY" ]]; then
        log_warning "AppImage is not executable, fixing permissions..."
        chmod +x "$APP_BINARY" || return 1
    fi
    
    # Check disk space (minimum 100MB)
    local available_space
    available_space=$(df "$HOME" | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 102400 ]]; then
        log_warning "Low disk space: $(($available_space / 1024))MB available"
        cleanup_cache
    fi
    
    # Check required commands
    local required_commands=("ps" "kill" "find")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            log_warning "Required command not found: $cmd"
        fi
    done
    
    log_info "System requirements validation completed"
}

# Acquire lock with timeout
acquire_lock() {
    local timeout=10
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        if (set -C; echo $$ > "$LOCK_FILE") 2>/dev/null; then
            echo $$ > "$PID_FILE"
            log_debug "Lock acquired successfully"
            return 0
        fi
        
        if [[ -f "$LOCK_FILE" ]]; then
            local lock_pid
            lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
            if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
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

# Launch Cursor IDE with comprehensive error handling
launch_cursor() {
    local start_time=$(date +%s%N)
    log_info "Launching Cursor IDE..."
    
    # Pre-launch checks
    if ! perform_prelaunch_checks; then
        log_error "Pre-launch checks failed"
        return 1
    fi
    
    # Prepare launch environment
    prepare_launch_environment
    
    # Build launch command
    local launch_cmd=("$APP_BINARY")
    
    # Add launch arguments
    add_launch_arguments launch_cmd "$@"
    
    # Performance monitoring
    if [[ "$PERFORMANCE_MONITORING" == "true" ]]; then
        log_debug "Starting performance monitoring"
        monitor_performance &
        local monitor_pid=$!
    fi
    
    # Launch the application
    log_info "Executing: ${launch_cmd[*]}"
    
    if "${launch_cmd[@]}"; then
        local end_time=$(date +%s%N)
        local duration=$(( (end_time - start_time) / 1000000 ))
        log_performance "cursor_launch" "$duration"
        log_info "Cursor IDE launched successfully"
        
        # Kill performance monitor if running
        [[ -n "${monitor_pid:-}" ]] && kill "$monitor_pid" 2>/dev/null || true
        
        return 0
    else
        local exit_code=$?
        log_error "Failed to launch Cursor IDE (exit code: $exit_code)"
        
        # Kill performance monitor if running
        [[ -n "${monitor_pid:-}" ]] && kill "$monitor_pid" 2>/dev/null || true
        
        # Attempt recovery
        attempt_launch_recovery
        return $exit_code
    fi
}

# Perform pre-launch checks
perform_prelaunch_checks() {
    log_debug "Performing pre-launch checks..."
    
    # Check if another instance is running
    if is_cursor_running; then
        log_warning "Cursor IDE is already running, bringing to foreground..."
        bring_cursor_to_foreground
        return 1
    fi
    
    # Validate AppImage integrity
    if ! validate_appimage_integrity; then
        log_error "AppImage integrity validation failed"
        return 1
    fi
    
    # Check system resources
    if ! check_system_resources; then
        log_warning "System resources may be insufficient"
    fi
    
    log_debug "Pre-launch checks completed successfully"
    return 0
}

# Check if Cursor IDE is already running
is_cursor_running() {
    if pgrep -f "cursor" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# Bring existing Cursor window to foreground
bring_cursor_to_foreground() {
    if command -v wmctrl &>/dev/null; then
        wmctrl -a "Cursor" 2>/dev/null || true
    elif command -v xdotool &>/dev/null; then
        xdotool search --name "Cursor" windowactivate 2>/dev/null || true
    fi
}

# Validate AppImage integrity
validate_appimage_integrity() {
    log_debug "Validating AppImage integrity..."
    
    # Check file signature
    if ! file "$APP_BINARY" | grep -q "ELF"; then
        log_error "AppImage is not a valid ELF executable"
        return 1
    fi
    
    # Test extraction capability
    if ! timeout 10 "$APP_BINARY" --appimage-help >/dev/null 2>&1; then
        log_warning "AppImage may have issues (help command failed)"
    fi
    
    return 0
}

# Check system resources
check_system_resources() {
    local memory_available
    memory_available=$(free -m | awk 'NR==2{print $7}')
    
    if [[ $memory_available -lt 512 ]]; then
        log_warning "Low available memory: ${memory_available}MB"
        return 1
    fi
    
    return 0
}

# Prepare launch environment
prepare_launch_environment() {
    log_debug "Preparing launch environment..."
    
    # Set environment variables
    export APPIMAGE_EXTRACT_AND_RUN=1
    export CURSOR_CONFIG_DIR="$CONFIG_DIR"
    export CURSOR_CACHE_DIR="$CACHE_DIR"
    
    # Create necessary runtime directories
    mkdir -p "$HOME/.cursor" 2>/dev/null || true
    
    log_debug "Launch environment prepared"
}

# Add launch arguments
add_launch_arguments() {
    local -n cmd_ref=$1
    shift
    
    # Add user-provided arguments
    cmd_ref+=("$@")
    
    # Add performance arguments if enabled
    if [[ "${ENABLE_HARDWARE_ACCELERATION:-true}" == "true" ]]; then
        cmd_ref+=("--enable-hardware-acceleration")
    fi
    
    if [[ "${ENABLE_GPU_RENDERING:-true}" == "true" ]]; then
        cmd_ref+=("--enable-gpu-rasterization")
    fi
    
    # Add memory limit if specified
    if [[ -n "${MEMORY_LIMIT:-}" ]] && [[ "$MEMORY_LIMIT" -gt 0 ]]; then
        cmd_ref+=("--max-old-space-size=$MEMORY_LIMIT")
    fi
    
    log_debug "Launch arguments added: ${cmd_ref[*]}"
}

# Monitor performance during launch
monitor_performance() {
    local interval=1
    local max_iterations=30
    local iteration=0
    
    while [[ $iteration -lt $max_iterations ]]; do
        if pgrep -f "cursor" >/dev/null 2>&1; then
            local pid
            pid=$(pgrep -f "cursor" | head -1)
            local cpu_usage memory_usage
            cpu_usage=$(ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ')
            memory_usage=$(ps -p "$pid" -o %mem= 2>/dev/null | tr -d ' ')
            
            if [[ -n "$cpu_usage" ]] && [[ -n "$memory_usage" ]]; then
                log_performance "resource_usage" "CPU:${cpu_usage}% MEM:${memory_usage}%"
            fi
        fi
        
        sleep $interval
        ((iteration++))
    done
}

# Attempt launch recovery
attempt_launch_recovery() {
    log_info "Attempting launch recovery..."
    
    # Clear cache
    cleanup_cache
    
    # Reset configuration if corrupted
    if [[ -f "$LAUNCHER_CONFIG" ]]; then
        local backup_config="${LAUNCHER_CONFIG}.backup"
        cp "$LAUNCHER_CONFIG" "$backup_config"
        create_default_configuration
        log_info "Configuration reset, backup saved to: $backup_config"
    fi
    
    # Try launching with minimal arguments
    log_info "Attempting minimal launch..."
    if timeout 30 "$APP_BINARY" --version >/dev/null 2>&1; then
        log_info "Minimal launch successful, trying full launch again..."
        return 0
    else
        log_error "Recovery attempt failed"
        return 1
    fi
}

# Self-correction functions
fix_appimage_issues() {
    log_info "Attempting to fix AppImage issues..."
    
    # Fix permissions
    chmod +x "$APP_BINARY" 2>/dev/null || true
    
    # Clear FUSE cache if it exists
    if [[ -d "/tmp/.appimage-" ]]; then
        rm -rf /tmp/.appimage-* 2>/dev/null || true
    fi
}

fix_directory_permissions() {
    log_info "Attempting to fix directory permissions..."
    
    # Fix ownership and permissions
    for dir in "$CONFIG_DIR" "$CACHE_DIR" "$LOGS_DIR"; do
        if [[ -d "$dir" ]]; then
            chmod 755 "$dir" 2>/dev/null || true
            find "$dir" -type f -exec chmod 644 {} \; 2>/dev/null || true
        fi
    done
}

# Cleanup functions
cleanup_cache() {
    log_info "Cleaning up cache..."
    
    if [[ -d "$CACHE_DIR" ]]; then
        find "$CACHE_DIR" -type f -mtime +7 -delete 2>/dev/null || true
        find "$CACHE_DIR" -type d -empty -delete 2>/dev/null || true
    fi
    
    # Clean temporary files
    find /tmp -name "*cursor*" -user "$(whoami)" -mtime +1 -delete 2>/dev/null || true
}

cleanup_logs() {
    log_info "Cleaning up old logs..."
    
    local retention_days="${LOG_RETENTION_DAYS:-30}"
    if [[ -d "$LOGS_DIR" ]]; then
        find "$LOGS_DIR" -name "*.log" -mtime +$retention_days -delete 2>/dev/null || true
    fi
}

cleanup_on_error() {
    log_warning "Performing error cleanup..."
    cleanup_on_exit
}

cleanup_on_exit() {
    # Remove lock files
    [[ -f "$LOCK_FILE" ]] && rm -f "$LOCK_FILE"
    [[ -f "$PID_FILE" ]] && rm -f "$PID_FILE"
    
    # Kill any background processes
    jobs -p | xargs -r kill 2>/dev/null || true
    
    log_debug "Cleanup completed"
}

# Display usage information
display_usage() {
    cat << 'EOF'
Professional Cursor IDE Launcher v2.0

USAGE:
    launcher-improved-v2.sh [OPTIONS] [CURSOR_ARGS...]

OPTIONS:
    --debug         Enable debug mode
    --verbose       Enable verbose output
    --no-perf       Disable performance monitoring
    --cleanup       Clean cache and logs, then exit
    --status        Show launcher status
    --help          Display this help message
    --version       Display version information

CURSOR_ARGS:
    Any additional arguments will be passed directly to Cursor IDE

EXAMPLES:
    ./launcher-improved-v2.sh
    ./launcher-improved-v2.sh --verbose /path/to/project
    ./launcher-improved-v2.sh --debug --new-window

CONFIGURATION:
    Configuration file: ~/.config/cursor-launcher/launcher.conf
    Log directory: ~/.config/cursor-launcher/logs/
    Cache directory: ~/.cache/cursor-launcher/

For more information, see the documentation.
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --debug)
                DEBUG_MODE=true
                shift
                ;;
            --verbose)
                VERBOSE_MODE=true
                shift
                ;;
            --no-perf)
                PERFORMANCE_MONITORING=false
                shift
                ;;
            --cleanup)
                cleanup_cache
                cleanup_logs
                log_info "Cleanup completed"
                exit 0
                ;;
            --status)
                show_launcher_status
                exit 0
                ;;
            --help)
                display_usage
                exit 0
                ;;
            --version)
                echo "Professional Cursor IDE Launcher v$VERSION"
                exit 0
                ;;
            -*)
                log_warning "Unknown option: $1"
                shift
                ;;
            *)
                # Pass remaining arguments to Cursor
                break
                ;;
        esac
    done
}

# Show launcher status
show_launcher_status() {
    echo "Professional Cursor IDE Launcher v$VERSION"
    echo "Configuration: $LAUNCHER_CONFIG"
    echo "Logs: $LOGS_DIR"
    echo "Cache: $CACHE_DIR"
    echo "AppImage: $APP_BINARY"
    
    if [[ -f "$APP_BINARY" ]]; then
        echo "AppImage Status: Found"
        echo "AppImage Size: $(du -h "$APP_BINARY" | cut -f1)"
    else
        echo "AppImage Status: Not Found"
    fi
    
    if is_cursor_running; then
        echo "Cursor Status: Running"
    else
        echo "Cursor Status: Not Running"
    fi
}

# Main execution function
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Initialize launcher
    initialize_launcher
    
    # Launch Cursor IDE
    if launch_cursor "$@"; then
        log_info "Professional Cursor IDE Launcher completed successfully"
        exit 0
    else
        log_error "Professional Cursor IDE Launcher failed"
        exit 1
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi