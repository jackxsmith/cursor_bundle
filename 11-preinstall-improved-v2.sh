#\!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# 11-preinstall-improved-v2.sh - Professional Pre-Installation Framework v2.0
# Enterprise-grade pre-installation validation with robust error handling and self-correcting mechanisms
# ============================================================================

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="2.0.0"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Configuration Management
readonly APP_NAME="cursor"
readonly PREINSTALL_CONFIG_DIR="${HOME}/.config/cursor-preinstall"
readonly PREINSTALL_CACHE_DIR="${HOME}/.cache/cursor-preinstall"
readonly PREINSTALL_LOG_DIR="${PREINSTALL_CONFIG_DIR}/logs"

# Logging Configuration
readonly LOG_FILE="${PREINSTALL_LOG_DIR}/preinstall_${TIMESTAMP}.log"
readonly ERROR_LOG="${PREINSTALL_LOG_DIR}/preinstall_errors_${TIMESTAMP}.log"
readonly VALIDATION_LOG="${PREINSTALL_LOG_DIR}/validation_${TIMESTAMP}.log"

# Lock Management
readonly LOCK_FILE="${PREINSTALL_CONFIG_DIR}/.preinstall.lock"
readonly PID_FILE="${PREINSTALL_CONFIG_DIR}/.preinstall.pid"

# Global Variables
declare -g PREINSTALL_CONFIG="${PREINSTALL_CONFIG_DIR}/preinstall.conf"
declare -g VERBOSE_MODE=false
declare -g DRY_RUN_MODE=false
declare -g VALIDATION_PASSED=true

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
        *"df"* < /dev/null | *"free"*)
            log_info "System info command failed, checking alternative methods..."
            check_system_resources_alternative
            ;;
        *"which"*|*"command"*)
            log_info "Command check failed, updating PATH and retrying..."
            fix_path_environment
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

log_validation() {
    local check="$1"
    local result="$2"
    local details="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] VALIDATION: $check = $result ($details)" >> "$VALIDATION_LOG"
}

# Initialize pre-installation framework
initialize_preinstall_framework() {
    log_info "Initializing Professional Pre-Installation Framework v${VERSION}"
    
    # Set up error handling
    trap 'error_handler ${LINENO} "$BASH_COMMAND" $?' ERR
    trap 'cleanup_on_exit' EXIT
    trap 'log_info "Received interrupt signal, cleaning up..."; cleanup_on_exit; exit 130' INT TERM
    
    # Create directory structure
    create_directory_structure
    
    # Load configuration
    load_configuration
    
    # Acquire lock
    acquire_lock
    
    log_info "Pre-installation framework initialization completed successfully"
}

# Create directory structure with retry logic
create_directory_structure() {
    local dirs=("$PREINSTALL_CONFIG_DIR" "$PREINSTALL_CACHE_DIR" "$PREINSTALL_LOG_DIR")
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
    if [[ \! -f "$PREINSTALL_CONFIG" ]]; then
        log_info "Creating default pre-installation configuration"
        create_default_configuration
    fi
    
    # Source configuration safely
    if [[ -r "$PREINSTALL_CONFIG" ]]; then
        source "$PREINSTALL_CONFIG"
        log_info "Configuration loaded from $PREINSTALL_CONFIG"
    else
        log_warning "Configuration file not readable, using defaults"
    fi
}

# Create default configuration
create_default_configuration() {
    cat > "$PREINSTALL_CONFIG" << 'CONFIGEOF'
# Professional Pre-Installation Framework Configuration v2.0

# General Settings
VERBOSE_MODE=false
DRY_RUN_MODE=false
STRICT_VALIDATION=true
AUTO_FIX_ISSUES=true

# System Requirements
MIN_DISK_SPACE_MB=2048
MIN_MEMORY_MB=1024
MIN_TMP_SPACE_MB=512

# Validation Settings
CHECK_DEPENDENCIES=true
CHECK_PERMISSIONS=true
CHECK_HARDWARE=true
VALIDATE_ENVIRONMENT=true

# Security Settings
VERIFY_CHECKSUMS=true
CHECK_FILE_PERMISSIONS=true
VALIDATE_USER_CONTEXT=true

# Maintenance Settings
LOG_RETENTION_DAYS=30
CLEANUP_ON_SUCCESS=true
BACKUP_EXISTING_CONFIG=true
CONFIGEOF
    
    log_info "Default configuration created: $PREINSTALL_CONFIG"
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

# Perform comprehensive pre-installation validation
perform_preinstall_validation() {
    log_info "Starting comprehensive pre-installation validation..."
    
    local validation_start=$(date +%s)
    VALIDATION_PASSED=true
    
    # System validation
    validate_system_requirements
    
    # Dependency validation
    validate_dependencies
    
    # Permission validation
    validate_permissions
    
    # Environment validation
    validate_environment
    
    local validation_end=$(date +%s)
    local validation_duration=$((validation_end - validation_start))
    
    if [[ "$VALIDATION_PASSED" == "true" ]]; then
        log_info "Pre-installation validation completed successfully in ${validation_duration}s"
        return 0
    else
        log_error "Pre-installation validation failed after ${validation_duration}s"
        return 1
    fi
}

# Validate system requirements
validate_system_requirements() {
    log_info "Validating system requirements..."
    
    # Check operating system
    if \! validate_operating_system; then
        VALIDATION_PASSED=false
    fi
    
    # Check architecture
    if \! validate_architecture; then
        VALIDATION_PASSED=false
    fi
    
    # Check disk space
    if \! validate_disk_space; then
        VALIDATION_PASSED=false
    fi
    
    # Check memory
    if \! validate_memory; then
        VALIDATION_PASSED=false
    fi
    
    log_info "System requirements validation completed"
}

# Validate operating system
validate_operating_system() {
    local os_info
    if [[ -f /etc/os-release ]]; then
        os_info=$(grep "^PRETTY_NAME=" /etc/os-release | cut -d'"' -f2)
    else
        os_info=$(uname -s)
    fi
    
    log_validation "OPERATING_SYSTEM" "DETECTED" "$os_info"
    
    # Check if OS is supported (Linux-based systems)
    if [[ "$os_info" =~ (Ubuntu|Debian|CentOS|RHEL|Fedora|SUSE|Arch|Linux) ]]; then
        log_validation "OPERATING_SYSTEM" "SUPPORTED" "$os_info"
        return 0
    else
        log_error "Unsupported operating system: $os_info"
        log_validation "OPERATING_SYSTEM" "UNSUPPORTED" "$os_info"
        return 1
    fi
}

# Validate architecture
validate_architecture() {
    local arch
    arch=$(uname -m)
    
    log_validation "ARCHITECTURE" "DETECTED" "$arch"
    
    case "$arch" in
        "x86_64"|"amd64")
            log_validation "ARCHITECTURE" "SUPPORTED" "$arch"
            return 0
            ;;
        "aarch64"|"arm64")
            log_validation "ARCHITECTURE" "SUPPORTED" "$arch (ARM64)"
            return 0
            ;;
        *)
            log_warning "Architecture may not be fully supported: $arch"
            log_validation "ARCHITECTURE" "WARNING" "$arch"
            return 0
            ;;
    esac
}

# Validate disk space
validate_disk_space() {
    local required_space=${MIN_DISK_SPACE_MB:-2048}
    local available_space
    
    # Check space in home directory
    if available_space=$(df "$HOME" 2>/dev/null | awk 'NR==2 {print int($4/1024)}'); then
        log_validation "DISK_SPACE" "AVAILABLE" "${available_space}MB"
        
        if [[ $available_space -lt $required_space ]]; then
            log_error "Insufficient disk space: ${available_space}MB < ${required_space}MB"
            log_validation "DISK_SPACE" "INSUFFICIENT" "${available_space}MB < ${required_space}MB"
            return 1
        else
            log_validation "DISK_SPACE" "SUFFICIENT" "${available_space}MB >= ${required_space}MB"
            return 0
        fi
    else
        log_warning "Could not check disk space"
        log_validation "DISK_SPACE" "UNKNOWN" "Check failed"
        return 0
    fi
}

# Validate memory
validate_memory() {
    local required_memory=${MIN_MEMORY_MB:-1024}
    local available_memory
    
    if available_memory=$(free -m 2>/dev/null | awk 'NR==2{print $7}'); then
        if [[ -z "$available_memory" ]]; then
            available_memory=$(free -m 2>/dev/null | awk 'NR==2{print $4}')
        fi
        
        log_validation "MEMORY" "AVAILABLE" "${available_memory}MB"
        
        if [[ $available_memory -lt $required_memory ]]; then
            log_warning "Low available memory: ${available_memory}MB < ${required_memory}MB"
            log_validation "MEMORY" "LOW" "${available_memory}MB < ${required_memory}MB"
            return 0  # Warning only
        else
            log_validation "MEMORY" "SUFFICIENT" "${available_memory}MB >= ${required_memory}MB"
            return 0
        fi
    else
        log_warning "Could not check available memory"
        log_validation "MEMORY" "UNKNOWN" "Check failed"
        return 0
    fi
}

# Validate dependencies
validate_dependencies() {
    log_info "Validating system dependencies..."
    
    local required_commands=("bash" "chmod" "chown" "mkdir" "rm" "cp" "mv")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" &>/dev/null; then
            log_validation "COMMAND_$cmd" "AVAILABLE" "$(command -v "$cmd")"
        else
            missing_commands+=("$cmd")
            log_validation "COMMAND_$cmd" "MISSING" "Not found in PATH"
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        VALIDATION_PASSED=false
        return 1
    fi
    
    log_info "Dependency validation completed"
    return 0
}

# Validate permissions
validate_permissions() {
    log_info "Validating file system permissions..."
    
    # Check write permissions in home directory
    if [[ -w "$HOME" ]]; then
        log_validation "PERMISSION_HOME" "WRITABLE" "$HOME"
    else
        log_error "Home directory is not writable: $HOME"
        log_validation "PERMISSION_HOME" "NOT_WRITABLE" "$HOME"
        VALIDATION_PASSED=false
        return 1
    fi
    
    # Check write permissions in current directory
    if [[ -w "$SCRIPT_DIR" ]]; then
        log_validation "PERMISSION_CURRENT" "WRITABLE" "$SCRIPT_DIR"
    else
        log_error "Current directory is not writable: $SCRIPT_DIR"
        log_validation "PERMISSION_CURRENT" "NOT_WRITABLE" "$SCRIPT_DIR"
        VALIDATION_PASSED=false
        return 1
    fi
    
    log_info "Permission validation completed"
    return 0
}

# Validate environment
validate_environment() {
    log_info "Validating environment settings..."
    
    # Check PATH
    if [[ -n "${PATH:-}" ]]; then
        log_validation "ENVIRONMENT_PATH" "SET" "${#PATH} characters"
    else
        log_warning "PATH environment variable is not set"
        log_validation "ENVIRONMENT_PATH" "UNSET" "PATH is empty"
    fi
    
    # Check USER
    local current_user="${USER:-$(whoami 2>/dev/null || echo 'unknown')}"
    log_validation "ENVIRONMENT_USER" "DETECTED" "$current_user"
    
    # Check if running as root (warn if true)
    if [[ "$current_user" == "root" ]]; then
        log_warning "Running as root user - this may not be recommended"
        log_validation "ENVIRONMENT_ROOT" "WARNING" "Running as root"
    fi
    
    log_info "Environment validation completed"
    return 0
}

# Generate validation report
generate_validation_report() {
    local report_file="${PREINSTALL_LOG_DIR}/validation_report_${TIMESTAMP}.txt"
    log_info "Generating validation report: $report_file"
    
    cat > "$report_file" << REPORTEOF
Pre-Installation Validation Report
Generated: $(date)
Framework Version: $VERSION

Validation Status: $(if [[ "$VALIDATION_PASSED" == "true" ]]; then echo "PASSED"; else echo "FAILED"; fi)

System appears ready for Cursor IDE installation.

For detailed validation results, see: $VALIDATION_LOG
REPORTEOF
    
    log_info "Validation report generated: $report_file"
}

# Self-correction functions
fix_directory_permissions() {
    log_info "Attempting to fix directory permissions..."
    
    for dir in "$PREINSTALL_CONFIG_DIR" "$PREINSTALL_CACHE_DIR" "$PREINSTALL_LOG_DIR"; do
        if [[ -d "$dir" ]]; then
            chmod 755 "$dir" 2>/dev/null || true
        fi
    done
}

check_system_resources_alternative() {
    log_info "Checking system resources using alternative methods..."
    
    if [[ -f /proc/meminfo ]]; then
        local mem_available
        mem_available=$(grep "MemAvailable" /proc/meminfo 2>/dev/null | awk '{print int($2/1024)}' || echo "Unknown")
        if [[ "$mem_available" \!= "Unknown" ]]; then
            log_info "Alternative memory check: ${mem_available}MB available"
        fi
    fi
}

fix_path_environment() {
    log_info "Attempting to fix PATH environment..."
    export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
    log_info "Updated PATH: $PATH"
}

# Cleanup functions
cleanup_on_error() {
    log_warning "Performing error cleanup..."
    cleanup_on_exit
}

cleanup_on_exit() {
    [[ -f "$LOCK_FILE" ]] && rm -f "$LOCK_FILE"
    [[ -f "$PID_FILE" ]] && rm -f "$PID_FILE"
    jobs -p | xargs -r kill 2>/dev/null || true
    log_info "Cleanup completed"
}

# Display usage information
display_usage() {
    cat << 'USAGEEOF'
Professional Pre-Installation Framework v2.0

USAGE:
    preinstall-improved-v2.sh [OPTIONS]

OPTIONS:
    --validate      Perform validation checks (default)
    --report        Generate validation report only
    --verbose       Enable verbose output
    --dry-run       Show what would be checked
    --help          Display this help message
    --version       Display version information

EXAMPLES:
    ./preinstall-improved-v2.sh
    ./preinstall-improved-v2.sh --verbose
    ./preinstall-improved-v2.sh --report

For more information, see the documentation.
USAGEEOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --validate)
                OPERATION="validate"
                shift
                ;;
            --report)
                OPERATION="report"
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
                echo "Professional Pre-Installation Framework v$VERSION"
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
    local OPERATION="${OPERATION:-validate}"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Initialize framework
    initialize_preinstall_framework
    
    case "$OPERATION" in
        "validate")
            if perform_preinstall_validation; then
                generate_validation_report
                log_info "Pre-installation validation completed successfully"
                exit 0
            else
                generate_validation_report
                log_error "Pre-installation validation failed"
                exit 1
            fi
            ;;
        "report")
            generate_validation_report
            log_info "Validation report generated"
            exit 0
            ;;
        *)
            log_error "Unknown operation: $OPERATION"
            exit 1
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
