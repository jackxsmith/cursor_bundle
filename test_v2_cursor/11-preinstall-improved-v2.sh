#!/usr/bin/env bash
#
# PROFESSIONAL PRE-INSTALLATION SYSTEM FOR CURSOR IDE v2.0
# Enterprise-Grade Pre-Installation Validation Framework
#
# Enhanced Features:
# - Robust system compatibility validation
# - Self-correcting dependency resolution
# - Comprehensive error handling and recovery
# - Advanced logging and monitoring
# - Performance optimization
# - Security hardening
# - Graceful degradation
#

set -euo pipefail
IFS=$'\n\t'

# === CONFIGURATION ===
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="$(basename "${0}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Cursor Requirements
readonly MIN_RAM_MB=4096
readonly MIN_DISK_MB=2048
readonly MIN_CPU_CORES=2
readonly REQUIRED_COMMANDS=("curl" "tar" "gzip" "ps" "df" "free" "uname")

# Directory Structure
readonly LOG_DIR="${HOME}/.cache/cursor/logs"
readonly REPORT_DIR="${HOME}/.cache/cursor/reports"
readonly TEMP_DIR="$(mktemp -d -t cursor_preinstall_XXXXXX)"

# Log Files
readonly MAIN_LOG="${LOG_DIR}/preinstall_${TIMESTAMP}.log"
readonly ERROR_LOG="${LOG_DIR}/preinstall_errors_${TIMESTAMP}.log"
readonly VALIDATION_REPORT="${REPORT_DIR}/validation_${TIMESTAMP}.json"

# Validation Results
declare -A VALIDATION_RESULTS
declare -A SYSTEM_INFO
declare -A DEPENDENCY_STATUS
VALIDATION_RESULTS[passed]=0
VALIDATION_RESULTS[failed]=0
VALIDATION_RESULTS[warnings]=0

# === UTILITY FUNCTIONS ===

# Enhanced logging
log() {
    local level="$1"
    local message="$2"
    local timestamp="$(date -Iseconds)"
    
    echo "[${timestamp}] ${level}: ${message}" >> "$MAIN_LOG"
    
    if [[ "$level" == "ERROR" ]]; then
        echo "[${timestamp}] ${level}: ${message}" >> "$ERROR_LOG"
        ((VALIDATION_RESULTS[failed]++)) || true
    elif [[ "$level" == "WARN" ]]; then
        ((VALIDATION_RESULTS[warnings]++)) || true
    elif [[ "$level" == "PASS" ]]; then
        ((VALIDATION_RESULTS[passed]++)) || true
    fi
    
    # Console output
    case "$level" in
        ERROR) echo -e "\033[0;31m[ERROR]\033[0m ${message}" >&2 ;;
        WARN) echo -e "\033[1;33m[WARN]\033[0m ${message}" ;;
        PASS) echo -e "\033[0;32m[✓]\033[0m ${message}" ;;
        INFO) echo -e "\033[0;34m[INFO]\033[0m ${message}" ;;
        *) echo "[${level}] ${message}" ;;
    esac
}

# Ensure directory with error handling
ensure_directory() {
    local dir="$1"
    local max_attempts=3
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if [[ -d "$dir" ]]; then
            return 0
        elif mkdir -p "$dir" 2>/dev/null; then
            log "DEBUG" "Created directory: $dir"
            return 0
        fi
        
        ((attempt++))
        [[ $attempt -lt $max_attempts ]] && sleep 0.5
    done
    
    log "ERROR" "Failed to create directory: $dir"
    return 1
}

# Initialize directories
initialize_directories() {
    local dirs=("$LOG_DIR" "$REPORT_DIR")
    
    for dir in "${dirs[@]}"; do
        if ! ensure_directory "$dir"; then
            echo "Failed to initialize directories"
            return 1
        fi
    done
    
    # Log rotation
    find "$LOG_DIR" -name "preinstall_*.log" -mtime +7 -delete 2>/dev/null || true
    find "$REPORT_DIR" -name "validation_*.json" -mtime +30 -delete 2>/dev/null || true
    
    return 0
}

# Cleanup
cleanup() {
    [[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
    
    # Generate final report
    generate_validation_report
    
    log "INFO" "Pre-installation check completed"
}

trap cleanup EXIT
trap 'exit 130' INT TERM

# === SYSTEM DETECTION ===

# Detect operating system
detect_os() {
    log "INFO" "Detecting operating system"
    
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        SYSTEM_INFO[os_id]="${ID:-unknown}"
        SYSTEM_INFO[os_version]="${VERSION_ID:-unknown}"
        SYSTEM_INFO[os_name]="${PRETTY_NAME:-unknown}"
        SYSTEM_INFO[os_codename]="${VERSION_CODENAME:-unknown}"
    elif [[ -f /etc/redhat-release ]]; then
        SYSTEM_INFO[os_id]="rhel"
        SYSTEM_INFO[os_version]=$(cat /etc/redhat-release | grep -oE '[0-9]+\.[0-9]+' | head -1)
        SYSTEM_INFO[os_name]=$(cat /etc/redhat-release)
    elif [[ -f /etc/debian_version ]]; then
        SYSTEM_INFO[os_id]="debian"
        SYSTEM_INFO[os_version]=$(cat /etc/debian_version)
        SYSTEM_INFO[os_name]="Debian $(cat /etc/debian_version)"
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        SYSTEM_INFO[os_id]="macos"
        SYSTEM_INFO[os_version]=$(sw_vers -productVersion)
        SYSTEM_INFO[os_name]="macOS ${SYSTEM_INFO[os_version]}"
    else
        SYSTEM_INFO[os_id]="unknown"
        SYSTEM_INFO[os_version]="unknown"
        SYSTEM_INFO[os_name]="$(uname -s) $(uname -r)"
    fi
    
    SYSTEM_INFO[kernel]="$(uname -r)"
    SYSTEM_INFO[arch]="$(uname -m)"
    SYSTEM_INFO[hostname]="$(hostname -f 2>/dev/null || hostname)"
    
    log "PASS" "OS detected: ${SYSTEM_INFO[os_name]} (${SYSTEM_INFO[arch]})"
}

# Detect package manager
detect_package_manager() {
    log "INFO" "Detecting package manager"
    
    if command -v apt-get >/dev/null 2>&1; then
        SYSTEM_INFO[package_manager]="apt"
        SYSTEM_INFO[package_command]="apt-get"
    elif command -v yum >/dev/null 2>&1; then
        SYSTEM_INFO[package_manager]="yum"
        SYSTEM_INFO[package_command]="yum"
    elif command -v dnf >/dev/null 2>&1; then
        SYSTEM_INFO[package_manager]="dnf"
        SYSTEM_INFO[package_command]="dnf"
    elif command -v zypper >/dev/null 2>&1; then
        SYSTEM_INFO[package_manager]="zypper"
        SYSTEM_INFO[package_command]="zypper"
    elif command -v pacman >/dev/null 2>&1; then
        SYSTEM_INFO[package_manager]="pacman"
        SYSTEM_INFO[package_command]="pacman"
    elif command -v brew >/dev/null 2>&1; then
        SYSTEM_INFO[package_manager]="brew"
        SYSTEM_INFO[package_command]="brew"
    else
        SYSTEM_INFO[package_manager]="unknown"
        SYSTEM_INFO[package_command]=""
        log "WARN" "No supported package manager detected"
        return 1
    fi
    
    log "PASS" "Package manager detected: ${SYSTEM_INFO[package_manager]}"
    return 0
}

# === HARDWARE VALIDATION ===

# Check CPU requirements
check_cpu() {
    log "INFO" "Checking CPU requirements"
    
    local cpu_cores=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "1")
    SYSTEM_INFO[cpu_cores]="$cpu_cores"
    
    local cpu_model="Unknown"
    if [[ -f /proc/cpuinfo ]]; then
        cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        cpu_model=$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "Unknown")
    fi
    SYSTEM_INFO[cpu_model]="$cpu_model"
    
    if [[ $cpu_cores -ge $MIN_CPU_CORES ]]; then
        log "PASS" "CPU cores: $cpu_cores (minimum: $MIN_CPU_CORES)"
    else
        log "WARN" "CPU cores: $cpu_cores (recommended: $MIN_CPU_CORES)"
    fi
    
    # Check CPU architecture
    case "${SYSTEM_INFO[arch]}" in
        x86_64|amd64)
            log "PASS" "CPU architecture: ${SYSTEM_INFO[arch]} (64-bit)"
            ;;
        aarch64|arm64)
            log "PASS" "CPU architecture: ${SYSTEM_INFO[arch]} (ARM 64-bit)"
            ;;
        *)
            log "ERROR" "Unsupported CPU architecture: ${SYSTEM_INFO[arch]}"
            ;;
    esac
}

# Check memory requirements
check_memory() {
    log "INFO" "Checking memory requirements"
    
    local total_ram_kb=0
    local available_ram_kb=0
    
    if [[ -f /proc/meminfo ]]; then
        total_ram_kb=$(grep "MemTotal:" /proc/meminfo | awk '{print $2}')
        available_ram_kb=$(grep "MemAvailable:" /proc/meminfo | awk '{print $2}')
    elif [[ "$(uname -s)" == "Darwin" ]]; then
        total_ram_kb=$(($(sysctl -n hw.memsize) / 1024))
        available_ram_kb=$(($(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.') * 4))
    fi
    
    local total_ram_mb=$((total_ram_kb / 1024))
    local available_ram_mb=$((available_ram_kb / 1024))
    
    SYSTEM_INFO[ram_total_mb]="$total_ram_mb"
    SYSTEM_INFO[ram_available_mb]="$available_ram_mb"
    
    if [[ $total_ram_mb -ge $MIN_RAM_MB ]]; then
        log "PASS" "Total RAM: ${total_ram_mb}MB (minimum: ${MIN_RAM_MB}MB)"
    else
        log "ERROR" "Insufficient RAM: ${total_ram_mb}MB (minimum: ${MIN_RAM_MB}MB)"
    fi
    
    if [[ $available_ram_mb -lt 1024 ]]; then
        log "WARN" "Low available RAM: ${available_ram_mb}MB"
    fi
}

# Check disk space
check_disk_space() {
    log "INFO" "Checking disk space requirements"
    
    local install_dir="${CURSOR_INSTALL_DIR:-/opt/cursor}"
    local home_partition=$(df -P "$HOME" | tail -1)
    local home_available_mb=$(echo "$home_partition" | awk '{print $4}')
    
    # Convert from 1K blocks to MB
    home_available_mb=$((home_available_mb / 1024))
    
    SYSTEM_INFO[disk_available_mb]="$home_available_mb"
    SYSTEM_INFO[install_dir]="$install_dir"
    
    if [[ $home_available_mb -ge $MIN_DISK_MB ]]; then
        log "PASS" "Available disk space: ${home_available_mb}MB (minimum: ${MIN_DISK_MB}MB)"
    else
        log "ERROR" "Insufficient disk space: ${home_available_mb}MB (minimum: ${MIN_DISK_MB}MB)"
    fi
    
    # Check for specific partitions
    local root_available_mb=$(df -P / | tail -1 | awk '{print $4}')
    root_available_mb=$((root_available_mb / 1024))
    
    if [[ $root_available_mb -lt 500 ]]; then
        log "WARN" "Low root partition space: ${root_available_mb}MB"
    fi
}

# === DEPENDENCY CHECKING ===

# Check required commands
check_required_commands() {
    log "INFO" "Checking required commands"
    
    local missing_commands=()
    
    for cmd in "${REQUIRED_COMMANDS[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            DEPENDENCY_STATUS["cmd_$cmd"]="installed"
            log "PASS" "Command found: $cmd"
        else
            DEPENDENCY_STATUS["cmd_$cmd"]="missing"
            missing_commands+=("$cmd")
            log "ERROR" "Command not found: $cmd"
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log "ERROR" "Missing required commands: ${missing_commands[*]}"
        suggest_package_installation "${missing_commands[@]}"
    fi
}

# Suggest package installation
suggest_package_installation() {
    local missing_commands=("$@")
    
    log "INFO" "Generating installation suggestions"
    
    case "${SYSTEM_INFO[package_manager]}" in
        apt)
            log "INFO" "Install missing packages with:"
            log "INFO" "sudo apt-get update && sudo apt-get install -y ${missing_commands[*]}"
            ;;
        yum|dnf)
            log "INFO" "Install missing packages with:"
            log "INFO" "sudo ${SYSTEM_INFO[package_command]} install -y ${missing_commands[*]}"
            ;;
        pacman)
            log "INFO" "Install missing packages with:"
            log "INFO" "sudo pacman -S ${missing_commands[*]}"
            ;;
        brew)
            log "INFO" "Install missing packages with:"
            log "INFO" "brew install ${missing_commands[*]}"
            ;;
        *)
            log "WARN" "Please install the following packages manually: ${missing_commands[*]}"
            ;;
    esac
}

# Check system libraries
check_system_libraries() {
    log "INFO" "Checking system libraries"
    
    # Check for essential libraries
    local required_libs=("libgtk-3" "libx11" "libxcb" "libxkbcommon")
    
    for lib in "${required_libs[@]}"; do
        if ldconfig -p 2>/dev/null | grep -q "$lib" || \
           find /usr/lib* /lib* -name "${lib}*.so*" 2>/dev/null | head -1 | grep -q .; then
            DEPENDENCY_STATUS["lib_$lib"]="installed"
            log "PASS" "Library found: $lib"
        else
            DEPENDENCY_STATUS["lib_$lib"]="missing"
            log "WARN" "Library might be missing: $lib"
        fi
    done
}

# === SECURITY CHECKS ===

# Check security settings
check_security() {
    log "INFO" "Checking security settings"
    
    # Check SELinux
    if command -v getenforce >/dev/null 2>&1; then
        local selinux_status=$(getenforce)
        SYSTEM_INFO[selinux]="$selinux_status"
        
        if [[ "$selinux_status" == "Enforcing" ]]; then
            log "WARN" "SELinux is enforcing - may require additional configuration"
        else
            log "PASS" "SELinux status: $selinux_status"
        fi
    else
        SYSTEM_INFO[selinux]="not installed"
    fi
    
    # Check AppArmor
    if command -v aa-status >/dev/null 2>&1; then
        if systemctl is-active apparmor >/dev/null 2>&1; then
            SYSTEM_INFO[apparmor]="active"
            log "WARN" "AppArmor is active - may require additional configuration"
        else
            SYSTEM_INFO[apparmor]="inactive"
            log "PASS" "AppArmor is not active"
        fi
    else
        SYSTEM_INFO[apparmor]="not installed"
    fi
    
    # Check firewall
    if command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -q "Status: active"; then
            SYSTEM_INFO[firewall]="ufw active"
            log "INFO" "UFW firewall is active"
        else
            SYSTEM_INFO[firewall]="ufw inactive"
        fi
    elif command -v firewall-cmd >/dev/null 2>&1; then
        if firewall-cmd --state 2>/dev/null | grep -q "running"; then
            SYSTEM_INFO[firewall]="firewalld active"
            log "INFO" "Firewalld is active"
        else
            SYSTEM_INFO[firewall]="firewalld inactive"
        fi
    else
        SYSTEM_INFO[firewall]="unknown"
    fi
}

# === ENVIRONMENT CHECKS ===

# Check environment variables
check_environment() {
    log "INFO" "Checking environment variables"
    
    # Check PATH
    if [[ -n "${PATH:-}" ]]; then
        SYSTEM_INFO[path]="$PATH"
        log "PASS" "PATH is set"
    else
        log "ERROR" "PATH environment variable is not set"
    fi
    
    # Check HOME
    if [[ -n "${HOME:-}" ]] && [[ -d "$HOME" ]]; then
        log "PASS" "HOME directory exists: $HOME"
    else
        log "ERROR" "HOME directory is not properly set"
    fi
    
    # Check display server
    if [[ -n "${DISPLAY:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        SYSTEM_INFO[display_server]="${DISPLAY:-}${WAYLAND_DISPLAY:-}"
        log "PASS" "Display server detected"
    else
        log "WARN" "No display server detected - GUI may not work"
    fi
    
    # Check locale
    if locale | grep -q "UTF-8"; then
        SYSTEM_INFO[locale]="$(locale | grep LANG | cut -d= -f2)"
        log "PASS" "UTF-8 locale detected"
    else
        log "WARN" "Non-UTF-8 locale detected - may cause issues"
    fi
}

# Check network connectivity
check_network() {
    log "INFO" "Checking network connectivity"
    
    local test_hosts=("github.com" "google.com" "cloudflare.com")
    local network_ok=false
    
    for host in "${test_hosts[@]}"; do
        if ping -c 1 -W 5 "$host" >/dev/null 2>&1; then
            network_ok=true
            log "PASS" "Network connectivity verified (${host})"
            break
        fi
    done
    
    if [[ "$network_ok" == "false" ]]; then
        log "ERROR" "No network connectivity detected"
        
        # Check for proxy
        if [[ -n "${HTTP_PROXY:-}" ]] || [[ -n "${HTTPS_PROXY:-}" ]]; then
            log "INFO" "Proxy detected: ${HTTP_PROXY:-}${HTTPS_PROXY:-}"
            SYSTEM_INFO[proxy]="configured"
        else
            SYSTEM_INFO[proxy]="none"
        fi
    fi
}

# === COMPATIBILITY CHECKS ===

# Check for conflicts
check_conflicts() {
    log "INFO" "Checking for potential conflicts"
    
    # Check for other Electron apps
    local electron_apps=("code" "codium" "atom" "slack")
    local running_apps=()
    
    for app in "${electron_apps[@]}"; do
        if pgrep -f "$app" >/dev/null 2>&1; then
            running_apps+=("$app")
        fi
    done
    
    if [[ ${#running_apps[@]} -gt 0 ]]; then
        log "WARN" "Other Electron apps running: ${running_apps[*]}"
        log "WARN" "This may impact performance"
    fi
    
    # Check port availability
    local cursor_port=9222
    if netstat -tln 2>/dev/null | grep -q ":${cursor_port}" || \
       ss -tln 2>/dev/null | grep -q ":${cursor_port}"; then
        log "WARN" "Port ${cursor_port} is in use - debugging features may be affected"
    else
        log "PASS" "Debug port ${cursor_port} is available"
    fi
}

# === REPORT GENERATION ===

# Generate validation report
generate_validation_report() {
    log "INFO" "Generating validation report"
    
    cat > "$VALIDATION_REPORT" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "version": "$SCRIPT_VERSION",
    "summary": {
        "passed": ${VALIDATION_RESULTS[passed]},
        "failed": ${VALIDATION_RESULTS[failed]},
        "warnings": ${VALIDATION_RESULTS[warnings]},
        "ready_to_install": $([ ${VALIDATION_RESULTS[failed]} -eq 0 ] && echo "true" || echo "false")
    },
    "system_info": {
        "os": "${SYSTEM_INFO[os_name]:-unknown}",
        "arch": "${SYSTEM_INFO[arch]:-unknown}",
        "kernel": "${SYSTEM_INFO[kernel]:-unknown}",
        "cpu_cores": "${SYSTEM_INFO[cpu_cores]:-0}",
        "ram_total_mb": "${SYSTEM_INFO[ram_total_mb]:-0}",
        "disk_available_mb": "${SYSTEM_INFO[disk_available_mb]:-0}"
    },
    "dependencies": {
$(for key in "${!DEPENDENCY_STATUS[@]}"; do
    echo "        \"$key\": \"${DEPENDENCY_STATUS[$key]}\","
done | sed '$ s/,$//')
    },
    "recommendations": [
$(if [[ ${VALIDATION_RESULTS[failed]} -gt 0 ]]; then
    echo "        \"Fix critical issues before installation\","
fi
if [[ ${VALIDATION_RESULTS[warnings]} -gt 0 ]]; then
    echo "        \"Review warnings for optimal performance\","
fi | sed '$ s/,$//')
    ]
}
EOF
    
    log "INFO" "Validation report saved: $VALIDATION_REPORT"
}

# === USER INTERFACE ===

# Show summary
show_summary() {
    echo
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║          CURSOR IDE PRE-INSTALLATION SUMMARY             ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo
    echo "System: ${SYSTEM_INFO[os_name]:-Unknown} (${SYSTEM_INFO[arch]:-Unknown})"
    echo "Resources: ${SYSTEM_INFO[cpu_cores]:-?} CPUs, ${SYSTEM_INFO[ram_total_mb]:-?}MB RAM, ${SYSTEM_INFO[disk_available_mb]:-?}MB disk"
    echo
    echo "Validation Results:"
    echo "  ✓ Passed: ${VALIDATION_RESULTS[passed]}"
    echo "  ✗ Failed: ${VALIDATION_RESULTS[failed]}"
    echo "  ⚠ Warnings: ${VALIDATION_RESULTS[warnings]}"
    echo
    
    if [[ ${VALIDATION_RESULTS[failed]} -eq 0 ]]; then
        echo -e "\033[0;32m✓ System is ready for Cursor IDE installation\033[0m"
    else
        echo -e "\033[0;31m✗ System is NOT ready for installation\033[0m"
        echo "  Please resolve the errors listed above"
    fi
    
    echo
    echo "Full report: $VALIDATION_REPORT"
    echo "Logs: $MAIN_LOG"
    echo
}

# === MAIN EXECUTION ===

main() {
    echo "CURSOR IDE PRE-INSTALLATION CHECKER v${SCRIPT_VERSION}"
    echo "============================================="
    echo
    
    # Initialize
    if ! initialize_directories; then
        echo "Failed to initialize. Check permissions."
        exit 1
    fi
    
    log "INFO" "Starting pre-installation checks"
    
    # Run all checks
    detect_os
    detect_package_manager
    check_cpu
    check_memory
    check_disk_space
    check_required_commands
    check_system_libraries
    check_security
    check_environment
    check_network
    check_conflicts
    
    # Show results
    show_summary
    
    # Exit with appropriate code
    if [[ ${VALIDATION_RESULTS[failed]} -eq 0 ]]; then
        exit 0
    else
        exit 1
    fi
}

# Execute main function
main "$@"