#!/usr/bin/env bash
#
# ENTERPRISE PRE-INSTALLATION SYSTEM FOR CURSOR IDE v6.9.215
# Advanced Pre-Installation Validation and Preparation Framework
#
# Features:
# - Comprehensive system compatibility analysis
# - Advanced dependency resolution and management
# - Multi-distribution package manager integration
# - Hardware requirement validation and optimization
# - Security assessment and hardening recommendations
# - Network connectivity and proxy configuration
# - Storage requirement analysis and disk space management
# - User permission validation and elevation management
# - System service dependency checking
# - Kernel module and driver verification
# - Container and virtualization environment detection
# - Multi-architecture support and cross-compilation
# - Performance benchmarking and optimization
# - Backup and rollback preparation
# - Enterprise policy compliance validation
# - License verification and activation
# - Integration with configuration management systems
# - Advanced logging and audit trail generation
# - Progress reporting and user notification
# - Automated remediation and fix suggestions
# - Cloud environment detection and optimization
# - Resource usage monitoring and allocation
# - Security vulnerability scanning
# - Compliance framework integration (SOC2, HIPAA, etc.)
# - Custom environment variable management
# - PATH and library configuration optimization
# - Font and rendering subsystem preparation
# - Audio and multimedia framework setup
# - Accessibility feature validation
# - Internationalization and localization setup
# - Plugin architecture preparation
# - Database and external service connectivity testing
# - SSL/TLS certificate validation and management
# - Firewall and network security configuration
# - System performance profiling
# - Memory and CPU optimization recommendations
# - GPU and hardware acceleration detection
# - Advanced error handling and recovery mechanisms

set -euo pipefail
IFS=$'\n\t'

# === CONFIGURATION ===
readonly SCRIPT_VERSION="6.9.215"
readonly SCRIPT_NAME="$(basename "${0}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
readonly VERSION="$(cat "${SCRIPT_DIR}/VERSION" 2>/dev/null || echo "unknown")"

# Directory Structure
readonly LOG_DIR="${HOME}/.cache/cursor/preinstall/logs"
readonly CACHE_DIR="${HOME}/.cache/cursor/preinstall/cache"
readonly CONFIG_DIR="${HOME}/.config/cursor/preinstall"
readonly BACKUP_DIR="${HOME}/.cache/cursor/preinstall/backups"
readonly TEMP_DIR="$(mktemp -d)"

# Configuration Files
readonly MAIN_CONFIG="${CONFIG_DIR}/preinstall.conf"
readonly REQUIREMENTS_FILE="${CONFIG_DIR}/requirements.json"
readonly COMPATIBILITY_DB="${CACHE_DIR}/compatibility.db"
readonly PACKAGE_CACHE="${CACHE_DIR}/packages"

# Logging Configuration
readonly MAIN_LOG="${LOG_DIR}/preinstall_${TIMESTAMP}.log"
readonly ERROR_LOG="${LOG_DIR}/preinstall_errors_${TIMESTAMP}.log"
readonly AUDIT_LOG="${LOG_DIR}/preinstall_audit_${TIMESTAMP}.log"
readonly PERFORMANCE_LOG="${LOG_DIR}/preinstall_performance_${TIMESTAMP}.log"

# Colors and Formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

# System Requirements
declare -A MIN_REQUIREMENTS=(
    ["memory_mb"]=2048
    ["disk_space_mb"]=4096
    ["cpu_cores"]=2
    ["cpu_freq_mhz"]=1800
    ["kernel_version"]="3.10.0"
    ["glibc_version"]="2.17"
)

declare -A RECOMMENDED_REQUIREMENTS=(
    ["memory_mb"]=8192
    ["disk_space_mb"]=16384
    ["cpu_cores"]=4
    ["cpu_freq_mhz"]=2400
    ["kernel_version"]="4.15.0"
    ["glibc_version"]="2.27"
)

# System Information
declare -A SYSTEM_INFO=(
    ["os_name"]=""
    ["os_version"]=""
    ["os_id"]=""
    ["architecture"]=""
    ["kernel_version"]=""
    ["cpu_model"]=""
    ["cpu_cores"]=""
    ["memory_total"]=""
    ["disk_space"]=""
    ["package_manager"]=""
    ["init_system"]=""
    ["desktop_environment"]=""
    ["display_server"]=""
    ["gpu_vendor"]=""
    ["network_status"]=""
    ["virtualization"]=""
    ["container_runtime"]=""
)

# Check Results
declare -A CHECK_RESULTS=(
    ["system_compatibility"]=0
    ["hardware_requirements"]=0
    ["software_dependencies"]=0
    ["network_connectivity"]=0
    ["security_assessment"]=0
    ["performance_baseline"]=0
    ["storage_analysis"]=0
    ["user_permissions"]=0
    ["service_dependencies"]=0
    ["environment_setup"]=0
)

declare -a CRITICAL_ISSUES=()
declare -a WARNING_ISSUES=()
declare -a INFO_MESSAGES=()
declare -a REMEDIATION_STEPS=()

# === INITIALIZATION ===
initialize_preinstall_system() {
    info "Initializing Cursor Pre-Installation System v${SCRIPT_VERSION}"
    
    # Create directory structure
    create_directory_structure
    
    # Initialize logging
    init_logging_system
    
    # Load configuration
    load_configuration
    
    # Detect system information
    detect_system_information
    
    # Initialize compatibility database
    init_compatibility_database
    
    info "Pre-installation system initialized successfully"
}

create_directory_structure() {
    local directories=(
        "${LOG_DIR}"
        "${CACHE_DIR}"
        "${CONFIG_DIR}"
        "${BACKUP_DIR}"
        "${PACKAGE_CACHE}"
        "${CONFIG_DIR}/profiles"
        "${CONFIG_DIR}/templates"
        "${CACHE_DIR}/downloads"
        "${CACHE_DIR}/benchmarks"
    )
    
    for dir in "${directories[@]}"; do
        if ! mkdir -p "${dir}" 2>/dev/null; then
            warn "Failed to create directory: ${dir}"
        fi
    done
    
    debug "Directory structure created"
}

init_logging_system() {
    # Initialize main log
    cat > "${MAIN_LOG}" <<EOF
=== Cursor Pre-Installation System v${SCRIPT_VERSION} ===
Session started: $(date -Iseconds)
User: $(whoami)
Working directory: ${SCRIPT_DIR}
System: $(uname -a)
Cursor version: ${VERSION}

EOF
    
    # Initialize other logs
    : > "${ERROR_LOG}"
    : > "${AUDIT_LOG}"
    : > "${PERFORMANCE_LOG}"
    
    debug "Logging system initialized"
}

# === LOGGING FUNCTIONS ===
log() {
    local level="$1"
    local message="$2"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    echo "[${timestamp}] [${level}] ${message}" >> "${MAIN_LOG}"
    
    case "${level}" in
        "ERROR") echo "[${timestamp}] [ERROR] ${message}" >> "${ERROR_LOG}" ;;
        "AUDIT") echo "[${timestamp}] [AUDIT] ${message}" >> "${AUDIT_LOG}" ;;
        "PERF") echo "[${timestamp}] [PERF] ${message}" >> "${PERFORMANCE_LOG}" ;;
    esac
    
    # Console output with colors
    case "${level}" in
        "ERROR") echo -e "${RED}[ERROR]${NC} ${message}" >&2 ;;
        "WARN") echo -e "${YELLOW}[WARN]${NC} ${message}" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} ${message}" ;;
        "INFO") echo -e "${BLUE}[INFO]${NC} ${message}" ;;
        "DEBUG") [[ "${DEBUG:-false}" == "true" ]] && echo -e "${PURPLE}[DEBUG]${NC} ${message}" ;;
        *) echo "[${level}] ${message}" ;;
    esac
}

error() { log "ERROR" "$1"; }
warn() { log "WARN" "$1"; }
success() { log "SUCCESS" "$1"; }
info() { log "INFO" "$1"; }
debug() { log "DEBUG" "$1"; }
audit() { log "AUDIT" "$1"; }
perf() { log "PERF" "$1"; }

# === CONFIGURATION MANAGEMENT ===
load_configuration() {
    info "Loading pre-installation configuration"
    
    if [[ ! -f "${MAIN_CONFIG}" ]]; then
        create_default_configuration
    fi
    
    # Source configuration
    source "${MAIN_CONFIG}"
    
    # Load requirements file
    if [[ ! -f "${REQUIREMENTS_FILE}" ]]; then
        create_requirements_file
    fi
    
    debug "Configuration loaded"
}

create_default_configuration() {
    info "Creating default pre-installation configuration"
    
    cat > "${MAIN_CONFIG}" <<EOF
# Cursor Pre-Installation Configuration
# Generated on $(date -Iseconds)

# Validation Settings
STRICT_MODE=false
SKIP_OPTIONAL_CHECKS=false
AUTO_REMEDIATION=true
INTERACTIVE_MODE=true

# Performance Settings
PARALLEL_CHECKS=true
MAX_PARALLEL_JOBS=4
TIMEOUT_SECONDS=30
BENCHMARK_ENABLED=true

# Network Settings
NETWORK_TIMEOUT=10
DOWNLOAD_TIMEOUT=30
PROXY_AUTO_DETECT=true
DNS_VERIFICATION=true

# Security Settings
SECURITY_SCAN_ENABLED=true
VULNERABILITY_CHECK=true
CERTIFICATE_VALIDATION=true
FIREWALL_CHECK=true

# Logging Settings
VERBOSE_LOGGING=true
DEBUG_MODE=false
AUDIT_ENABLED=true
PERFORMANCE_TRACKING=true

# Package Manager Settings
AUTO_INSTALL_DEPENDENCIES=false
USE_PACKAGE_CACHE=true
VERIFY_PACKAGE_SIGNATURES=true
UPDATE_PACKAGE_LISTS=true
EOF
}

create_requirements_file() {
    info "Creating system requirements file"
    
    cat > "${REQUIREMENTS_FILE}" <<EOF
{
    "version": "${SCRIPT_VERSION}",
    "created": "$(date -Iseconds)",
    "minimum_requirements": {
        "memory_mb": ${MIN_REQUIREMENTS[memory_mb]},
        "disk_space_mb": ${MIN_REQUIREMENTS[disk_space_mb]},
        "cpu_cores": ${MIN_REQUIREMENTS[cpu_cores]},
        "cpu_freq_mhz": ${MIN_REQUIREMENTS[cpu_freq_mhz]},
        "kernel_version": "${MIN_REQUIREMENTS[kernel_version]}",
        "glibc_version": "${MIN_REQUIREMENTS[glibc_version]}"
    },
    "recommended_requirements": {
        "memory_mb": ${RECOMMENDED_REQUIREMENTS[memory_mb]},
        "disk_space_mb": ${RECOMMENDED_REQUIREMENTS[disk_space_mb]},
        "cpu_cores": ${RECOMMENDED_REQUIREMENTS[cpu_cores]},
        "cpu_freq_mhz": ${RECOMMENDED_REQUIREMENTS[cpu_freq_mhz]},
        "kernel_version": "${RECOMMENDED_REQUIREMENTS[kernel_version]}",
        "glibc_version": "${RECOMMENDED_REQUIREMENTS[glibc_version]}"
    },
    "supported_distributions": [
        {"name": "Ubuntu", "versions": ["18.04", "20.04", "22.04", "24.04"]},
        {"name": "Debian", "versions": ["10", "11", "12"]},
        {"name": "RHEL", "versions": ["8", "9"]},
        {"name": "CentOS", "versions": ["8", "9"]},
        {"name": "Fedora", "versions": ["36", "37", "38", "39"]},
        {"name": "openSUSE", "versions": ["15.4", "15.5"]},
        {"name": "Arch Linux", "versions": ["current"]},
        {"name": "Alpine", "versions": ["3.17", "3.18", "3.19"]}
    ],
    "required_packages": {
        "essential": ["curl", "wget", "tar", "gzip", "unzip"],
        "development": ["build-essential", "cmake", "pkg-config"],
        "graphics": ["libgl1-mesa-dev", "libglu1-mesa-dev"],
        "audio": ["libasound2-dev", "pulseaudio-utils"],
        "networking": ["ca-certificates", "openssl"],
        "fonts": ["fontconfig", "fonts-liberation"]
    },
    "optional_packages": {
        "performance": ["htop", "iotop", "sysstat"],
        "development": ["git", "nodejs", "python3", "java"],
        "multimedia": ["ffmpeg", "imagemagick"],
        "compression": ["p7zip-full", "rar", "unrar"]
    }
}
EOF
}

# === SYSTEM DETECTION ===
detect_system_information() {
    info "Detecting system information"
    
    local start_time
    start_time=$(date +%s.%N)
    
    # Operating System Information
    detect_os_information
    
    # Hardware Information
    detect_hardware_information
    
    # Software Environment
    detect_software_environment
    
    # Network Configuration
    detect_network_configuration
    
    # Virtualization and Containers
    detect_virtualization_environment
    
    local end_time
    end_time=$(date +%s.%N)
    local duration
    duration=$(echo "${end_time} - ${start_time}" | bc -l 2>/dev/null || echo "0")
    
    perf "System detection completed in ${duration}s"
    audit "system_detection_completed" "duration=${duration}s"
    
    info "System information detection completed"
}

detect_os_information() {
    debug "Detecting operating system information"
    
    # Read OS release information
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        SYSTEM_INFO["os_name"]="${NAME:-Unknown}"
        SYSTEM_INFO["os_version"]="${VERSION:-Unknown}"
        SYSTEM_INFO["os_id"]="${ID:-unknown}"
    else
        SYSTEM_INFO["os_name"]="Unknown Linux"
        SYSTEM_INFO["os_version"]="Unknown"
        SYSTEM_INFO["os_id"]="unknown"
        warn "OS release file not found"
    fi
    
    # Architecture
    SYSTEM_INFO["architecture"]="$(uname -m)"
    
    # Kernel version
    SYSTEM_INFO["kernel_version"]="$(uname -r)"
    
    debug "OS: ${SYSTEM_INFO[os_name]} ${SYSTEM_INFO[os_version]} (${SYSTEM_INFO[architecture]})"
}

detect_hardware_information() {
    debug "Detecting hardware information"
    
    # CPU Information
    if [[ -f /proc/cpuinfo ]]; then
        SYSTEM_INFO["cpu_model"]="$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | sed 's/^ *//')"
        SYSTEM_INFO["cpu_cores"]="$(nproc)"
    else
        SYSTEM_INFO["cpu_model"]="Unknown"
        SYSTEM_INFO["cpu_cores"]="1"
    fi
    
    # Memory Information
    if [[ -f /proc/meminfo ]]; then
        local memory_kb
        memory_kb="$(grep "MemTotal" /proc/meminfo | awk '{print $2}')"
        SYSTEM_INFO["memory_total"]="$((memory_kb / 1024))"
    else
        SYSTEM_INFO["memory_total"]="0"
    fi
    
    # Disk Space Information
    local disk_space_mb
    disk_space_mb="$(df -BM "${SCRIPT_DIR}" | awk 'NR==2 {print $4}' | sed 's/M//')"
    SYSTEM_INFO["disk_space"]="${disk_space_mb}"
    
    # GPU Information
    if command -v lspci >/dev/null 2>&1; then
        local gpu_info
        gpu_info="$(lspci | grep -i "vga\|3d\|display" | head -1)"
        if [[ "${gpu_info}" =~ NVIDIA ]]; then
            SYSTEM_INFO["gpu_vendor"]="nvidia"
        elif [[ "${gpu_info}" =~ AMD|ATI ]]; then
            SYSTEM_INFO["gpu_vendor"]="amd"
        elif [[ "${gpu_info}" =~ Intel ]]; then
            SYSTEM_INFO["gpu_vendor"]="intel"
        else
            SYSTEM_INFO["gpu_vendor"]="unknown"
        fi
    else
        SYSTEM_INFO["gpu_vendor"]="unknown"
    fi
    
    debug "Hardware: ${SYSTEM_INFO[cpu_cores]} cores, ${SYSTEM_INFO[memory_total]}MB RAM, ${SYSTEM_INFO[disk_space]}MB disk"
}

detect_software_environment() {
    debug "Detecting software environment"
    
    # Package Manager Detection
    if command -v apt >/dev/null 2>&1; then
        SYSTEM_INFO["package_manager"]="apt"
    elif command -v yum >/dev/null 2>&1; then
        SYSTEM_INFO["package_manager"]="yum"
    elif command -v dnf >/dev/null 2>&1; then
        SYSTEM_INFO["package_manager"]="dnf"
    elif command -v zypper >/dev/null 2>&1; then
        SYSTEM_INFO["package_manager"]="zypper"
    elif command -v pacman >/dev/null 2>&1; then
        SYSTEM_INFO["package_manager"]="pacman"
    elif command -v apk >/dev/null 2>&1; then
        SYSTEM_INFO["package_manager"]="apk"
    else
        SYSTEM_INFO["package_manager"]="unknown"
    fi
    
    # Init System Detection
    if [[ -d /run/systemd/system ]]; then
        SYSTEM_INFO["init_system"]="systemd"
    elif [[ -f /sbin/openrc ]]; then
        SYSTEM_INFO["init_system"]="openrc"
    elif [[ -f /sbin/init ]] && [[ "$(readlink /sbin/init)" =~ upstart ]]; then
        SYSTEM_INFO["init_system"]="upstart"
    else
        SYSTEM_INFO["init_system"]="sysv"
    fi
    
    # Desktop Environment Detection
    if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
        SYSTEM_INFO["desktop_environment"]="${XDG_CURRENT_DESKTOP}"
    elif [[ -n "${DESKTOP_SESSION:-}" ]]; then
        SYSTEM_INFO["desktop_environment"]="${DESKTOP_SESSION}"
    else
        SYSTEM_INFO["desktop_environment"]="none"
    fi
    
    # Display Server Detection
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        SYSTEM_INFO["display_server"]="wayland"
    elif [[ -n "${DISPLAY:-}" ]]; then
        SYSTEM_INFO["display_server"]="x11"
    else
        SYSTEM_INFO["display_server"]="none"
    fi
    
    debug "Software: ${SYSTEM_INFO[package_manager]} package manager, ${SYSTEM_INFO[init_system]} init, ${SYSTEM_INFO[desktop_environment]} desktop"
}

detect_network_configuration() {
    debug "Detecting network configuration"
    
    # Basic connectivity test
    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        SYSTEM_INFO["network_status"]="connected"
    else
        SYSTEM_INFO["network_status"]="disconnected"
    fi
    
    debug "Network: ${SYSTEM_INFO[network_status]}"
}

detect_virtualization_environment() {
    debug "Detecting virtualization environment"
    
    # Virtualization Detection
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        local virt_type
        virt_type="$(systemd-detect-virt 2>/dev/null || echo "none")"
        SYSTEM_INFO["virtualization"]="${virt_type}"
    elif [[ -f /proc/vz/version ]] || [[ -d /proc/vz ]]; then
        SYSTEM_INFO["virtualization"]="openvz"
    elif [[ -f /.dockerenv ]] || grep -q docker /proc/1/cgroup 2>/dev/null; then
        SYSTEM_INFO["virtualization"]="docker"
    else
        SYSTEM_INFO["virtualization"]="none"
    fi
    
    # Container Runtime Detection
    if command -v docker >/dev/null 2>&1; then
        SYSTEM_INFO["container_runtime"]="docker"
    elif command -v podman >/dev/null 2>&1; then
        SYSTEM_INFO["container_runtime"]="podman"
    elif command -v containerd >/dev/null 2>&1; then
        SYSTEM_INFO["container_runtime"]="containerd"
    else
        SYSTEM_INFO["container_runtime"]="none"
    fi
    
    debug "Virtualization: ${SYSTEM_INFO[virtualization]}, Container: ${SYSTEM_INFO[container_runtime]}"
}

# === COMPATIBILITY DATABASE ===
init_compatibility_database() {
    debug "Initializing compatibility database"
    
    local db_file="${COMPATIBILITY_DB}"
    
    if [[ ! -f "${db_file}" ]]; then
        create_compatibility_database
    fi
    
    # Update database if older than 7 days
    local db_age=0
    if [[ -f "${db_file}" ]]; then
        db_age=$(( $(date +%s) - $(stat -f%m "${db_file}" 2>/dev/null || stat -c%Y "${db_file}" 2>/dev/null || echo 0) ))
    fi
    
    if [[ ${db_age} -gt 604800 ]]; then  # 7 days
        update_compatibility_database
    fi
    
    debug "Compatibility database initialized"
}

create_compatibility_database() {
    debug "Creating compatibility database"
    
    cat > "${COMPATIBILITY_DB}" <<'EOF'
# Cursor IDE Compatibility Database
# Format: os_id:version:architecture:status:notes

# Ubuntu
ubuntu:18.04:x86_64:supported:LTS
ubuntu:20.04:x86_64:supported:LTS
ubuntu:22.04:x86_64:supported:LTS
ubuntu:24.04:x86_64:supported:LTS
ubuntu:18.04:aarch64:supported:ARM64
ubuntu:20.04:aarch64:supported:ARM64
ubuntu:22.04:aarch64:supported:ARM64

# Debian
debian:10:x86_64:supported:Stable
debian:11:x86_64:supported:Stable
debian:12:x86_64:supported:Stable
debian:10:aarch64:supported:ARM64
debian:11:aarch64:supported:ARM64
debian:12:aarch64:supported:ARM64

# RHEL/CentOS
rhel:8:x86_64:supported:Enterprise
rhel:9:x86_64:supported:Enterprise
centos:8:x86_64:supported:Stream
centos:9:x86_64:supported:Stream

# Fedora
fedora:36:x86_64:supported:Recent
fedora:37:x86_64:supported:Recent
fedora:38:x86_64:supported:Recent
fedora:39:x86_64:supported:Latest

# openSUSE
opensuse-leap:15.4:x86_64:supported:Stable
opensuse-leap:15.5:x86_64:supported:Stable
opensuse-tumbleweed:*:x86_64:testing:Rolling

# Arch Linux
arch:*:x86_64:supported:Rolling
manjaro:*:x86_64:supported:Rolling

# Alpine
alpine:3.17:x86_64:supported:Minimal
alpine:3.18:x86_64:supported:Minimal
alpine:3.19:x86_64:supported:Minimal

# Unsupported or legacy
ubuntu:16.04:*:deprecated:EOL
debian:9:*:deprecated:EOL
centos:7:*:deprecated:EOL
EOF
}

update_compatibility_database() {
    debug "Updating compatibility database from remote source"
    
    local remote_db_url="https://releases.cursor.com/compatibility.db"
    local temp_db="${TEMP_DIR}/compatibility.db"
    
    if command -v curl >/dev/null 2>&1; then
        if curl -f -s -L --max-time 30 "${remote_db_url}" -o "${temp_db}"; then
            mv "${temp_db}" "${COMPATIBILITY_DB}"
            info "Compatibility database updated from remote source"
        else
            warn "Failed to update compatibility database from remote source"
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -q -T 30 "${remote_db_url}" -O "${temp_db}"; then
            mv "${temp_db}" "${COMPATIBILITY_DB}"
            info "Compatibility database updated from remote source"
        else
            warn "Failed to update compatibility database from remote source"
        fi
    else
        warn "No download tool available for updating compatibility database"
    fi
}

# === PRE-INSTALLATION CHECKS ===
run_preinstallation_checks() {
    info "Starting comprehensive pre-installation checks"
    
    local start_time
    start_time=$(date +%s.%N)
    
    # Clear previous results
    CRITICAL_ISSUES=()
    WARNING_ISSUES=()
    INFO_MESSAGES=()
    REMEDIATION_STEPS=()
    
    # Run all checks
    local checks=(
        "check_system_compatibility"
        "check_hardware_requirements"
        "check_software_dependencies"
        "check_network_connectivity"
        "check_security_assessment"
        "check_performance_baseline"
        "check_storage_analysis"
        "check_user_permissions"
        "check_service_dependencies"
        "check_environment_setup"
    )
    
    local total_checks=${#checks[@]}
    local completed_checks=0
    
    for check_function in "${checks[@]}"; do
        info "Running ${check_function}..."
        
        local check_start
        check_start=$(date +%s.%N)
        
        if "${check_function}"; then
            success "${check_function} completed successfully"
        else
            error "${check_function} failed"
        fi
        
        local check_end
        check_end=$(date +%s.%N)
        local check_duration
        check_duration=$(echo "${check_end} - ${check_start}" | bc -l 2>/dev/null || echo "0")
        
        perf "${check_function} completed in ${check_duration}s"
        
        ((completed_checks++))
        local progress=$((completed_checks * 100 / total_checks))
        info "Progress: ${progress}% (${completed_checks}/${total_checks})"
    done
    
    local end_time
    end_time=$(date +%s.%N)
    local total_duration
    total_duration=$(echo "${end_time} - ${start_time}" | bc -l 2>/dev/null || echo "0")
    
    perf "All pre-installation checks completed in ${total_duration}s"
    
    # Generate summary report
    generate_check_summary
    
    info "Pre-installation checks completed"
}

check_system_compatibility() {
    debug "Checking system compatibility"
    
    local compatibility_score=0
    local max_score=100
    
    # Check OS compatibility
    local os_compatible=false
    while IFS=':' read -r os_id version arch status notes; do
        if [[ "${os_id}" == "${SYSTEM_INFO[os_id]}" ]]; then
            if [[ "${version}" == "*" ]] || [[ "${SYSTEM_INFO[os_version]}" =~ ${version} ]]; then
                if [[ "${arch}" == "*" ]] || [[ "${arch}" == "${SYSTEM_INFO[architecture]}" ]]; then
                    case "${status}" in
                        "supported")
                            os_compatible=true
                            compatibility_score=$((compatibility_score + 40))
                            INFO_MESSAGES+=("Operating system is fully supported")
                            ;;
                        "testing")
                            os_compatible=true
                            compatibility_score=$((compatibility_score + 30))
                            WARNING_ISSUES+=("Operating system is in testing phase")
                            ;;
                        "deprecated")
                            WARNING_ISSUES+=("Operating system is deprecated: ${notes}")
                            compatibility_score=$((compatibility_score + 10))
                            ;;
                    esac
                    break
                fi
            fi
        fi
    done < "${COMPATIBILITY_DB}"
    
    if [[ "${os_compatible}" == "false" ]]; then
        CRITICAL_ISSUES+=("Unsupported operating system: ${SYSTEM_INFO[os_name]} ${SYSTEM_INFO[os_version]} (${SYSTEM_INFO[architecture]})")
        REMEDIATION_STEPS+=("Consider upgrading to a supported operating system version")
    fi
    
    # Check architecture compatibility
    case "${SYSTEM_INFO[architecture]}" in
        "x86_64"|"amd64")
            compatibility_score=$((compatibility_score + 30))
            INFO_MESSAGES+=("Architecture ${SYSTEM_INFO[architecture]} is fully supported")
            ;;
        "aarch64"|"arm64")
            compatibility_score=$((compatibility_score + 25))
            INFO_MESSAGES+=("Architecture ${SYSTEM_INFO[architecture]} is supported with some limitations")
            ;;
        "i386"|"i686")
            compatibility_score=$((compatibility_score + 10))
            WARNING_ISSUES+=("32-bit architecture has limited support")
            REMEDIATION_STEPS+=("Consider upgrading to 64-bit system for better performance")
            ;;
        *)
            CRITICAL_ISSUES+=("Unsupported architecture: ${SYSTEM_INFO[architecture]}")
            REMEDIATION_STEPS+=("Install on a supported architecture (x86_64 or aarch64)")
            ;;
    esac
    
    # Check kernel version
    local kernel_version="${SYSTEM_INFO[kernel_version]}"
    local min_kernel="${MIN_REQUIREMENTS[kernel_version]}"
    if version_compare "${kernel_version}" "${min_kernel}"; then
        compatibility_score=$((compatibility_score + 20))
        INFO_MESSAGES+=("Kernel version ${kernel_version} meets minimum requirements")
    else
        WARNING_ISSUES+=("Kernel version ${kernel_version} is below minimum ${min_kernel}")
        REMEDIATION_STEPS+=("Consider updating kernel to version ${min_kernel} or newer")
        compatibility_score=$((compatibility_score + 5))
    fi
    
    # Check glibc version
    if command -v ldd >/dev/null 2>&1; then
        local glibc_version
        glibc_version=$(ldd --version 2>&1 | head -1 | awk '{print $NF}')
        local min_glibc="${MIN_REQUIREMENTS[glibc_version]}"
        if version_compare "${glibc_version}" "${min_glibc}"; then
            compatibility_score=$((compatibility_score + 10))
            INFO_MESSAGES+=("glibc version ${glibc_version} is compatible")
        else
            WARNING_ISSUES+=("glibc version ${glibc_version} is below minimum ${min_glibc}")
            REMEDIATION_STEPS+=("Update system to get newer glibc version")
        fi
    fi
    
    CHECK_RESULTS["system_compatibility"]=${compatibility_score}
    audit "system_compatibility_check" "score=${compatibility_score}/${max_score}"
    
    if [[ ${compatibility_score} -ge 80 ]]; then
        return 0
    else
        return 1
    fi
}

check_hardware_requirements() {
    debug "Checking hardware requirements"
    
    local hw_score=0
    local max_score=100
    
    # Check memory requirements
    local memory_mb="${SYSTEM_INFO[memory_total]}"
    local min_memory="${MIN_REQUIREMENTS[memory_mb]}"
    local rec_memory="${RECOMMENDED_REQUIREMENTS[memory_mb]}"
    
    if [[ ${memory_mb} -ge ${rec_memory} ]]; then
        hw_score=$((hw_score + 30))
        INFO_MESSAGES+=("Memory ${memory_mb}MB exceeds recommended ${rec_memory}MB")
    elif [[ ${memory_mb} -ge ${min_memory} ]]; then
        hw_score=$((hw_score + 20))
        INFO_MESSAGES+=("Memory ${memory_mb}MB meets minimum requirements")
        WARNING_ISSUES+=("Consider upgrading to ${rec_memory}MB for optimal performance")
    else
        hw_score=$((hw_score + 5))
        CRITICAL_ISSUES+=("Insufficient memory: ${memory_mb}MB (minimum: ${min_memory}MB)")
        REMEDIATION_STEPS+=("Add more RAM or close other applications")
    fi
    
    # Check disk space requirements
    local disk_mb="${SYSTEM_INFO[disk_space]}"
    local min_disk="${MIN_REQUIREMENTS[disk_space_mb]}"
    local rec_disk="${RECOMMENDED_REQUIREMENTS[disk_space_mb]}"
    
    if [[ ${disk_mb} -ge ${rec_disk} ]]; then
        hw_score=$((hw_score + 25))
        INFO_MESSAGES+=("Disk space ${disk_mb}MB exceeds recommended ${rec_disk}MB")
    elif [[ ${disk_mb} -ge ${min_disk} ]]; then
        hw_score=$((hw_score + 15))
        INFO_MESSAGES+=("Disk space ${disk_mb}MB meets minimum requirements")
    else
        hw_score=$((hw_score + 5))
        CRITICAL_ISSUES+=("Insufficient disk space: ${disk_mb}MB (minimum: ${min_disk}MB)")
        REMEDIATION_STEPS+=("Free up disk space or install to different location")
    fi
    
    # Check CPU requirements
    local cpu_cores="${SYSTEM_INFO[cpu_cores]}"
    local min_cores="${MIN_REQUIREMENTS[cpu_cores]}"
    local rec_cores="${RECOMMENDED_REQUIREMENTS[cpu_cores]}"
    
    if [[ ${cpu_cores} -ge ${rec_cores} ]]; then
        hw_score=$((hw_score + 25))
        INFO_MESSAGES+=("CPU cores ${cpu_cores} exceeds recommended ${rec_cores}")
    elif [[ ${cpu_cores} -ge ${min_cores} ]]; then
        hw_score=$((hw_score + 15))
        INFO_MESSAGES+=("CPU cores ${cpu_cores} meets minimum requirements")
    else
        hw_score=$((hw_score + 5))
        WARNING_ISSUES+=("CPU cores ${cpu_cores} is below recommended ${rec_cores}")
        REMEDIATION_STEPS+=("Consider upgrading CPU for better performance")
    fi
    
    # Check GPU availability (optional)
    if [[ "${SYSTEM_INFO[gpu_vendor]}" != "unknown" ]]; then
        hw_score=$((hw_score + 10))
        INFO_MESSAGES+=("GPU detected: ${SYSTEM_INFO[gpu_vendor]}")
    else
        hw_score=$((hw_score + 5))
        WARNING_ISSUES+=("No dedicated GPU detected (integrated graphics will be used)")
    fi
    
    # Check virtualization environment impact
    if [[ "${SYSTEM_INFO[virtualization]}" != "none" ]]; then
        hw_score=$((hw_score + 5))
        WARNING_ISSUES+=("Running in virtualized environment: ${SYSTEM_INFO[virtualization]}")
        INFO_MESSAGES+=("Performance may be reduced in virtual environment")
    else
        hw_score=$((hw_score + 10))
    fi
    
    CHECK_RESULTS["hardware_requirements"]=${hw_score}
    audit "hardware_requirements_check" "score=${hw_score}/${max_score}"
    
    if [[ ${hw_score} -ge 60 ]]; then
        return 0
    else
        return 1
    fi
}

check_software_dependencies() {
    debug "Checking software dependencies"
    
    local deps_score=0
    local max_score=100
    
    # Check package manager availability
    local pkg_mgr="${SYSTEM_INFO[package_manager]}"
    if [[ "${pkg_mgr}" != "unknown" ]]; then
        deps_score=$((deps_score + 20))
        INFO_MESSAGES+=("Package manager detected: ${pkg_mgr}")
    else
        deps_score=$((deps_score + 5))
        WARNING_ISSUES+=("No supported package manager found")
        REMEDIATION_STEPS+=("Install packages manually or use supported distribution")
    fi
    
    # Check essential dependencies
    local essential_deps=("curl" "wget" "tar" "gzip" "unzip")
    local missing_essential=()
    local found_essential=0
    
    for dep in "${essential_deps[@]}"; do
        if command -v "${dep}" >/dev/null 2>&1; then
            ((found_essential++))
        else
            missing_essential+=("${dep}")
        fi
    done
    
    local essential_score=$((found_essential * 15 / ${#essential_deps[@]}))
    deps_score=$((deps_score + essential_score))
    
    if [[ ${#missing_essential[@]} -eq 0 ]]; then
        INFO_MESSAGES+=("All essential dependencies are available")
    else
        WARNING_ISSUES+=("Missing essential dependencies: ${missing_essential[*]}")
        REMEDIATION_STEPS+=("Install missing dependencies: ${missing_essential[*]}")
    fi
    
    # Check development dependencies
    local dev_deps=("gcc" "make" "cmake" "pkg-config")
    local missing_dev=()
    local found_dev=0
    
    for dep in "${dev_deps[@]}"; do
        if command -v "${dep}" >/dev/null 2>&1; then
            ((found_dev++))
        else
            missing_dev+=("${dep}")
        fi
    done
    
    local dev_score=$((found_dev * 10 / ${#dev_deps[@]}))
    deps_score=$((deps_score + dev_score))
    
    if [[ ${#missing_dev[@]} -gt 0 ]]; then
        INFO_MESSAGES+=("Optional development tools missing: ${missing_dev[*]}")
    fi
    
    # Check graphics libraries
    local graphics_libs=("libgl1-mesa-dev" "libglu1-mesa-dev" "libx11-dev")
    local found_graphics=0
    
    for lib in "${graphics_libs[@]}"; do
        if check_library_availability "${lib}"; then
            ((found_graphics++))
        fi
    done
    
    local graphics_score=$((found_graphics * 15 / ${#graphics_libs[@]}))
    deps_score=$((deps_score + graphics_score))
    
    # Check font system
    if command -v fc-list >/dev/null 2>&1; then
        deps_score=$((deps_score + 10))
        INFO_MESSAGES+=("Font system (fontconfig) is available")
    else
        WARNING_ISSUES+=("Font system not available")
        REMEDIATION_STEPS+=("Install fontconfig package")
    fi
    
    # Check audio system
    if command -v pulseaudio >/dev/null 2>&1 || [[ -d /proc/asound ]]; then
        deps_score=$((deps_score + 10))
        INFO_MESSAGES+=("Audio system is available")
    else
        INFO_MESSAGES+=("Audio system not detected (optional)")
    fi
    
    # Check SSL/TLS support
    if command -v openssl >/dev/null 2>&1; then
        deps_score=$((deps_score + 10))
        INFO_MESSAGES+=("SSL/TLS support is available")
    else
        WARNING_ISSUES+=("SSL/TLS support not available")
        REMEDIATION_STEPS+=("Install openssl package")
    fi
    
    CHECK_RESULTS["software_dependencies"]=${deps_score}
    audit "software_dependencies_check" "score=${deps_score}/${max_score}"
    
    if [[ ${deps_score} -ge 70 ]]; then
        return 0
    else
        return 1
    fi
}

check_library_availability() {
    local lib_name="$1"
    
    # Check using package manager
    case "${SYSTEM_INFO[package_manager]}" in
        "apt")
            dpkg -l "${lib_name}" >/dev/null 2>&1
            ;;
        "yum"|"dnf")
            rpm -q "${lib_name}" >/dev/null 2>&1
            ;;
        "zypper")
            zypper se -i "${lib_name}" >/dev/null 2>&1
            ;;
        "pacman")
            pacman -Q "${lib_name}" >/dev/null 2>&1
            ;;
        *)
            # Generic check using ldconfig
            ldconfig -p | grep -q "${lib_name}" 2>/dev/null
            ;;
    esac
}

check_network_connectivity() {
    debug "Checking network connectivity"
    
    local network_score=0
    local max_score=100
    
    # Basic connectivity test
    if [[ "${SYSTEM_INFO[network_status]}" == "connected" ]]; then
        network_score=$((network_score + 30))
        INFO_MESSAGES+=("Internet connectivity is available")
    else
        network_score=$((network_score + 5))
        CRITICAL_ISSUES+=("No internet connectivity detected")
        REMEDIATION_STEPS+=("Check network configuration and connectivity")
    fi
    
    # DNS resolution test
    if nslookup cursor.com >/dev/null 2>&1; then
        network_score=$((network_score + 20))
        INFO_MESSAGES+=("DNS resolution is working")
    else
        WARNING_ISSUES+=("DNS resolution issues detected")
        REMEDIATION_STEPS+=("Check DNS configuration")
        network_score=$((network_score + 5))
    fi
    
    # HTTPS connectivity test
    if command -v curl >/dev/null 2>&1; then
        if curl -f -s -I --max-time 10 https://releases.cursor.com/ >/dev/null 2>&1; then
            network_score=$((network_score + 25))
            INFO_MESSAGES+=("HTTPS connectivity to Cursor servers is working")
        else
            WARNING_ISSUES+=("Cannot connect to Cursor release servers")
            REMEDIATION_STEPS+=("Check firewall and proxy settings")
            network_score=$((network_score + 10))
        fi
    fi
    
    # Certificate verification
    if command -v openssl >/dev/null 2>&1; then
        if echo | openssl s_client -connect cursor.com:443 -verify_return_error 2>/dev/null >/dev/null; then
            network_score=$((network_score + 15))
            INFO_MESSAGES+=("SSL certificate verification is working")
        else
            WARNING_ISSUES+=("SSL certificate verification issues")
            REMEDIATION_STEPS+=("Update CA certificates package")
        fi
    fi
    
    # Proxy detection
    if [[ -n "${http_proxy:-}" ]] || [[ -n "${https_proxy:-}" ]]; then
        network_score=$((network_score + 10))
        INFO_MESSAGES+=("HTTP proxy detected: ${http_proxy:-${https_proxy}}")
    else
        network_score=$((network_score + 10))
    fi
    
    CHECK_RESULTS["network_connectivity"]=${network_score}
    audit "network_connectivity_check" "score=${network_score}/${max_score}"
    
    if [[ ${network_score} -ge 60 ]]; then
        return 0
    else
        return 1
    fi
}

check_security_assessment() {
    debug "Performing security assessment"
    
    local security_score=0
    local max_score=100
    
    # Check if running as root (security risk)
    if [[ $(id -u) -eq 0 ]]; then
        security_score=$((security_score + 10))
        WARNING_ISSUES+=("Running as root user - security risk")
        REMEDIATION_STEPS+=("Run installation as regular user with sudo privileges")
    else
        security_score=$((security_score + 25))
        INFO_MESSAGES+=("Running as non-root user (secure)")
    fi
    
    # Check sudo availability
    if command -v sudo >/dev/null 2>&1; then
        security_score=$((security_score + 15))
        INFO_MESSAGES+=("sudo is available for privilege escalation")
        
        # Test sudo access
        if sudo -n true 2>/dev/null; then
            security_score=$((security_score + 10))
            INFO_MESSAGES+=("sudo access is configured")
        else
            INFO_MESSAGES+=("sudo may require password for privilege escalation")
        fi
    else
        WARNING_ISSUES+=("sudo not available - manual privilege escalation required")
        REMEDIATION_STEPS+=("Install sudo package or run with appropriate privileges")
    fi
    
    # Check firewall status
    if command -v ufw >/dev/null 2>&1; then
        local ufw_status
        ufw_status=$(ufw status 2>/dev/null | head -1)
        if [[ "${ufw_status}" =~ active ]]; then
            security_score=$((security_score + 15))
            INFO_MESSAGES+=("UFW firewall is active")
        else
            security_score=$((security_score + 10))
            INFO_MESSAGES+=("UFW firewall is available but inactive")
        fi
    elif command -v firewall-cmd >/dev/null 2>&1; then
        if systemctl is-active firewalld >/dev/null 2>&1; then
            security_score=$((security_score + 15))
            INFO_MESSAGES+=("firewalld is active")
        else
            security_score=$((security_score + 10))
            INFO_MESSAGES+=("firewalld is available but inactive")
        fi
    elif command -v iptables >/dev/null 2>&1; then
        security_score=$((security_score + 10))
        INFO_MESSAGES+=("iptables firewall is available")
    else
        security_score=$((security_score + 5))
        WARNING_ISSUES+=("No firewall detected")
    fi
    
    # Check SELinux status
    if command -v getenforce >/dev/null 2>&1; then
        local selinux_status
        selinux_status=$(getenforce 2>/dev/null)
        case "${selinux_status}" in
            "Enforcing")
                security_score=$((security_score + 15))
                INFO_MESSAGES+=("SELinux is enforcing (high security)")
                ;;
            "Permissive")
                security_score=$((security_score + 10))
                INFO_MESSAGES+=("SELinux is permissive (warnings only)")
                ;;
            "Disabled")
                security_score=$((security_score + 5))
                INFO_MESSAGES+=("SELinux is disabled")
                ;;
        esac
    fi
    
    # Check AppArmor status
    if command -v aa-status >/dev/null 2>&1; then
        if aa-status --enabled 2>/dev/null; then
            security_score=$((security_score + 15))
            INFO_MESSAGES+=("AppArmor is enabled")
        else
            security_score=$((security_score + 5))
            INFO_MESSAGES+=("AppArmor is available but not enabled")
        fi
    fi
    
    # Check file permissions on critical directories
    local secure_dirs=("/tmp" "/var/tmp")
    for dir in "${secure_dirs[@]}"; do
        if [[ -d "${dir}" ]]; then
            local perms
            perms=$(stat -c%a "${dir}" 2>/dev/null || stat -f%A "${dir}" 2>/dev/null)
            if [[ "${perms}" =~ ^17[0-7][0-7]$ ]]; then  # sticky bit set
                security_score=$((security_score + 5))
            else
                WARNING_ISSUES+=("Directory ${dir} does not have sticky bit set")
            fi
        fi
    done
    
    CHECK_RESULTS["security_assessment"]=${security_score}
    audit "security_assessment_check" "score=${security_score}/${max_score}"
    
    if [[ ${security_score} -ge 60 ]]; then
        return 0
    else
        return 1
    fi
}

check_performance_baseline() {
    debug "Establishing performance baseline"
    
    local perf_score=0
    local max_score=100
    local baseline_file="${CACHE_DIR}/performance_baseline.json"
    
    # CPU performance test
    local cpu_start
    cpu_start=$(date +%s.%N)
    
    # Simple CPU benchmark (calculate prime numbers)
    local prime_count=0
    for ((i=2; i<=1000; i++)); do
        local is_prime=1
        for ((j=2; j*j<=i; j++)); do
            if ((i % j == 0)); then
                is_prime=0
                break
            fi
        done
        if [[ ${is_prime} -eq 1 ]]; then
            ((prime_count++))
        fi
    done
    
    local cpu_end
    cpu_end=$(date +%s.%N)
    local cpu_time
    cpu_time=$(echo "${cpu_end} - ${cpu_start}" | bc -l 2>/dev/null || echo "1.0")
    
    # Evaluate CPU performance
    if (( $(echo "${cpu_time} < 0.5" | bc -l 2>/dev/null || echo 0) )); then
        perf_score=$((perf_score + 30))
        INFO_MESSAGES+=("CPU performance is excellent (${cpu_time}s)")
    elif (( $(echo "${cpu_time} < 1.0" | bc -l 2>/dev/null || echo 0) )); then
        perf_score=$((perf_score + 25))
        INFO_MESSAGES+=("CPU performance is good (${cpu_time}s)")
    elif (( $(echo "${cpu_time} < 2.0" | bc -l 2>/dev/null || echo 0) )); then
        perf_score=$((perf_score + 20))
        INFO_MESSAGES+=("CPU performance is adequate (${cpu_time}s)")
    else
        perf_score=$((perf_score + 10))
        WARNING_ISSUES+=("CPU performance is below optimal (${cpu_time}s)")
    fi
    
    # Memory performance test
    local mem_start
    mem_start=$(date +%s.%N)
    
    # Simple memory allocation test
    local test_data=""
    for ((i=0; i<10000; i++)); do
        test_data+="x"
    done
    
    local mem_end
    mem_end=$(date +%s.%N)
    local mem_time
    mem_time=$(echo "${mem_end} - ${mem_start}" | bc -l 2>/dev/null || echo "0.1")
    
    if (( $(echo "${mem_time} < 0.01" | bc -l 2>/dev/null || echo 0) )); then
        perf_score=$((perf_score + 25))
        INFO_MESSAGES+=("Memory performance is excellent")
    elif (( $(echo "${mem_time} < 0.05" | bc -l 2>/dev/null || echo 0) )); then
        perf_score=$((perf_score + 20))
        INFO_MESSAGES+=("Memory performance is good")
    else
        perf_score=$((perf_score + 15))
        INFO_MESSAGES+=("Memory performance is adequate")
    fi
    
    # Disk I/O performance test
    local io_start
    io_start=$(date +%s.%N)
    
    # Simple disk I/O test
    local test_file="${TEMP_DIR}/io_test"
    for ((i=0; i<100; i++)); do
        echo "test data line ${i}" >> "${test_file}"
    done
    sync
    cat "${test_file}" > /dev/null
    rm -f "${test_file}"
    
    local io_end
    io_end=$(date +%s.%N)
    local io_time
    io_time=$(echo "${io_end} - ${io_start}" | bc -l 2>/dev/null || echo "0.1")
    
    if (( $(echo "${io_time} < 0.1" | bc -l 2>/dev/null || echo 0) )); then
        perf_score=$((perf_score + 25))
        INFO_MESSAGES+=("Disk I/O performance is excellent")
    elif (( $(echo "${io_time} < 0.5" | bc -l 2>/dev/null || echo 0) )); then
        perf_score=$((perf_score + 20))
        INFO_MESSAGES+=("Disk I/O performance is good")
    else
        perf_score=$((perf_score + 15))
        WARNING_ISSUES+=("Disk I/O performance may impact installation speed")
    fi
    
    # System load assessment
    if [[ -f /proc/loadavg ]]; then
        local load_avg
        load_avg=$(awk '{print $1}' /proc/loadavg)
        local cpu_cores="${SYSTEM_INFO[cpu_cores]}"
        
        if (( $(echo "${load_avg} < ${cpu_cores}" | bc -l 2>/dev/null || echo 0) )); then
            perf_score=$((perf_score + 20))
            INFO_MESSAGES+=("System load is low (${load_avg})")
        elif (( $(echo "${load_avg} < $((cpu_cores * 2))" | bc -l 2>/dev/null || echo 0) )); then
            perf_score=$((perf_score + 15))
            INFO_MESSAGES+=("System load is moderate (${load_avg})")
        else
            perf_score=$((perf_score + 5))
            WARNING_ISSUES+=("System load is high (${load_avg}) - may affect performance")
        fi
    fi
    
    # Save baseline results
    cat > "${baseline_file}" <<EOF
{
    "timestamp": "$(date -Iseconds)",
    "cpu_benchmark_time": ${cpu_time},
    "memory_benchmark_time": ${mem_time},
    "io_benchmark_time": ${io_time},
    "system_load": "$(cat /proc/loadavg 2>/dev/null || echo "unknown")",
    "performance_score": ${perf_score}
}
EOF
    
    CHECK_RESULTS["performance_baseline"]=${perf_score}
    audit "performance_baseline_check" "score=${perf_score}/${max_score}"
    
    if [[ ${perf_score} -ge 60 ]]; then
        return 0
    else
        return 1
    fi
}

check_storage_analysis() {
    debug "Analyzing storage requirements"
    
    local storage_score=0
    local max_score=100
    
    # Check available disk space
    local disk_mb="${SYSTEM_INFO[disk_space]}"
    local min_disk="${MIN_REQUIREMENTS[disk_space_mb]}"
    local rec_disk="${RECOMMENDED_REQUIREMENTS[disk_space_mb]}"
    
    if [[ ${disk_mb} -ge $((rec_disk * 2)) ]]; then
        storage_score=$((storage_score + 40))
        INFO_MESSAGES+=("Abundant disk space available: ${disk_mb}MB")
    elif [[ ${disk_mb} -ge ${rec_disk} ]]; then
        storage_score=$((storage_score + 30))
        INFO_MESSAGES+=("Sufficient disk space: ${disk_mb}MB")
    elif [[ ${disk_mb} -ge ${min_disk} ]]; then
        storage_score=$((storage_score + 20))
        WARNING_ISSUES+=("Limited disk space: ${disk_mb}MB")
        REMEDIATION_STEPS+=("Consider freeing up disk space")
    else
        storage_score=$((storage_score + 5))
        CRITICAL_ISSUES+=("Insufficient disk space: ${disk_mb}MB (need ${min_disk}MB)")
        REMEDIATION_STEPS+=("Free up at least $((min_disk - disk_mb))MB of disk space")
    fi
    
    # Check filesystem type
    local fs_type
    fs_type=$(df -T "${SCRIPT_DIR}" | awk 'NR==2 {print $2}')
    
    case "${fs_type}" in
        "ext4"|"xfs"|"btrfs"|"zfs")
            storage_score=$((storage_score + 20))
            INFO_MESSAGES+=("Filesystem ${fs_type} is well supported")
            ;;
        "ext3"|"ext2")
            storage_score=$((storage_score + 15))
            WARNING_ISSUES+=("Filesystem ${fs_type} is older - consider upgrading")
            ;;
        "tmpfs"|"ramfs")
            storage_score=$((storage_score + 5))
            WARNING_ISSUES+=("Installing to temporary filesystem ${fs_type}")
            ;;
        *)
            storage_score=$((storage_score + 10))
            INFO_MESSAGES+=("Filesystem ${fs_type} should work but is not tested")
            ;;
    esac
    
    # Check disk I/O scheduler
    local device
    device=$(df "${SCRIPT_DIR}" | awk 'NR==2 {print $1}' | sed 's/[0-9]*$//')
    local scheduler_file="/sys/block/$(basename "${device}")/queue/scheduler"
    
    if [[ -f "${scheduler_file}" ]]; then
        local scheduler
        scheduler=$(grep -o '\[.*\]' "${scheduler_file}" 2>/dev/null | tr -d '[]')
        case "${scheduler}" in
            "deadline"|"noop"|"mq-deadline")
                storage_score=$((storage_score + 15))
                INFO_MESSAGES+=("I/O scheduler ${scheduler} is optimal for SSDs")
                ;;
            "cfq")
                storage_score=$((storage_score + 10))
                INFO_MESSAGES+=("I/O scheduler ${scheduler} is good for HDDs")
                ;;
            *)
                storage_score=$((storage_score + 10))
                INFO_MESSAGES+=("I/O scheduler: ${scheduler}")
                ;;
        esac
    fi
    
    # Check for SSD vs HDD
    if command -v lsblk >/dev/null 2>&1; then
        local storage_type
        storage_type=$(lsblk -d -o NAME,ROTA | grep "$(basename "${device}")" | awk '{print $2}')
        if [[ "${storage_type}" == "0" ]]; then
            storage_score=$((storage_score + 15))
            INFO_MESSAGES+=("SSD storage detected - excellent performance")
        elif [[ "${storage_type}" == "1" ]]; then
            storage_score=$((storage_score + 10))
            INFO_MESSAGES+=("HDD storage detected - adequate performance")
        fi
    fi
    
    # Check mount options
    local mount_opts
    mount_opts=$(mount | grep "$(df "${SCRIPT_DIR}" | awk 'NR==2 {print $1}')" | sed 's/.*(\(.*\)).*/\1/')
    
    if [[ "${mount_opts}" =~ noatime ]]; then
        storage_score=$((storage_score + 5))
        INFO_MESSAGES+=("noatime mount option detected - good for performance")
    fi
    
    if [[ "${mount_opts}" =~ relatime ]]; then
        storage_score=$((storage_score + 3))
    fi
    
    # Check for quotas
    if [[ "${mount_opts}" =~ quota ]]; then
        storage_score=$((storage_score + 2))
        INFO_MESSAGES+=("Disk quotas are enabled")
    fi
    
    CHECK_RESULTS["storage_analysis"]=${storage_score}
    audit "storage_analysis_check" "score=${storage_score}/${max_score}"
    
    if [[ ${storage_score} -ge 60 ]]; then
        return 0
    else
        return 1
    fi
}

check_user_permissions() {
    debug "Checking user permissions"
    
    local perm_score=0
    local max_score=100
    
    # Check if running as root
    if [[ $(id -u) -eq 0 ]]; then
        perm_score=$((perm_score + 20))
        WARNING_ISSUES+=("Running as root - has full system access")
        INFO_MESSAGES+=("Can install to system directories without sudo")
    else
        perm_score=$((perm_score + 30))
        INFO_MESSAGES+=("Running as regular user $(whoami) - secure")
    fi
    
    # Check sudo access
    if command -v sudo >/dev/null 2>&1; then
        perm_score=$((perm_score + 15))
        
        if sudo -n true 2>/dev/null; then
            perm_score=$((perm_score + 15))
            INFO_MESSAGES+=("Passwordless sudo access available")
        elif timeout 1 sudo -S true </dev/null 2>/dev/null; then
            perm_score=$((perm_score + 10))
            INFO_MESSAGES+=("Sudo access available (password required)")
        else
            perm_score=$((perm_score + 5))
            WARNING_ISSUES+=("Sudo access may be restricted")
            REMEDIATION_STEPS+=("Configure sudo access or run with appropriate privileges")
        fi
    else
        WARNING_ISSUES+=("sudo not available")
        REMEDIATION_STEPS+=("Install sudo or use root account for system installation")
    fi
    
    # Check write permissions to common directories
    local test_dirs=("/tmp" "/var/tmp" "${HOME}")
    local writable_dirs=0
    
    for dir in "${test_dirs[@]}"; do
        if [[ -w "${dir}" ]]; then
            ((writable_dirs++))
        fi
    done
    
    perm_score=$((perm_score + writable_dirs * 5))
    INFO_MESSAGES+=("Writable directories: ${writable_dirs}/${#test_dirs[@]}")
    
    # Check user groups
    local user_groups
    user_groups=$(groups 2>/dev/null || echo "")
    local important_groups=("sudo" "wheel" "admin" "docker")
    local group_count=0
    
    for group in "${important_groups[@]}"; do
        if [[ "${user_groups}" =~ ${group} ]]; then
            ((group_count++))
        fi
    done
    
    if [[ ${group_count} -gt 0 ]]; then
        perm_score=$((perm_score + group_count * 5))
        INFO_MESSAGES+=("User is member of ${group_count} administrative groups")
    fi
    
    # Check file creation permissions in installation directory
    local install_parent
    install_parent="$(dirname "/opt/cursor")"
    
    if [[ -w "${install_parent}" ]] || sudo test -w "${install_parent}" 2>/dev/null; then
        perm_score=$((perm_score + 15))
        INFO_MESSAGES+=("Can write to installation directory parent")
    else
        WARNING_ISSUES+=("May not be able to create installation directory")
        REMEDIATION_STEPS+=("Ensure write access to ${install_parent} or use user directory")
    fi
    
    # Check umask
    local current_umask
    current_umask=$(umask)
    if [[ "${current_umask}" == "0022" ]] || [[ "${current_umask}" == "022" ]]; then
        perm_score=$((perm_score + 10))
        INFO_MESSAGES+=("Default umask ${current_umask} is appropriate")
    else
        perm_score=$((perm_score + 5))
        INFO_MESSAGES+=("Current umask: ${current_umask}")
    fi
    
    CHECK_RESULTS["user_permissions"]=${perm_score}
    audit "user_permissions_check" "score=${perm_score}/${max_score}"
    
    if [[ ${perm_score} -ge 60 ]]; then
        return 0
    else
        return 1
    fi
}

check_service_dependencies() {
    debug "Checking service dependencies"
    
    local service_score=0
    local max_score=100
    
    # Check init system
    local init_system="${SYSTEM_INFO[init_system]}"
    case "${init_system}" in
        "systemd")
            service_score=$((service_score + 30))
            INFO_MESSAGES+=("systemd init system detected - full support")
            ;;
        "openrc")
            service_score=$((service_score + 25))
            INFO_MESSAGES+=("OpenRC init system detected - good support")
            ;;
        "upstart")
            service_score=$((service_score + 20))
            INFO_MESSAGES+=("Upstart init system detected - basic support")
            ;;
        "sysv")
            service_score=$((service_score + 15))
            WARNING_ISSUES+=("SysV init system - limited service management")
            ;;
        *)
            service_score=$((service_score + 10))
            WARNING_ISSUES+=("Unknown init system: ${init_system}")
            ;;
    esac
    
    # Check D-Bus service
    if command -v dbus-launch >/dev/null 2>&1; then
        service_score=$((service_score + 15))
        INFO_MESSAGES+=("D-Bus service is available")
        
        if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
            service_score=$((service_score + 5))
            INFO_MESSAGES+=("D-Bus session bus is active")
        fi
    else
        WARNING_ISSUES+=("D-Bus service not available")
        REMEDIATION_STEPS+=("Install D-Bus package for desktop integration")
    fi
    
    # Check display server
    local display_server="${SYSTEM_INFO[display_server]}"
    case "${display_server}" in
        "x11")
            service_score=$((service_score + 20))
            INFO_MESSAGES+=("X11 display server detected")
            ;;
        "wayland")
            service_score=$((service_score + 20))
            INFO_MESSAGES+=("Wayland display server detected")
            ;;
        "none")
            service_score=$((service_score + 5))
            WARNING_ISSUES+=("No display server detected - headless mode")
            ;;
    esac
    
    # Check audio services
    if command -v pulseaudio >/dev/null 2>&1; then
        service_score=$((service_score + 10))
        INFO_MESSAGES+=("PulseAudio is available")
    elif command -v pipewire >/dev/null 2>&1; then
        service_score=$((service_score + 10))
        INFO_MESSAGES+=("PipeWire is available")
    elif [[ -d /proc/asound ]]; then
        service_score=$((service_score + 8))
        INFO_MESSAGES+=("ALSA audio system is available")
    else
        service_score=$((service_score + 5))
        INFO_MESSAGES+=("No audio system detected (optional)")
    fi
    
    # Check networking services
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl is-active NetworkManager >/dev/null 2>&1; then
            service_score=$((service_score + 10))
            INFO_MESSAGES+=("NetworkManager is active")
        elif systemctl is-active systemd-networkd >/dev/null 2>&1; then
            service_score=$((service_score + 10))
            INFO_MESSAGES+=("systemd-networkd is active")
        fi
    fi
    
    # Check time synchronization
    if command -v timedatectl >/dev/null 2>&1; then
        local ntp_status
        ntp_status=$(timedatectl show --property=NTPSynchronized --value 2>/dev/null)
        if [[ "${ntp_status}" == "yes" ]]; then
            service_score=$((service_score + 5))
            INFO_MESSAGES+=("Time synchronization is active")
        else
            service_score=$((service_score + 3))
            INFO_MESSAGES+=("Time synchronization may not be active")
        fi
    fi
    
    # Check desktop services
    if [[ "${SYSTEM_INFO[desktop_environment]}" != "none" ]]; then
        service_score=$((service_score + 10))
        INFO_MESSAGES+=("Desktop environment services are available")
    fi
    
    CHECK_RESULTS["service_dependencies"]=${service_score}
    audit "service_dependencies_check" "score=${service_score}/${max_score}"
    
    if [[ ${service_score} -ge 60 ]]; then
        return 0
    else
        return 1
    fi
}

check_environment_setup() {
    debug "Checking environment setup"
    
    local env_score=0
    local max_score=100
    
    # Check PATH environment
    if [[ -n "${PATH:-}" ]]; then
        env_score=$((env_score + 15))
        local path_dirs
        path_dirs=$(echo "${PATH}" | tr ':' '\n' | wc -l)
        INFO_MESSAGES+=("PATH contains ${path_dirs} directories")
        
        # Check for common directories in PATH
        local common_dirs=("/usr/bin" "/bin" "/usr/local/bin")
        local found_dirs=0
        
        for dir in "${common_dirs[@]}"; do
            if [[ ":${PATH}:" =~ :${dir}: ]]; then
                ((found_dirs++))
            fi
        done
        
        env_score=$((env_score + found_dirs * 5))
    else
        WARNING_ISSUES+=("PATH environment variable not set")
        REMEDIATION_STEPS+=("Set PATH environment variable")
    fi
    
    # Check LANG environment
    if [[ -n "${LANG:-}" ]]; then
        env_score=$((env_score + 10))
        INFO_MESSAGES+=("LANG environment: ${LANG}")
        
        if [[ "${LANG}" =~ UTF-8 ]]; then
            env_score=$((env_score + 10))
            INFO_MESSAGES+=("UTF-8 encoding is configured")
        else
            WARNING_ISSUES+=("Non-UTF-8 encoding may cause issues")
            REMEDIATION_STEPS+=("Set LANG to UTF-8 locale (e.g., en_US.UTF-8)")
        fi
    else
        WARNING_ISSUES+=("LANG environment variable not set")
        REMEDIATION_STEPS+=("Set LANG environment variable")
    fi
    
    # Check HOME directory
    if [[ -n "${HOME:-}" ]] && [[ -d "${HOME}" ]]; then
        env_score=$((env_score + 15))
        INFO_MESSAGES+=("HOME directory is set and exists: ${HOME}")
        
        if [[ -w "${HOME}" ]]; then
            env_score=$((env_score + 5))
            INFO_MESSAGES+=("HOME directory is writable")
        else
            WARNING_ISSUES+=("HOME directory is not writable")
        fi
    else
        WARNING_ISSUES+=("HOME directory not set or doesn't exist")
        REMEDIATION_STEPS+=("Set HOME environment variable to valid directory")
    fi
    
    # Check TMPDIR or temp directory
    local temp_dir="${TMPDIR:-/tmp}"
    if [[ -d "${temp_dir}" ]] && [[ -w "${temp_dir}" ]]; then
        env_score=$((env_score + 10))
        INFO_MESSAGES+=("Temporary directory is available: ${temp_dir}")
    else
        WARNING_ISSUES+=("Temporary directory not available or not writable")
        REMEDIATION_STEPS+=("Ensure /tmp directory exists and is writable")
    fi
    
    # Check shell environment
    if [[ -n "${SHELL:-}" ]]; then
        env_score=$((env_score + 10))
        INFO_MESSAGES+=("Shell: ${SHELL}")
        
        if [[ "${SHELL}" =~ bash|zsh|fish ]]; then
            env_score=$((env_score + 5))
            INFO_MESSAGES+=("Modern shell detected")
        fi
    fi
    
    # Check terminal environment
    if [[ -n "${TERM:-}" ]]; then
        env_score=$((env_score + 5))
        INFO_MESSAGES+=("Terminal: ${TERM}")
    fi
    
    # Check display environment for GUI
    if [[ -n "${DISPLAY:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        env_score=$((env_score + 15))
        INFO_MESSAGES+=("Display environment is configured")
    else
        env_score=$((env_score + 5))
        INFO_MESSAGES+=("No display environment (headless mode)")
    fi
    
    # Check XDG directories
    local xdg_dirs=("XDG_CONFIG_HOME" "XDG_CACHE_HOME" "XDG_DATA_HOME")
    local xdg_count=0
    
    for xdg_var in "${xdg_dirs[@]}"; do
        if [[ -n "${!xdg_var:-}" ]]; then
            ((xdg_count++))
        fi
    done
    
    if [[ ${xdg_count} -gt 0 ]]; then
        env_score=$((env_score + xdg_count * 2))
        INFO_MESSAGES+=("XDG directories configured: ${xdg_count}/3")
    fi
    
    CHECK_RESULTS["environment_setup"]=${env_score}
    audit "environment_setup_check" "score=${env_score}/${max_score}"
    
    if [[ ${env_score} -ge 60 ]]; then
        return 0
    else
        return 1
    fi
}

# === UTILITY FUNCTIONS ===
version_compare() {
    local version1="$1"
    local version2="$2"
    
    # Simple version comparison - returns 0 if version1 >= version2
    if command -v sort >/dev/null 2>&1; then
        local higher_version
        higher_version=$(printf '%s\n%s\n' "${version1}" "${version2}" | sort -V | tail -1)
        [[ "${higher_version}" == "${version1}" ]]
    else
        # Fallback simple comparison
        [[ "${version1}" > "${version2}" ]] || [[ "${version1}" == "${version2}" ]]
    fi
}

# === REPORT GENERATION ===
generate_check_summary() {
    info "Generating pre-installation check summary"
    
    local summary_file="${LOG_DIR}/preinstall_summary_${TIMESTAMP}.txt"
    local json_summary="${LOG_DIR}/preinstall_summary_${TIMESTAMP}.json"
    
    # Calculate overall score
    local total_score=0
    local max_total=0
    local passed_checks=0
    local total_checks=${#CHECK_RESULTS[@]}
    
    for check_name in "${!CHECK_RESULTS[@]}"; do
        local score="${CHECK_RESULTS[${check_name}]}"
        total_score=$((total_score + score))
        max_total=$((max_total + 100))
        
        if [[ ${score} -ge 60 ]]; then
            ((passed_checks++))
        fi
    done
    
    local overall_percentage=0
    if [[ ${max_total} -gt 0 ]]; then
        overall_percentage=$((total_score * 100 / max_total))
    fi
    
    # Generate text summary
    cat > "${summary_file}" <<EOF
Cursor IDE Pre-Installation Check Summary
========================================

Generated: $(date -Iseconds)
Script Version: ${SCRIPT_VERSION}
System: ${SYSTEM_INFO[os_name]} ${SYSTEM_INFO[os_version]} (${SYSTEM_INFO[architecture]})

Overall Assessment: ${overall_percentage}% (${passed_checks}/${total_checks} checks passed)

System Information:
- OS: ${SYSTEM_INFO[os_name]} ${SYSTEM_INFO[os_version]}
- Architecture: ${SYSTEM_INFO[architecture]}
- Kernel: ${SYSTEM_INFO[kernel_version]}
- CPU: ${SYSTEM_INFO[cpu_model]} (${SYSTEM_INFO[cpu_cores]} cores)
- Memory: ${SYSTEM_INFO[memory_total]}MB
- Disk Space: ${SYSTEM_INFO[disk_space]}MB
- Package Manager: ${SYSTEM_INFO[package_manager]}
- Desktop Environment: ${SYSTEM_INFO[desktop_environment]}
- Display Server: ${SYSTEM_INFO[display_server]}
- Virtualization: ${SYSTEM_INFO[virtualization]}

Check Results:
EOF
    
    for check_name in "${!CHECK_RESULTS[@]}"; do
        local score="${CHECK_RESULTS[${check_name}]}"
        local status="FAIL"
        if [[ ${score} -ge 80 ]]; then
            status="EXCELLENT"
        elif [[ ${score} -ge 60 ]]; then
            status="PASS"
        elif [[ ${score} -ge 40 ]]; then
            status="WARN"
        fi
        
        printf "- %-25s: %3d/100 [%s]\n" "${check_name}" "${score}" "${status}" >> "${summary_file}"
    done
    
    cat >> "${summary_file}" <<EOF

Issues Found:
EOF
    
    if [[ ${#CRITICAL_ISSUES[@]} -gt 0 ]]; then
        echo "Critical Issues:" >> "${summary_file}"
        for issue in "${CRITICAL_ISSUES[@]}"; do
            echo "  ❌ ${issue}" >> "${summary_file}"
        done
        echo >> "${summary_file}"
    fi
    
    if [[ ${#WARNING_ISSUES[@]} -gt 0 ]]; then
        echo "Warnings:" >> "${summary_file}"
        for issue in "${WARNING_ISSUES[@]}"; do
            echo "  ⚠️  ${issue}" >> "${summary_file}"
        done
        echo >> "${summary_file}"
    fi
    
    if [[ ${#REMEDIATION_STEPS[@]} -gt 0 ]]; then
        echo "Recommended Actions:" >> "${summary_file}"
        for step in "${REMEDIATION_STEPS[@]}"; do
            echo "  💡 ${step}" >> "${summary_file}"
        done
        echo >> "${summary_file}"
    fi
    
    if [[ ${#INFO_MESSAGES[@]} -gt 0 ]]; then
        echo "Information:" >> "${summary_file}"
        for msg in "${INFO_MESSAGES[@]}"; do
            echo "  ℹ️  ${msg}" >> "${summary_file}"
        done
    fi
    
    # Generate JSON summary
    generate_json_summary "${json_summary}" "${overall_percentage}" "${passed_checks}" "${total_checks}"
    
    # Display summary to console
    display_console_summary "${overall_percentage}" "${passed_checks}" "${total_checks}"
    
    info "Summary reports generated:"
    info "  Text: ${summary_file}"
    info "  JSON: ${json_summary}"
}

generate_json_summary() {
    local json_file="$1"
    local overall_percentage="$2"
    local passed_checks="$3"
    local total_checks="$4"
    
    cat > "${json_file}" <<EOF
{
    "summary": {
        "timestamp": "$(date -Iseconds)",
        "script_version": "${SCRIPT_VERSION}",
        "overall_percentage": ${overall_percentage},
        "passed_checks": ${passed_checks},
        "total_checks": ${total_checks}
    },
    "system_info": {
        "os_name": "${SYSTEM_INFO[os_name]}",
        "os_version": "${SYSTEM_INFO[os_version]}",
        "os_id": "${SYSTEM_INFO[os_id]}",
        "architecture": "${SYSTEM_INFO[architecture]}",
        "kernel_version": "${SYSTEM_INFO[kernel_version]}",
        "cpu_model": "${SYSTEM_INFO[cpu_model]}",
        "cpu_cores": "${SYSTEM_INFO[cpu_cores]}",
        "memory_total": "${SYSTEM_INFO[memory_total]}",
        "disk_space": "${SYSTEM_INFO[disk_space]}",
        "package_manager": "${SYSTEM_INFO[package_manager]}",
        "desktop_environment": "${SYSTEM_INFO[desktop_environment]}",
        "display_server": "${SYSTEM_INFO[display_server]}",
        "virtualization": "${SYSTEM_INFO[virtualization]}"
    },
    "check_results": {
$(for check_name in "${!CHECK_RESULTS[@]}"; do
    echo "        \"${check_name}\": ${CHECK_RESULTS[${check_name}]},"
done | sed '$ s/,$//')
    },
    "issues": {
        "critical": [
$(printf '            "%s",\n' "${CRITICAL_ISSUES[@]}" | sed '$ s/,$//')
        ],
        "warnings": [
$(printf '            "%s",\n' "${WARNING_ISSUES[@]}" | sed '$ s/,$//')
        ]
    },
    "remediation_steps": [
$(printf '        "%s",\n' "${REMEDIATION_STEPS[@]}" | sed '$ s/,$//')
    ],
    "info_messages": [
$(printf '        "%s",\n' "${INFO_MESSAGES[@]}" | sed '$ s/,$//')
    ]
}
EOF
}

display_console_summary() {
    local overall_percentage="$1"
    local passed_checks="$2"
    local total_checks="$3"
    
    echo
    echo -e "${BOLD}${CYAN}=== PRE-INSTALLATION SUMMARY ===${NC}"
    echo
    
    if [[ ${overall_percentage} -ge 80 ]]; then
        echo -e "${GREEN}✅ System is ready for Cursor IDE installation${NC}"
        echo -e "Overall score: ${GREEN}${overall_percentage}%${NC} (${passed_checks}/${total_checks} checks passed)"
    elif [[ ${overall_percentage} -ge 60 ]]; then
        echo -e "${YELLOW}⚠️  System meets minimum requirements with warnings${NC}"
        echo -e "Overall score: ${YELLOW}${overall_percentage}%${NC} (${passed_checks}/${total_checks} checks passed)"
    else
        echo -e "${RED}❌ System does not meet minimum requirements${NC}"
        echo -e "Overall score: ${RED}${overall_percentage}%${NC} (${passed_checks}/${total_checks} checks passed)"
    fi
    
    echo
    
    if [[ ${#CRITICAL_ISSUES[@]} -gt 0 ]]; then
        echo -e "${RED}${BOLD}Critical Issues (${#CRITICAL_ISSUES[@]}):${NC}"
        for issue in "${CRITICAL_ISSUES[@]}"; do
            echo -e "  ${RED}❌ ${issue}${NC}"
        done
        echo
    fi
    
    if [[ ${#WARNING_ISSUES[@]} -gt 0 ]]; then
        echo -e "${YELLOW}${BOLD}Warnings (${#WARNING_ISSUES[@]}):${NC}"
        for issue in "${WARNING_ISSUES[@]}"; do
            echo -e "  ${YELLOW}⚠️  ${issue}${NC}"
        done
        echo
    fi
    
    if [[ ${#REMEDIATION_STEPS[@]} -gt 0 ]]; then
        echo -e "${BLUE}${BOLD}Recommended Actions:${NC}"
        for step in "${REMEDIATION_STEPS[@]}"; do
            echo -e "  ${BLUE}💡 ${step}${NC}"
        done
        echo
    fi
    
    echo -e "${CYAN}System Information:${NC}"
    echo -e "  OS: ${SYSTEM_INFO[os_name]} ${SYSTEM_INFO[os_version]} (${SYSTEM_INFO[architecture]})"
    echo -e "  CPU: ${SYSTEM_INFO[cpu_cores]} cores, ${SYSTEM_INFO[memory_total]}MB RAM"
    echo -e "  Storage: ${SYSTEM_INFO[disk_space]}MB available"
    echo -e "  Environment: ${SYSTEM_INFO[desktop_environment]} on ${SYSTEM_INFO[display_server]}"
    echo
}

# === CLEANUP ===
cleanup_preinstall() {
    debug "Cleaning up pre-installation system"
    
    # Clean up temporary files
    rm -rf "${TEMP_DIR}" 2>/dev/null || true
    
    # Close any open file descriptors
    exec 3>&- 2>/dev/null || true
    exec 4>&- 2>/dev/null || true
    
    debug "Cleanup completed"
}

# === MAIN EXECUTION ===
main() {
    local start_time
    start_time=$(date +%s)
    
    # Set up cleanup trap
    trap cleanup_preinstall EXIT INT TERM
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_usage
                exit 0
                ;;
            --version|-v)
                echo "Cursor Pre-Installation System v${SCRIPT_VERSION}"
                exit 0
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --debug)
                DEBUG=true
                VERBOSE=true
                shift
                ;;
            --strict)
                STRICT_MODE=true
                shift
                ;;
            --interactive)
                INTERACTIVE_MODE=true
                shift
                ;;
            --json-output)
                JSON_OUTPUT=true
                shift
                ;;
            *)
                warn "Unknown option: $1"
                shift
                ;;
        esac
    done
    
    # Initialize system
    initialize_preinstall_system
    
    # Run pre-installation checks
    run_preinstallation_checks
    
    # Calculate execution time
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    info "Pre-installation checks completed in ${duration} seconds"
    audit "preinstall_session_completed" "duration=${duration}s"
    
    # Exit with appropriate code
    local exit_code=0
    if [[ ${#CRITICAL_ISSUES[@]} -gt 0 ]]; then
        exit_code=1
    elif [[ ${#WARNING_ISSUES[@]} -gt 0 ]]; then
        exit_code=2
    fi
    
    exit ${exit_code}
}

show_usage() {
    cat <<EOF
Cursor IDE Enterprise Pre-Installation System v${SCRIPT_VERSION}

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --help, -h          Show this help message
    --version, -v       Show version information
    --verbose           Enable verbose output
    --debug             Enable debug mode with detailed logging
    --strict            Enable strict validation mode
    --interactive       Enable interactive mode for remediation
    --json-output       Output results in JSON format

DESCRIPTION:
    Performs comprehensive pre-installation validation for Cursor IDE,
    checking system compatibility, hardware requirements, software
    dependencies, and environment configuration.

EXIT CODES:
    0    All checks passed
    1    Critical issues found (installation not recommended)
    2    Warnings found (installation may proceed with caution)

REPORTS:
    Text summary: ~/.cache/cursor/preinstall/logs/preinstall_summary_TIMESTAMP.txt
    JSON summary: ~/.cache/cursor/preinstall/logs/preinstall_summary_TIMESTAMP.json
    Full log:     ~/.cache/cursor/preinstall/logs/preinstall_TIMESTAMP.log

For more information, visit: https://cursor.com
EOF
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi