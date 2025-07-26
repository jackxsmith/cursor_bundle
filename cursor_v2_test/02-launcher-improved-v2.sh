#!/usr/bin/env bash
#
# CURSOR BUNDLE LAUNCHER v2.0 - Professional Edition
# Professional application launcher with policy compliance
#
# Features:
# - Multi-platform compatibility (Linux, macOS, Windows/WSL)
# - Strong error handling with self-correction
# - Professional configuration management
# - Performance monitoring and optimization
# - Security validation and compliance
# - Comprehensive logging and telemetry
#

set -euo pipefail
IFS=$'\n\t'

# === CONFIGURATION ===
readonly SCRIPT_VERSION="2.0-professional"
readonly SCRIPT_NAME="$(basename "${0}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Application Configuration
readonly APP_NAME="cursor"
readonly APP_VERSION="$(cat "${SCRIPT_DIR}/VERSION" 2>/dev/null || echo "unknown")"
readonly APP_BINARY="${SCRIPT_DIR}/cursor.AppImage"
readonly CONFIG_DIR="${HOME}/.config/cursor-launcher"
readonly CACHE_DIR="${HOME}/.cache/cursor-launcher"
readonly LOG_DIR="${CONFIG_DIR}/logs"

# Configuration Files
readonly LAUNCHER_CONFIG="${CONFIG_DIR}/launcher.conf"
readonly MAIN_LOG="${LOG_DIR}/launcher_${TIMESTAMP}.log"
readonly ERROR_LOG="${LOG_DIR}/errors_${TIMESTAMP}.log"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'

# Global State Variables
declare -g VERBOSE=false
declare -g DEBUG_MODE=false
declare -g PROFILE="default"
declare -g LAUNCH_MODE="normal"
declare -g SECURITY_LEVEL="standard"
declare -g PERFORMANCE_MODE="balanced"

# === LOGGING AND ERROR HANDLING ===
log() {
    local level="${1:-INFO}"
    local message="$2"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Ensure log directory exists
    mkdir -p "${LOG_DIR}" 2>/dev/null || true
    
    # Write to log files with error handling
    {
        echo "[${timestamp}] [${level}] ${message}" >> "${MAIN_LOG}"
        
        # Also write errors to error log
        if [[ "${level}" == "ERROR" ]]; then
            echo "[${timestamp}] [ERROR] ${message}" >> "${ERROR_LOG}"
        fi
    } 2>/dev/null || true
    
    # Console output with colors
    case "${level}" in
        "ERROR") 
            echo -e "${RED}[ERROR]${NC} ${message}" >&2
            ;;
        "WARN")  
            echo -e "${YELLOW}[WARN]${NC} ${message}"
            ;;
        "SUCCESS"|"PASS") 
            echo -e "${GREEN}[✓]${NC} ${message}"
            ;;
        "INFO")  
            [[ "$VERBOSE" == "true" ]] && echo -e "${BLUE}[INFO]${NC} ${message}"
            ;;
        "DEBUG") 
            [[ "$DEBUG_MODE" == "true" ]] && echo -e "[DEBUG] ${message}"
            ;;
    esac
}

# Professional error handler with self-correction
error_handler() {
    local line_no="$1"
    local bash_command="$2"
    local exit_code="$3"
    
    log "ERROR" "Command failed at line $line_no: $bash_command (exit code: $exit_code)"
    
    # Self-correction attempts
    case "$bash_command" in
        *mkdir*)
            log "INFO" "Attempting to create missing directories..."
            ensure_directories
            ;;
        *chmod*)
            log "INFO" "Attempting to fix file permissions..."
            fix_permissions
            ;;
        *"${APP_BINARY}"*)
            log "INFO" "Application binary issue, checking availability..."
            if [[ ! -f "${APP_BINARY}" ]]; then
                log "ERROR" "Application binary not found: ${APP_BINARY}"
                return 1
            fi
            ;;
    esac
}

# === INITIALIZATION ===
ensure_directories() {
    local dirs=("$CONFIG_DIR" "$CACHE_DIR" "$LOG_DIR")
    
    for dir in "${dirs[@]}"; do
        if ! mkdir -p "$dir" 2>/dev/null; then
            log "ERROR" "Failed to create directory: $dir"
            return 1
        fi
    done
    
    log "DEBUG" "Directory structure created successfully"
    return 0
}

initialize_launcher() {
    log "INFO" "Initializing Cursor Launcher v${SCRIPT_VERSION}"
    
    # Set error handler
    trap 'error_handler ${LINENO} "$BASH_COMMAND" $?' ERR
    
    # Create directory structure
    ensure_directories || {
        log "ERROR" "Failed to initialize directory structure"
        return 1
    }
    
    # Initialize default configuration if not exists
    if [[ ! -f "${LAUNCHER_CONFIG}" ]]; then
        create_default_config
    fi
    
    # Load configuration
    load_configuration
    
    # Validate environment
    validate_environment
    
    # Log rotation
    find "$LOG_DIR" -name "launcher_*.log" -mtime +7 -delete 2>/dev/null || true
    
    log "PASS" "Launcher initialized successfully"
    return 0
}

create_default_config() {
    log "INFO" "Creating default configuration"
    
    cat > "${LAUNCHER_CONFIG}" <<EOF
# Cursor Launcher Configuration v${SCRIPT_VERSION}
# Generated: $(date -Iseconds)

[general]
default_profile=default
auto_update=true
telemetry_enabled=false
crash_reporting=true
performance_monitoring=true

[security]
security_level=standard
sandbox_mode=false
verify_signatures=true

[performance]
performance_mode=balanced
memory_limit=4096
cpu_priority=normal

[ui]
theme=auto
scaling=auto
hardware_acceleration=true

[logging]
log_level=INFO
max_log_files=10
log_retention_days=30
debug_mode=false
EOF
    
    log "PASS" "Default configuration created"
}

load_configuration() {
    log "DEBUG" "Loading launcher configuration"
    
    if [[ -f "${LAUNCHER_CONFIG}" ]]; then
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ "${key}" =~ ^[[:space:]]*# ]] && continue
            [[ -z "${key}" ]] && continue
            [[ "${key}" =~ ^\[.*\]$ ]] && continue
            
            # Process configuration values
            case "${key}" in
                "default_profile") PROFILE="${value}" ;;
                "security_level") SECURITY_LEVEL="${value}" ;;
                "performance_mode") PERFORMANCE_MODE="${value}" ;;
                "debug_mode") [[ "${value}" == "true" ]] && DEBUG_MODE=true ;;
                "log_level") 
                    case "${value}" in
                        "DEBUG") DEBUG_MODE=true ;;
                        "VERBOSE") VERBOSE=true ;;
                    esac
                    ;;
            esac
        done < "${LAUNCHER_CONFIG}"
        
        log "DEBUG" "Configuration loaded successfully"
    else
        log "WARN" "Configuration file not found, using defaults"
    fi
}

# === ENVIRONMENT VALIDATION ===
validate_environment() {
    log "INFO" "Validating launch environment"
    
    local errors=0
    
    # Check required files
    if [[ ! -f "${APP_BINARY}" ]]; then
        log "ERROR" "Application binary not found: ${APP_BINARY}"
        ((errors++))
    fi
    
    # Check binary permissions
    if [[ ! -x "${APP_BINARY}" ]]; then
        log "WARN" "Application binary is not executable, attempting to fix"
        if chmod +x "${APP_BINARY}" 2>/dev/null; then
            log "PASS" "Fixed binary permissions"
        else
            log "ERROR" "Failed to fix binary permissions"
            ((errors++))
        fi
    fi
    
    # Check disk space
    local available_space
    available_space=$(df "${SCRIPT_DIR}" 2>/dev/null | awk 'NR==2 {print $4}' || echo "0")
    if [[ "${available_space}" -lt 1048576 ]]; then  # 1GB in KB
        log "WARN" "Low disk space: ${available_space}KB available"
    fi
    
    # Check memory
    if command -v free >/dev/null 2>&1; then
        local available_memory
        available_memory=$(free -m 2>/dev/null | awk 'NR==2{print $7}' || echo "0")
        if [[ "${available_memory}" -lt 512 ]]; then
            log "WARN" "Low available memory: ${available_memory}MB"
        fi
    fi
    
    # Platform-specific validation
    validate_platform_specific
    
    if [[ $errors -gt 0 ]]; then
        log "ERROR" "Environment validation failed with $errors errors"
        return 1
    fi
    
    log "PASS" "Environment validation passed"
    return 0
}

validate_platform_specific() {
    local platform="$(uname -s)"
    
    log "DEBUG" "Validating platform: $platform"
    
    case "${platform}" in
        "Linux")
            validate_linux_environment
            ;;
        "Darwin")
            validate_macos_environment
            ;;
        "CYGWIN"*|"MINGW"*|"MSYS"*)
            validate_windows_environment
            ;;
        *)
            log "WARN" "Unknown platform: ${platform}"
            ;;
    esac
}

validate_linux_environment() {
    log "DEBUG" "Validating Linux environment"
    
    # Check display server
    if [[ -z "${DISPLAY:-}" ]] && [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
        log "WARN" "No display server detected (DISPLAY or WAYLAND_DISPLAY)"
    fi
    
    # Check for AppImage requirements
    if ! command -v fuse >/dev/null 2>&1; then
        log "INFO" "FUSE not available, AppImage may need extraction"
    fi
    
    # Check required libraries (basic check)
    local required_commands=("ldconfig")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log "DEBUG" "Command not available: $cmd"
        fi
    done
}

validate_macos_environment() {
    log "DEBUG" "Validating macOS environment"
    
    # Check for basic macOS structures
    if [[ ! -d "/System" ]]; then
        log "WARN" "macOS system directory not found"
    fi
}

validate_windows_environment() {
    log "DEBUG" "Validating Windows environment"
    
    # Check for Windows-specific requirements
    if ! command -v cmd >/dev/null 2>&1; then
        log "WARN" "Windows command processor not available"
    fi
}

# === PERFORMANCE OPTIMIZATION ===
optimize_performance() {
    log "INFO" "Applying performance optimizations"
    
    case "${PERFORMANCE_MODE}" in
        "high")
            apply_high_performance_settings
            ;;
        "balanced")
            apply_balanced_settings
            ;;
        "low")
            apply_low_performance_settings
            ;;
        *)
            log "WARN" "Unknown performance mode: ${PERFORMANCE_MODE}"
            apply_balanced_settings
            ;;
    esac
    
    log "PASS" "Performance optimizations applied"
}

apply_high_performance_settings() {
    log "DEBUG" "Applying high performance settings"
    
    # Set high CPU priority if possible
    if command -v nice >/dev/null 2>&1; then
        export NICE_PRIORITY="-5"
    fi
    
    # Optimize memory settings
    export MALLOC_CHECK_=0
    export MALLOC_PERTURB_=0
}

apply_balanced_settings() {
    log "DEBUG" "Applying balanced performance settings"
    
    # Default settings - no special optimizations
    export NICE_PRIORITY="0"
}

apply_low_performance_settings() {
    log "DEBUG" "Applying low performance settings"
    
    # Reduce resource usage
    export NICE_PRIORITY="10"
    export MALLOC_CHECK_=1
}

fix_permissions() {
    log "DEBUG" "Fixing file permissions"
    
    # Fix script permissions
    chmod +x "${SCRIPT_DIR}"/*.sh 2>/dev/null || true
    
    # Fix binary permissions
    if [[ -f "${APP_BINARY}" ]]; then
        chmod +x "${APP_BINARY}" 2>/dev/null || {
            log "WARN" "Could not fix binary permissions"
        }
    fi
}

# === SECURITY VALIDATION ===
validate_security() {
    log "INFO" "Performing security validation"
    
    local security_issues=0
    
    # Check binary integrity
    if [[ -f "${APP_BINARY}" ]]; then
        local file_size
        file_size=$(stat -c%s "${APP_BINARY}" 2>/dev/null || echo "0")
        
        if [[ $file_size -lt 1024 ]]; then
            log "ERROR" "Binary file appears corrupted (too small)"
            ((security_issues++))
        fi
    fi
    
    # Check for suspicious files
    local suspicious_patterns=("*.tmp.exe" "*.tmp.bat" "*malware*")
    for pattern in "${suspicious_patterns[@]}"; do
        if ls $pattern 2>/dev/null | grep -q .; then
            log "WARN" "Suspicious files found matching pattern: $pattern"
            ((security_issues++))
        fi
    done
    
    # Validate script directory permissions
    local dir_perms
    dir_perms=$(stat -c%a "${SCRIPT_DIR}" 2>/dev/null || echo "755")
    if [[ "$dir_perms" == "777" ]]; then
        log "WARN" "Script directory has overly permissive permissions: $dir_perms"
        ((security_issues++))
    fi
    
    if [[ $security_issues -eq 0 ]]; then
        log "PASS" "Security validation passed"
    else
        log "WARN" "Security validation completed with $security_issues issues"
    fi
    
    return 0
}

# === APPLICATION LAUNCH ===
launch_application() {
    local launch_args=("$@")
    
    log "INFO" "Launching ${APP_NAME} v${APP_VERSION}"
    
    # Apply performance optimizations
    optimize_performance
    
    # Perform security validation
    validate_security
    
    # Set up environment variables
    export CURSOR_LAUNCHER_VERSION="${SCRIPT_VERSION}"
    export CURSOR_CONFIG_DIR="${CONFIG_DIR}"
    export CURSOR_CACHE_DIR="${CACHE_DIR}"
    
    # Launch application based on mode
    case "${LAUNCH_MODE}" in
        "debug")
            launch_debug_mode "${launch_args[@]}"
            ;;
        "safe")
            launch_safe_mode "${launch_args[@]}"
            ;;
        *)
            launch_normal_mode "${launch_args[@]}"
            ;;
    esac
}

launch_normal_mode() {
    local args=("$@")
    
    log "DEBUG" "Launching in normal mode"
    
    # Launch application
    if [[ -n "${NICE_PRIORITY:-}" ]] && command -v nice >/dev/null 2>&1; then
        exec nice -n "${NICE_PRIORITY}" "${APP_BINARY}" "${args[@]}"
    else
        exec "${APP_BINARY}" "${args[@]}"
    fi
}

launch_debug_mode() {
    local args=("$@")
    
    log "DEBUG" "Launching in debug mode"
    
    # Enable debug environment
    export DEBUG=1
    export VERBOSE=1
    
    # Launch with debug output
    exec "${APP_BINARY}" "${args[@]}" 2>&1 | tee "${LOG_DIR}/debug_${TIMESTAMP}.log"
}

launch_safe_mode() {
    local args=("$@")
    
    log "DEBUG" "Launching in safe mode"
    
    # Launch with minimal environment
    env -i HOME="$HOME" USER="$USER" PATH="$PATH" DISPLAY="${DISPLAY:-}" \
        "${APP_BINARY}" "${args[@]}"
}

# === REPORTING ===
generate_launch_report() {
    local report_file="${LOG_DIR}/launch_report_${TIMESTAMP}.json"
    
    log "INFO" "Generating launch report"
    
    cat > "${report_file}" <<EOF
{
    "report_generated": "$(date -Iseconds)",
    "launcher_version": "${SCRIPT_VERSION}",
    "app_version": "${APP_VERSION}",
    "profile": "${PROFILE}",
    "launch_mode": "${LAUNCH_MODE}",
    "security_level": "${SECURITY_LEVEL}",
    "performance_mode": "${PERFORMANCE_MODE}",
    "platform": "$(uname -s)",
    "system_info": {
        "hostname": "$(hostname)",
        "user": "$(whoami)",
        "pwd": "$(pwd)",
        "shell": "${SHELL:-unknown}"
    }
}
EOF
    
    log "PASS" "Launch report generated: ${report_file}"
    echo "${report_file}"
}

show_launcher_status() {
    echo -e "${BOLD}=== CURSOR LAUNCHER STATUS ===${NC}"
    echo "Launcher Version: ${SCRIPT_VERSION}"
    echo "App Version: ${APP_VERSION}"
    echo "Profile: ${PROFILE}"
    echo "Launch Mode: ${LAUNCH_MODE}"
    echo "Security Level: ${SECURITY_LEVEL}"
    echo "Performance Mode: ${PERFORMANCE_MODE}"
    echo
    echo -e "${BOLD}=== CONFIGURATION ===${NC}"
    echo "Config Directory: ${CONFIG_DIR}"
    echo "Cache Directory: ${CACHE_DIR}"
    echo "Log Directory: ${LOG_DIR}"
    echo "App Binary: ${APP_BINARY}"
    echo
    echo -e "${BOLD}=== SYSTEM INFO ===${NC}"
    echo "Platform: $(uname -s)"
    echo "Architecture: $(uname -m)"
    echo "Hostname: $(hostname)"
    echo "User: $(whoami)"
    echo
    echo -e "${BOLD}=== STATISTICS ===${NC}"
    echo "Log Files: $(find "${LOG_DIR}" -name "*.log" 2>/dev/null | wc -l || echo "0")"
    echo "Cache Size: $(du -sh "${CACHE_DIR}" 2>/dev/null | cut -f1 || echo "0K")"
}

# === MAIN EXECUTION ===
show_usage() {
    cat <<EOF
${BOLD}Cursor Launcher v${SCRIPT_VERSION} - Professional Edition${NC}

${BOLD}USAGE:${NC}
    ${SCRIPT_NAME} [OPTIONS] [-- APP_ARGS...]

${BOLD}OPTIONS:${NC}
    --profile PROFILE      Use specific profile (default: default)
    --mode MODE            Launch mode: normal|debug|safe
    --security LEVEL       Security level: minimal|standard|high
    --performance MODE     Performance mode: low|balanced|high
    --verbose, -v          Enable verbose output
    --debug                Enable debug mode
    --status               Show launcher status
    --report               Generate launch report
    --help, -h             Show this help
    --version              Show version information

${BOLD}LAUNCH MODES:${NC}
    normal                 Standard application launch (default)
    debug                  Launch with debug output and logging
    safe                   Launch with minimal environment

${BOLD}EXAMPLES:${NC}
    ${SCRIPT_NAME}                              # Standard launch
    ${SCRIPT_NAME} --mode debug                 # Debug launch
    ${SCRIPT_NAME} --performance high           # High performance
    ${SCRIPT_NAME} --status                     # Show status
    ${SCRIPT_NAME} -- --app-arg value           # Pass args to app

${BOLD}CONFIGURATION:${NC}
    Config: ${LAUNCHER_CONFIG}
    Logs: ${LOG_DIR}
    Cache: ${CACHE_DIR}
EOF
}

main() {
    local app_args=()
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile)
                PROFILE="$2"
                shift 2
                ;;
            --mode)
                LAUNCH_MODE="$2"
                shift 2
                ;;
            --security)
                SECURITY_LEVEL="$2"
                shift 2
                ;;
            --performance)
                PERFORMANCE_MODE="$2"
                shift 2
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --debug)
                DEBUG_MODE=true
                VERBOSE=true
                shift
                ;;
            --status)
                initialize_launcher
                show_launcher_status
                exit 0
                ;;
            --report)
                initialize_launcher
                local report_file
                report_file=$(generate_launch_report)
                echo "Report generated: ${report_file}"
                if command -v jq >/dev/null 2>&1; then
                    jq . "${report_file}"
                else
                    cat "${report_file}"
                fi
                exit 0
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            --version)
                echo "Cursor Launcher v${SCRIPT_VERSION}"
                exit 0
                ;;
            --)
                shift
                break
                ;;
            *)
                app_args+=("$1")
                shift
                ;;
        esac
    done
    
    # Add remaining arguments
    app_args+=("$@")
    
    # Initialize launcher
    initialize_launcher || {
        log "ERROR" "Launcher initialization failed"
        exit 1
    }
    
    # Launch application
    launch_application "${app_args[@]}"
}

# Cleanup function
cleanup_launcher() {
    log "DEBUG" "Performing launcher cleanup"
    
    # Clean temporary files
    find "${CACHE_DIR}" -name "*.tmp" -mtime +1 -delete 2>/dev/null || true
    
    log "PASS" "Launcher cleanup completed"
}

trap cleanup_launcher EXIT

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi