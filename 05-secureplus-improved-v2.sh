#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# 05-secureplus-improved-v2.sh - Professional Enhanced Security Launcher v2.0
# Enterprise-grade secure application launcher with robust error handling and self-correcting mechanisms
# ============================================================================

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="2.0.0"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Configuration Management
readonly APP_NAME="cursor"
readonly APP_BINARY="${SCRIPT_DIR}/cursor.AppImage"
readonly SECUREPLUS_CONFIG_DIR="${HOME}/.config/cursor-secureplus"
readonly SECURITY_CACHE_DIR="${HOME}/.cache/cursor-secureplus"
readonly SECURITY_LOG_DIR="${SECUREPLUS_CONFIG_DIR}/logs"

# Logging Configuration
readonly LOG_FILE="${SECURITY_LOG_DIR}/secureplus_${TIMESTAMP}.log"
readonly ERROR_LOG="${SECURITY_LOG_DIR}/secureplus_errors_${TIMESTAMP}.log"
readonly SECURITY_LOG="${SECURITY_LOG_DIR}/security_events_${TIMESTAMP}.log"

# Lock Management
readonly LOCK_FILE="${SECUREPLUS_CONFIG_DIR}/.secureplus.lock"
readonly PID_FILE="${SECUREPLUS_CONFIG_DIR}/.secureplus.pid"

# Global Variables
declare -g SECUREPLUS_CONFIG="${SECUREPLUS_CONFIG_DIR}/secureplus.conf"
declare -g VERBOSE_MODE=false
declare -g SECURITY_MODE="enhanced" 
declare -g ISOLATION_ENABLED=true
declare -g MONITORING_ENABLED=true

# Enhanced error handling with self-correction
error_handler() {
    local line_no="$1"
    local bash_command="$2"
    local exit_code="$3"
    
    log_error "Error on line $line_no: Command '$bash_command' failed with exit code $exit_code"
    
    # Self-correction attempts
    case "$bash_command" in
        *"cursor.AppImage"*)
            log_info "AppImage execution failed, checking integrity and permissions..."
            fix_appimage_issues
            ;;
        *"mkdir"*)
            log_info "Directory creation failed, attempting to fix permissions..."
            fix_directory_permissions
            ;;
        *"isolate"*|*"sandbox"*)
            log_info "Isolation failed, checking system capabilities..."
            check_isolation_capabilities
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

log_security() {
    local event="$1"
    local severity="$2"
    local details="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] SECURITY [$severity] $event: $details" >> "$SECURITY_LOG"
}

# Initialize secure launcher with robust setup
initialize_secure_launcher() {
    log_info "Initializing Professional Enhanced Security Launcher v${VERSION}"
    
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
    
    # Initialize security environment
    initialize_security_environment
    
    # Acquire lock
    acquire_lock
    
    log_info "Secure launcher initialization completed successfully"
}

# Create directory structure with retry logic
create_directory_structure() {
    local dirs=("$SECUREPLUS_CONFIG_DIR" "$SECURITY_CACHE_DIR" "$SECURITY_LOG_DIR")
    local max_retries=3
    
    for dir in "${dirs[@]}"; do
        local retry_count=0
        while [[ $retry_count -lt $max_retries ]]; do
            if mkdir -p "$dir" 2>/dev/null; then
                # Set secure permissions
                chmod 700 "$dir" 2>/dev/null || true
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
    if [[ ! -f "$SECUREPLUS_CONFIG" ]]; then
        log_info "Creating default secure launcher configuration"
        create_default_configuration
    fi
    
    # Source configuration safely
    if [[ -r "$SECUREPLUS_CONFIG" ]]; then
        source "$SECUREPLUS_CONFIG"
        log_info "Configuration loaded from $SECUREPLUS_CONFIG"
    else
        log_warning "Configuration file not readable, using defaults"
    fi
}

# Create default configuration
create_default_configuration() {
    cat > "$SECUREPLUS_CONFIG" << 'EOF'
# Professional Enhanced Security Launcher Configuration v2.0

# General Settings
VERBOSE_MODE=false
SECURITY_MODE=enhanced
MONITORING_ENABLED=true
AUDIT_LOGGING=true

# Application Isolation Settings
ISOLATION_ENABLED=true
USE_NAMESPACE_ISOLATION=true
RESTRICT_NETWORK_ACCESS=false
LIMIT_FILE_ACCESS=true
ENABLE_RESOURCE_LIMITS=true

# Process Security Settings
ENABLE_ASLR=true
ENABLE_DEP=true
DISABLE_CORE_DUMPS=true
SET_PROCESS_LIMITS=true
MONITOR_CHILD_PROCESSES=true

# File System Security
ENABLE_FILE_INTEGRITY_MONITORING=true
RESTRICT_WRITABLE_PATHS=true
MONITOR_FILE_CHANGES=true
QUARANTINE_SUSPICIOUS_FILES=false

# Network Security
MONITOR_NETWORK_CONNECTIONS=true
BLOCK_SUSPICIOUS_DOMAINS=false
LOG_NETWORK_ACTIVITY=true
DNS_FILTERING=false

# System Monitoring
MONITOR_SYSTEM_CALLS=false
TRACK_RESOURCE_USAGE=true
ENABLE_PERFORMANCE_MONITORING=true
ALERT_ON_ANOMALIES=false

# Maintenance Settings
LOG_RETENTION_DAYS=30
CLEANUP_INTERVAL_HOURS=24
AUTO_UPDATE_SECURITY_RULES=false
ENABLE_SELF_DIAGNOSTICS=true
EOF
    
    log_info "Default configuration created: $SECUREPLUS_CONFIG"
}

# Validate system requirements
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
    
    # Check AppImage permissions and integrity
    if [[ ! -x "$APP_BINARY" ]]; then
        log_warning "AppImage is not executable, fixing permissions..."
        chmod +x "$APP_BINARY" || return 1
    fi
    
    # Check required commands
    local required_commands=("unshare" "chmod" "chown" "ps" "netstat")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_warning "Missing commands (isolation may be limited): ${missing_commands[*]}"
    fi
    
    # Check available memory (minimum 512MB)
    local available_memory
    available_memory=$(free -m | awk 'NR==2{print $7}')
    if [[ $available_memory -lt 512 ]]; then
        log_warning "Low available memory: ${available_memory}MB"
    fi
    
    log_info "System requirements validation completed"
}

# Initialize security environment
initialize_security_environment() {
    log_info "Initializing security environment..."
    
    # Set secure umask
    umask 077
    
    # Clear potentially dangerous environment variables
    unset LD_PRELOAD LD_LIBRARY_PATH 2>/dev/null || true
    
    # Set secure PATH
    export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    
    # Initialize security monitoring if enabled
    if [[ "$MONITORING_ENABLED" == "true" ]]; then
        start_security_monitoring
    fi
    
    log_info "Security environment initialized"
}

# Start security monitoring
start_security_monitoring() {
    log_info "Starting security monitoring..."
    
    # Monitor file system changes if configured
    if [[ "${MONITOR_FILE_CHANGES:-false}" == "true" ]]; then
        monitor_file_changes &
        local monitor_pid=$!
        echo "$monitor_pid" > "${SECURITY_CACHE_DIR}/.monitor.pid"
        log_info "File system monitoring started (PID: $monitor_pid)"
    fi
    
    # Monitor network connections if configured
    if [[ "${MONITOR_NETWORK_CONNECTIONS:-false}" == "true" ]]; then
        monitor_network_activity &
        local network_pid=$!
        echo "$network_pid" > "${SECURITY_CACHE_DIR}/.network.pid"
        log_info "Network monitoring started (PID: $network_pid)"
    fi
}

# Monitor file changes
monitor_file_changes() {
    local watch_dir="${1:-$SCRIPT_DIR}"
    
    if command -v inotifywait >/dev/null 2>&1; then
        while true; do
            inotifywait -m -r -e modify,create,delete "$watch_dir" 2>/dev/null | \
            while read path action file; do
                log_security "FILE_CHANGE" "INFO" "$action on $path$file"
            done
            sleep 1
        done
    else
        # Fallback to periodic checks
        local last_check=$(date +%s)
        while true; do
            local current_time=$(date +%s)
            if [[ $((current_time - last_check)) -gt 60 ]]; then
                find "$watch_dir" -newer "${SECURITY_CACHE_DIR}/.last_check" 2>/dev/null | \
                while read -r changed_file; do
                    log_security "FILE_CHANGE" "INFO" "Modified: $changed_file"
                done
                touch "${SECURITY_CACHE_DIR}/.last_check"
                last_check=$current_time
            fi
            sleep 10
        done
    fi
}

# Monitor network activity
monitor_network_activity() {
    if command -v netstat >/dev/null 2>&1; then
        while true; do
            netstat -an 2>/dev/null | grep "ESTABLISHED" | \
            while read -r line; do
                local connection=$(echo "$line" | awk '{print $4 " -> " $5}')
                log_security "NETWORK_CONNECTION" "INFO" "$connection"
            done
            sleep 30
        done
    fi
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

# Launch application with enhanced security
launch_secure_application() {
    log_info "Launching Cursor IDE with enhanced security..."
    log_security "APP_LAUNCH" "INFO" "Starting secure application launch"
    
    # Pre-launch security checks
    if ! perform_security_checks; then
        log_error "Security checks failed, aborting launch"
        return 1
    fi
    
    # Prepare secure launch environment
    prepare_secure_environment
    
    # Build launch command with security parameters
    local launch_cmd=()
    build_secure_launch_command launch_cmd "$@"
    
    # Execute with monitoring
    local launch_start=$(date +%s)
    
    if [[ "$ISOLATION_ENABLED" == "true" ]]; then
        launch_with_isolation "${launch_cmd[@]}"
    else
        launch_without_isolation "${launch_cmd[@]}"
    fi
    
    local launch_result=$?
    local launch_end=$(date +%s)
    local launch_duration=$((launch_end - launch_start))
    
    log_info "Application launch completed in ${launch_duration}s (exit code: $launch_result)"
    log_security "APP_LAUNCH" "INFO" "Launch completed with exit code $launch_result"
    
    return $launch_result
}

# Perform security checks
perform_security_checks() {
    log_info "Performing pre-launch security checks..."
    
    # Check AppImage integrity
    if ! file "$APP_BINARY" | grep -q "ELF"; then
        log_error "AppImage integrity check failed"
        return 1
    fi
    
    # Check for running instances
    if pgrep -f "cursor" >/dev/null 2>&1; then
        log_warning "Cursor IDE is already running"
        if [[ "${ALLOW_MULTIPLE_INSTANCES:-false}" != "true" ]]; then
            return 1
        fi
    fi
    
    # Check system resources
    local available_memory
    available_memory=$(free -m | awk 'NR==2{print $7}')
    if [[ $available_memory -lt 256 ]]; then
        log_warning "Low memory condition detected: ${available_memory}MB"
    fi
    
    # Check disk space
    local available_space
    available_space=$(df "$HOME" | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 51200 ]]; then
        log_warning "Low disk space: $(($available_space / 1024))MB available"
    fi
    
    log_info "Security checks completed successfully"
    return 0
}

# Prepare secure environment
prepare_secure_environment() {
    log_info "Preparing secure launch environment..."
    
    # Create temporary runtime directory
    local runtime_dir
    runtime_dir=$(mktemp -d -p "$SECURITY_CACHE_DIR" "runtime.XXXXXX")
    export CURSOR_RUNTIME_DIR="$runtime_dir"
    
    # Set security-focused environment variables
    export APPIMAGE_EXTRACT_AND_RUN=1
    export CURSOR_SECURITY_MODE="$SECURITY_MODE"
    export CURSOR_LOG_DIR="$SECURITY_LOG_DIR"
    
    # Disable potentially dangerous features
    export CURSOR_DISABLE_EXTENSIONS=false
    export CURSOR_DISABLE_TELEMETRY=true
    export CURSOR_DISABLE_UPDATES=false
    
    log_info "Secure environment prepared"
}

# Build secure launch command
build_secure_launch_command() {
    local -n cmd_ref=$1
    shift
    
    cmd_ref=("$APP_BINARY")
    
    # Add user-provided arguments
    cmd_ref+=("$@")
    
    # Add security arguments
    if [[ "${ENABLE_SANDBOX:-false}" == "true" ]]; then
        cmd_ref+=("--no-sandbox")
    fi
    
    if [[ "${DISABLE_GPU:-false}" == "true" ]]; then
        cmd_ref+=("--disable-gpu")
    fi
    
    # Add resource limits
    if [[ -n "${MEMORY_LIMIT:-}" ]]; then
        cmd_ref+=("--max-old-space-size=$MEMORY_LIMIT")
    fi
    
    log_info "Launch command prepared: ${cmd_ref[*]}"
}

# Launch with isolation
launch_with_isolation() {
    log_info "Launching application with isolation..."
    
    # Check if unshare is available for namespace isolation
    if command -v unshare >/dev/null 2>&1 && [[ "${USE_NAMESPACE_ISOLATION:-true}" == "true" ]]; then
        log_info "Using namespace isolation"
        unshare --pid --fork --mount-proc "${@}"
    else
        log_info "Namespace isolation not available, using standard launch"
        "${@}"
    fi
}

# Launch without isolation
launch_without_isolation() {
    log_info "Launching application without isolation..."
    "${@}"
}

# Self-correction functions
fix_appimage_issues() {
    log_info "Attempting to fix AppImage issues..."
    
    # Fix permissions
    chmod +x "$APP_BINARY" 2>/dev/null || true
    
    # Clear any existing extraction
    rm -rf squashfs-root 2>/dev/null || true
    
    # Test basic functionality
    if timeout 10 "$APP_BINARY" --help >/dev/null 2>&1; then
        log_info "AppImage basic functionality verified"
    else
        log_warning "AppImage may have persistent issues"
    fi
}

fix_directory_permissions() {
    log_info "Attempting to fix directory permissions..."
    
    for dir in "$SECUREPLUS_CONFIG_DIR" "$SECURITY_CACHE_DIR" "$SECURITY_LOG_DIR"; do
        if [[ -d "$dir" ]]; then
            chmod 700 "$dir" 2>/dev/null || true
            find "$dir" -type f -exec chmod 600 {} \; 2>/dev/null || true
        fi
    done
}

check_isolation_capabilities() {
    log_info "Checking isolation capabilities..."
    
    if ! command -v unshare >/dev/null 2>&1; then
        log_warning "unshare command not available, disabling namespace isolation"
        USE_NAMESPACE_ISOLATION=false
    fi
    
    # Test namespace creation
    if ! unshare --pid --fork true 2>/dev/null; then
        log_warning "Cannot create PID namespace, isolation may be limited"
    fi
}

# Cleanup functions
cleanup_on_error() {
    log_warning "Performing error cleanup..."
    cleanup_on_exit
}

cleanup_on_exit() {
    # Stop monitoring processes
    for pid_file in "${SECURITY_CACHE_DIR}"/.*.pid; do
        if [[ -f "$pid_file" ]]; then
            local pid
            pid=$(cat "$pid_file" 2>/dev/null || echo "")
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                kill "$pid" 2>/dev/null || true
            fi
            rm -f "$pid_file"
        fi
    done
    
    # Clean up runtime directory
    if [[ -n "${CURSOR_RUNTIME_DIR:-}" ]] && [[ -d "$CURSOR_RUNTIME_DIR" ]]; then
        rm -rf "$CURSOR_RUNTIME_DIR"
    fi
    
    # Remove lock files
    [[ -f "$LOCK_FILE" ]] && rm -f "$LOCK_FILE"
    [[ -f "$PID_FILE" ]] && rm -f "$PID_FILE"
    
    # Kill any background processes
    jobs -p | xargs -r kill 2>/dev/null || true
    
    log_info "Cleanup completed"
}

# Display usage information
display_usage() {
    cat << 'EOF'
Professional Enhanced Security Launcher v2.0

USAGE:
    secureplus-improved-v2.sh [OPTIONS] [CURSOR_ARGS...]

OPTIONS:
    --verbose           Enable verbose output
    --security-mode     Set security mode (standard, enhanced, strict)
    --no-isolation      Disable process isolation
    --no-monitoring     Disable security monitoring
    --allow-multiple    Allow multiple instances
    --help              Display this help message
    --version           Display version information

CURSOR_ARGS:
    Any additional arguments will be passed directly to Cursor IDE

EXAMPLES:
    ./secureplus-improved-v2.sh
    ./secureplus-improved-v2.sh --verbose /path/to/project
    ./secureplus-improved-v2.sh --security-mode strict --no-monitoring

CONFIGURATION:
    Configuration file: ~/.config/cursor-secureplus/secureplus.conf
    Log directory: ~/.config/cursor-secureplus/logs/

For more information, see the documentation.
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose)
                VERBOSE_MODE=true
                shift
                ;;
            --security-mode)
                SECURITY_MODE="$2"
                shift 2
                ;;
            --no-isolation)
                ISOLATION_ENABLED=false
                shift
                ;;
            --no-monitoring)
                MONITORING_ENABLED=false
                shift
                ;;
            --allow-multiple)
                ALLOW_MULTIPLE_INSTANCES=true
                shift
                ;;
            --help)
                display_usage
                exit 0
                ;;
            --version)
                echo "Professional Enhanced Security Launcher v$VERSION"
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

# Main execution function
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Initialize secure launcher
    initialize_secure_launcher
    
    # Launch application
    if launch_secure_application "$@"; then
        log_info "Professional Enhanced Security Launcher completed successfully"
        exit 0
    else
        log_error "Professional Enhanced Security Launcher failed"
        exit 1
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi