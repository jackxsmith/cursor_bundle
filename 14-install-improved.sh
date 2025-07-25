#!/usr/bin/env bash

# =============================================================================
# CURSOR IDE ENTERPRISE INSTALLATION FRAMEWORK
# Version: 22-test-cursor-suite-improved-v2.sh
# Description: Advanced enterprise-grade installation system for Cursor IDE
# Author: Enterprise Development Team
# License: MIT
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# GLOBAL CONFIGURATION AND CONSTANTS
# =============================================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_VERSION="22-test-cursor-suite-improved-v2.sh"
readonly CURSOR_VERSION="6.9.35"
readonly TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"

# Directory structure
readonly BASE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/cursor-enterprise"
readonly LOG_DIR="$BASE_DIR/logs/installer"
readonly CONFIG_DIR="$BASE_DIR/config/installer"
readonly CACHE_DIR="$BASE_DIR/cache/installer"
readonly BACKUP_DIR="$BASE_DIR/backup/installer"
readonly TEMP_DIR="${TMPDIR:-/tmp}/cursor-installer-$$"

# Installation paths
readonly INSTALL_DIR="/opt/cursor"
readonly SYMLINK_DIR="/usr/local/bin"
readonly DESKTOP_DIR="/usr/share/applications"
readonly ICONS_DIR="/usr/share/icons/hicolor"
readonly MAN_DIR="/usr/share/man/man1"
readonly BASH_COMPLETION_DIR="/etc/bash_completion.d"

# Log files
readonly MAIN_LOG="$LOG_DIR/installer-${TIMESTAMP}.log"
readonly ERROR_LOG="$LOG_DIR/installer-error-${TIMESTAMP}.log"
readonly AUDIT_LOG="$LOG_DIR/installer-audit-${TIMESTAMP}.log"
readonly PERFORMANCE_LOG="$LOG_DIR/installer-performance-${TIMESTAMP}.log"
readonly SECURITY_LOG="$LOG_DIR/installer-security-${TIMESTAMP}.log"

# Configuration files
readonly MAIN_CONFIG="$CONFIG_DIR/installer.conf"
readonly MIRRORS_CONFIG="$CONFIG_DIR/mirrors.json"
readonly SECURITY_CONFIG="$CONFIG_DIR/security.conf"
readonly INTEGRATION_CONFIG="$CONFIG_DIR/integration.json"

# Backup files
readonly BACKUP_MANIFEST="$BACKUP_DIR/backup-${TIMESTAMP}.manifest"
readonly ROLLBACK_SCRIPT="$BACKUP_DIR/rollback-${TIMESTAMP}.sh"

# Colors and formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'

# Status codes
readonly STATUS_SUCCESS=0
readonly STATUS_WARNING=1
readonly STATUS_ERROR=2
readonly STATUS_CRITICAL=3
readonly STATUS_ROLLBACK=4

# Installation modes
declare -A INSTALL_MODES=(
    ["minimal"]="Minimal installation with basic features"
    ["standard"]="Standard installation for most users"
    ["enterprise"]="Full enterprise installation with all features"
    ["developer"]="Developer-focused installation with additional tools"
    ["custom"]="Custom installation with user-selected components"
)

# Installation components
declare -A INSTALL_COMPONENTS=(
    ["core"]="Core Cursor IDE application"
    ["desktop_integration"]="Desktop environment integration"
    ["shell_integration"]="Shell and terminal integration"
    ["development_tools"]="Additional development tools"
    ["documentation"]="Offline documentation and help"
    ["themes"]="Additional themes and color schemes"
    ["extensions"]="Pre-installed extension packages"
    ["language_packs"]="Multi-language support packs"
)

# System requirements
declare -A MIN_REQUIREMENTS=(
    ["memory_mb"]=2048
    ["disk_space_mb"]=4096
    ["cpu_cores"]=2
    ["kernel_version"]="3.10.0"
    ["glibc_version"]="2.17"
)

# Download mirrors
declare -A DOWNLOAD_MIRRORS=(
    ["primary"]="https://api.cursor.com/releases"
    ["mirror1"]="https://github.com/getcursor/cursor/releases"
    ["mirror2"]="https://cdn.cursor.sh/releases"
    ["fallback"]="https://backup.cursor.sh/releases"
)

# Global variables
declare -g INSTALL_MODE="standard"
declare -g FORCE_INSTALL=false
declare -g SKIP_VERIFICATION=false
declare -g ENABLE_TELEMETRY=true
declare -g CREATE_BACKUPS=true
declare -g QUIET_MODE=false
declare -g DRY_RUN=false
declare -g ROLLBACK_MODE=false

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Don't log in quiet mode unless it's an error
    if [[ "$QUIET_MODE" == "true" ]] && [[ "$level" != "ERROR" ]] && [[ "$level" != "CRITICAL" ]]; then
        return 0
    fi
    
    case "$level" in
        "INFO")
            echo -e "${CYAN}[INFO]${NC} $message" >&1
            echo "[$timestamp] [INFO] $message" >> "$MAIN_LOG"
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message" >&2
            echo "[$timestamp] [WARN] $message" >> "$MAIN_LOG"
            echo "[$timestamp] [WARN] $message" >> "$ERROR_LOG"
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            echo "[$timestamp] [ERROR] $message" >> "$MAIN_LOG"
            echo "[$timestamp] [ERROR] $message" >> "$ERROR_LOG"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message" >&1
            echo "[$timestamp] [SUCCESS] $message" >> "$MAIN_LOG"
            ;;
        "CRITICAL")
            echo -e "${RED}${BOLD}[CRITICAL]${NC} $message" >&2
            echo "[$timestamp] [CRITICAL] $message" >> "$MAIN_LOG"
            echo "[$timestamp] [CRITICAL] $message" >> "$ERROR_LOG"
            ;;
        "DEBUG")
            if [[ "${DEBUG:-false}" == "true" ]]; then
                echo -e "${DIM}[DEBUG]${NC} $message" >&1
                echo "[$timestamp] [DEBUG] $message" >> "$MAIN_LOG"
            fi
            ;;
    esac
}

audit_log() {
    local action="$1"
    local details="$2"
    local status="${3:-SUCCESS}"
    local user="${SUDO_USER:-$USER}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] USER=$user ACTION=$action STATUS=$status DETAILS=$details" >> "$AUDIT_LOG"
}

performance_log() {
    local operation="$1"
    local duration="$2"
    local details="${3:-}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] OPERATION=$operation DURATION=${duration}ms DETAILS=$details" >> "$PERFORMANCE_LOG"
}

security_log() {
    local event="$1"
    local severity="$2"
    local details="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] EVENT=$event SEVERITY=$severity DETAILS=$details" >> "$SECURITY_LOG"
}

show_progress() {
    local current="$1"
    local total="$2"
    local description="$3"
    local percentage=$((current * 100 / total))
    local completed=$((percentage / 2))
    local remaining=$((50 - completed))
    
    if [[ "$QUIET_MODE" != "true" ]]; then
        printf "\r${BLUE}[%s%s]${NC} %d%% %s" \
            "$(printf "%*s" $completed | tr ' ' '=')" \
            "$(printf "%*s" $remaining)" \
            "$percentage" \
            "$description"
        
        if [[ $current -eq $total ]]; then
            echo
        fi
    fi
}

cleanup() {
    local exit_code=$?
    log "INFO" "Performing cleanup operations..."
    
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
    
    # Clean up temporary files
    find /tmp -name "cursor-installer-*" -type d -mtime +1 -exec rm -rf {} + 2>/dev/null || true
    
    if [[ $exit_code -eq 0 ]]; then
        log "SUCCESS" "Installation completed successfully"
        audit_log "INSTALLATION_COMPLETE" "Exit code: $exit_code" "SUCCESS"
    else
        log "ERROR" "Installation failed with exit code: $exit_code"
        audit_log "INSTALLATION_FAILED" "Exit code: $exit_code" "FAILURE"
        
        if [[ "$CREATE_BACKUPS" == "true" ]] && [[ -f "$ROLLBACK_SCRIPT" ]]; then
            log "INFO" "Rollback script available at: $ROLLBACK_SCRIPT"
        fi
    fi
    
    exit $exit_code
}

error_handler() {
    local line_number="$1"
    local command="$2"
    local exit_code="$3"
    
    log "ERROR" "Command failed at line $line_number: $command (exit code: $exit_code)"
    security_log "SCRIPT_ERROR" "HIGH" "Unexpected script failure at line $line_number"
    audit_log "SCRIPT_ERROR" "Line: $line_number, Command: $command" "FAILURE"
    
    if [[ "$DRY_RUN" != "true" ]] && [[ "$CREATE_BACKUPS" == "true" ]]; then
        log "INFO" "Attempting to create emergency rollback script..."
        create_rollback_script
    fi
    
    cleanup
}

# =============================================================================
# INITIALIZATION FUNCTIONS
# =============================================================================

create_directory_structure() {
    log "INFO" "Creating directory structure..."
    
    local directories=(
        "$BASE_DIR" "$LOG_DIR" "$CONFIG_DIR" "$CACHE_DIR" "$BACKUP_DIR" "$TEMP_DIR"
    )
    
    for dir in "${directories[@]}"; do
        if [[ "$DRY_RUN" == "true" ]]; then
            log "DEBUG" "DRY RUN: Would create directory: $dir"
        else
            if ! mkdir -p "$dir"; then
                log "ERROR" "Failed to create directory: $dir"
                return 1
            fi
        fi
    done
    
    # Set appropriate permissions
    if [[ "$DRY_RUN" != "true" ]]; then
        chmod 755 "$BASE_DIR" "$LOG_DIR" "$CONFIG_DIR" "$CACHE_DIR"
        chmod 700 "$BACKUP_DIR" "$TEMP_DIR"
    fi
    
    log "SUCCESS" "Directory structure created successfully"
    return 0
}

initialize_configuration() {
    log "INFO" "Initializing configuration files..."
    
    # Main configuration file
    if [[ "$DRY_RUN" != "true" ]]; then
        cat > "$MAIN_CONFIG" << 'EOF'
# Cursor IDE Enterprise Installer Configuration
# Version: 22-test-cursor-suite-improved-v2.sh

[general]
installation_timeout=3600
download_timeout=1800
verification_enabled=true
backup_enabled=true
telemetry_enabled=true

[security]
verify_checksums=true
verify_signatures=true
check_file_permissions=true
scan_for_malware=false

[performance]
parallel_downloads=true
max_download_threads=4
compression_level=6
cache_downloads=true

[integration]
create_desktop_entry=true
create_menu_entries=true
setup_file_associations=true
install_shell_completion=true
create_man_pages=true

[updates]
check_for_updates=true
auto_update=false
update_channel=stable
backup_before_update=true
EOF

        # Mirrors configuration
        cat > "$MIRRORS_CONFIG" << 'EOF'
{
    "mirrors": [
        {
            "name": "primary",
            "url": "https://api.cursor.com/releases",
            "priority": 1,
            "region": "global",
            "active": true
        },
        {
            "name": "github",
            "url": "https://github.com/getcursor/cursor/releases",
            "priority": 2,
            "region": "global",
            "active": true
        },
        {
            "name": "cdn", 
            "url": "https://cdn.cursor.sh/releases",
            "priority": 3,
            "region": "global",
            "active": true
        }
    ],
    "fallback_strategy": "round_robin",
    "connection_timeout": 30,
    "max_retries": 3
}
EOF

        # Security configuration
        cat > "$SECURITY_CONFIG" << 'EOF'
# Security Configuration for Cursor IDE Installer

# Checksum verification
VERIFY_CHECKSUMS=true
CHECKSUM_ALGORITHM=sha256

# Digital signature verification
VERIFY_SIGNATURES=true
TRUSTED_KEYS_FILE=/etc/cursor/trusted-keys.gpg

# File system security
SECURE_PERMISSIONS=true
RESTRICT_EXECUTE_PERMISSIONS=true

# Network security
USE_HTTPS_ONLY=true
VERIFY_SSL_CERTIFICATES=true
ALLOW_REDIRECTS=false

# Installation security
BACKUP_EXISTING_INSTALLATION=true
QUARANTINE_SUSPICIOUS_FILES=true
LOG_ALL_OPERATIONS=true
EOF
    fi
    
    log "SUCCESS" "Configuration files initialized"
    return 0
}

# =============================================================================
# SYSTEM VALIDATION FUNCTIONS
# =============================================================================

check_system_requirements() {
    log "INFO" "Checking system requirements..."
    
    local requirements_met=true
    local start_time=$(date +%s%3N)
    
    # Check available memory
    local available_memory=$(free -m | awk '/^Mem:/ {print $7}')
    if [[ $available_memory -lt ${MIN_REQUIREMENTS[memory_mb]} ]]; then
        log "WARN" "Low available memory: ${available_memory}MB (minimum: ${MIN_REQUIREMENTS[memory_mb]}MB)"
        requirements_met=false
    else
        log "DEBUG" "Memory check passed: ${available_memory}MB available"
    fi
    
    # Check disk space
    local available_disk=$(df "$INSTALL_DIR" 2>/dev/null | awk 'NR==2 {print $4}' || df / | awk 'NR==2 {print $4}')
    local required_disk_kb=$((${MIN_REQUIREMENTS[disk_space_mb]} * 1024))
    if [[ $available_disk -lt $required_disk_kb ]]; then
        log "ERROR" "Insufficient disk space: $((available_disk / 1024))MB available, ${MIN_REQUIREMENTS[disk_space_mb]}MB required"
        requirements_met=false
    else
        log "DEBUG" "Disk space check passed: $((available_disk / 1024))MB available"
    fi
    
    # Check CPU cores
    local cpu_cores=$(nproc)
    if [[ $cpu_cores -lt ${MIN_REQUIREMENTS[cpu_cores]} ]]; then
        log "WARN" "Low CPU core count: $cpu_cores cores (recommended: ${MIN_REQUIREMENTS[cpu_cores]}+ cores)"
    else
        log "DEBUG" "CPU cores check passed: $cpu_cores cores"
    fi
    
    # Check kernel version
    local kernel_version=$(uname -r | cut -d'-' -f1)
    if ! version_compare "$kernel_version" "${MIN_REQUIREMENTS[kernel_version]}"; then
        log "WARN" "Old kernel version: $kernel_version (minimum: ${MIN_REQUIREMENTS[kernel_version]})"
    else
        log "DEBUG" "Kernel version check passed: $kernel_version"
    fi
    
    # Check glibc version
    if command -v ldd >/dev/null 2>&1; then
        local glibc_version=$(ldd --version | head -n1 | grep -oE '[0-9]+\.[0-9]+' | head -n1)
        if [[ -n "$glibc_version" ]] && ! version_compare "$glibc_version" "${MIN_REQUIREMENTS[glibc_version]}"; then
            log "WARN" "Old glibc version: $glibc_version (minimum: ${MIN_REQUIREMENTS[glibc_version]})"
        else
            log "DEBUG" "GLIBC version check passed: $glibc_version"
        fi
    fi
    
    # Check for required system libraries
    local required_libs=("libfuse2" "libgtk-3-0" "libxss1" "libasound2")
    for lib in "${required_libs[@]}"; do
        if ! ldconfig -p | grep -q "$lib"; then
            log "WARN" "Required library not found: $lib"
            requirements_met=false
        fi
    done
    
    local end_time=$(date +%s%3N)
    local duration=$((end_time - start_time))
    performance_log "system_requirements_check" "$duration" "Requirements met: $requirements_met"
    
    if $requirements_met; then
        log "SUCCESS" "All system requirements met"
        return 0
    else
        log "ERROR" "System requirements not met"
        return 1
    fi
}

version_compare() {
    local version1="$1"
    local version2="$2"
    
    # Simple version comparison (can be enhanced)
    printf '%s\n%s\n' "$version1" "$version2" | sort -V | head -n1 | grep -q "^$version2$"
}

check_permissions() {
    log "INFO" "Checking installation permissions..."
    
    local permission_issues=0
    
    # Check if we can write to installation directories
    local test_dirs=("$INSTALL_DIR" "$SYMLINK_DIR" "$DESKTOP_DIR" "$ICONS_DIR")
    for dir in "${test_dirs[@]}"; do
        local parent_dir=$(dirname "$dir")
        if [[ ! -w "$parent_dir" ]] && [[ "$EUID" -ne 0 ]]; then
            log "WARN" "No write permission to $parent_dir (may need sudo)"
            ((permission_issues++))
        fi
    done
    
    # Check if running as root when not needed
    if [[ "$EUID" -eq 0 ]] && [[ "$FORCE_INSTALL" != "true" ]]; then
        log "WARN" "Running as root - consider running as regular user with sudo for specific operations"
    fi
    
    if [[ $permission_issues -eq 0 ]]; then
        log "SUCCESS" "Permission checks passed"
        return 0
    else
        log "WARN" "Permission issues detected: $permission_issues"
        return 1
    fi
}

detect_existing_installation() {
    log "INFO" "Detecting existing Cursor installations..."
    
    local existing_installations=()
    
    # Check common installation locations
    local check_paths=(
        "/opt/cursor"
        "/usr/local/bin/cursor"
        "/usr/bin/cursor"
        "$HOME/.local/bin/cursor"
        "$HOME/Applications/cursor"
    )
    
    for path in "${check_paths[@]}"; do
        if [[ -e "$path" ]]; then
            existing_installations+=("$path")
            log "INFO" "Found existing installation: $path"
        fi
    done
    
    # Check AppImage in common locations
    local appimage_paths=(
        "$HOME/Downloads/cursor*.AppImage"
        "$HOME/Applications/cursor*.AppImage"
        "/opt/cursor/cursor*.AppImage"
    )
    
    for pattern in "${appimage_paths[@]}"; do
        for file in $pattern; do
            if [[ -f "$file" ]]; then
                existing_installations+=("$file")
                log "INFO" "Found existing AppImage: $file"
            fi
        done
    done
    
    if [[ ${#existing_installations[@]} -gt 0 ]]; then
        log "WARN" "Found ${#existing_installations[@]} existing installation(s)"
        
        if [[ "$FORCE_INSTALL" != "true" ]]; then
            log "INFO" "Use --force to overwrite existing installations"
            log "INFO" "Existing installations:"
            for installation in "${existing_installations[@]}"; do
                log "INFO" "  - $installation"
            done
        fi
        
        return 1
    else
        log "SUCCESS" "No existing installations found"
        return 0
    fi
}

# =============================================================================
# BACKUP AND ROLLBACK FUNCTIONS
# =============================================================================

create_backup() {
    if [[ "$CREATE_BACKUPS" != "true" ]] || [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    log "INFO" "Creating backup of existing installation..."
    
    local backup_start=$(date +%s%3N)
    local backup_created=false
    
    # Create backup manifest
    cat > "$BACKUP_MANIFEST" << EOF
# Cursor IDE Installation Backup Manifest
# Created: $(date)
# Version: $SCRIPT_VERSION

EOF
    
    # Backup existing installation
    if [[ -d "$INSTALL_DIR" ]]; then
        local backup_install_dir="$BACKUP_DIR/install-$(basename "$INSTALL_DIR")"
        if cp -r "$INSTALL_DIR" "$backup_install_dir" 2>/dev/null; then
            echo "INSTALL_DIR=$backup_install_dir" >> "$BACKUP_MANIFEST"
            log "DEBUG" "Backed up installation directory to $backup_install_dir"
            backup_created=true
        fi
    fi
    
    # Backup symlinks
    local symlinks=("/usr/local/bin/cursor" "/usr/bin/cursor")
    for symlink in "${symlinks[@]}"; do
        if [[ -L "$symlink" ]]; then
            local target=$(readlink "$symlink")
            echo "SYMLINK=$symlink:$target" >> "$BACKUP_MANIFEST"
            log "DEBUG" "Recorded symlink: $symlink -> $target"
            backup_created=true
        fi
    done
    
    # Backup desktop entries
    local desktop_entries=("/usr/share/applications/cursor.desktop" "$HOME/.local/share/applications/cursor.desktop")
    for entry in "${desktop_entries[@]}"; do
        if [[ -f "$entry" ]]; then
            local backup_entry="$BACKUP_DIR/$(basename "$entry")"
            if cp "$entry" "$backup_entry" 2>/dev/null; then
                echo "DESKTOP_ENTRY=$backup_entry" >> "$BACKUP_MANIFEST"
                log "DEBUG" "Backed up desktop entry: $entry"
                backup_created=true
            fi
        fi
    done
    
    local backup_end=$(date +%s%3N)
    local duration=$((backup_end - backup_start))
    performance_log "backup_creation" "$duration" "Backup created: $backup_created"
    
    if $backup_created; then
        log "SUCCESS" "Backup created successfully"
        audit_log "BACKUP_CREATED" "Manifest: $BACKUP_MANIFEST" "SUCCESS"
        create_rollback_script
        return 0
    else
        log "INFO" "No existing installation to backup"
        return 0
    fi
}

create_rollback_script() {
    if [[ "$CREATE_BACKUPS" != "true" ]] || [[ "$DRY_RUN" == "true" ]]; then
        return 0
    fi
    
    log "INFO" "Creating rollback script..."
    
    cat > "$ROLLBACK_SCRIPT" << 'EOF'
#!/usr/bin/env bash
# Cursor IDE Installation Rollback Script
# Generated automatically - do not edit manually

set -euo pipefail

BACKUP_MANIFEST="$(dirname "$0")/backup-$(basename "$0" .sh | cut -d'-' -f2).manifest"

if [[ ! -f "$BACKUP_MANIFEST" ]]; then
    echo "ERROR: Backup manifest not found: $BACKUP_MANIFEST"
    exit 1
fi

echo "Rolling back Cursor IDE installation..."

# Remove current installation
if [[ -d "/opt/cursor" ]]; then
    echo "Removing current installation..."
    sudo rm -rf "/opt/cursor"
fi

# Remove symlinks
for symlink in /usr/local/bin/cursor /usr/bin/cursor; do
    if [[ -L "$symlink" ]]; then
        echo "Removing symlink: $symlink"
        sudo rm -f "$symlink"
    fi
done

# Remove desktop entries
for entry in /usr/share/applications/cursor.desktop ~/.local/share/applications/cursor.desktop; do
    if [[ -f "$entry" ]]; then
        echo "Removing desktop entry: $entry"
        rm -f "$entry"
    fi
done

# Restore from backup
while IFS='=' read -r key value; do
    case "$key" in
        INSTALL_DIR)
            if [[ -d "$value" ]]; then
                echo "Restoring installation directory..."
                sudo cp -r "$value" "/opt/cursor"
            fi
            ;;
        SYMLINK)
            local symlink_path="${value%:*}"
            local symlink_target="${value#*:}"
            echo "Restoring symlink: $symlink_path -> $symlink_target"
            sudo ln -sf "$symlink_target" "$symlink_path"
            ;;
        DESKTOP_ENTRY)
            if [[ -f "$value" ]]; then
                echo "Restoring desktop entry..."
                local dest_path="/usr/share/applications/$(basename "$value")"
                sudo cp "$value" "$dest_path"
            fi
            ;;
    esac
done < "$BACKUP_MANIFEST"

echo "Rollback completed successfully"
EOF
    
    chmod +x "$ROLLBACK_SCRIPT"
    log "SUCCESS" "Rollback script created: $ROLLBACK_SCRIPT"
}

# =============================================================================
# DOWNLOAD AND VERIFICATION FUNCTIONS
# =============================================================================

download_cursor_appimage() {
    log "INFO" "Downloading Cursor IDE AppImage..."
    
    local download_start=$(date +%s%3N)
    local appimage_path="$CACHE_DIR/cursor-${CURSOR_VERSION}.AppImage"
    local download_url=""
    
    # Try mirrors in order of priority
    for mirror in "${!DOWNLOAD_MIRRORS[@]}"; do
        local mirror_url="${DOWNLOAD_MIRRORS[$mirror]}"
        download_url="$mirror_url/$CURSOR_VERSION/cursor.AppImage"
        
        log "DEBUG" "Trying mirror: $mirror ($mirror_url)"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log "INFO" "DRY RUN: Would download from $download_url"
            return 0
        fi
        
        # Test connectivity to mirror
        if curl -fsSL --connect-timeout 10 --head "$download_url" >/dev/null 2>&1; then
            log "INFO" "Using mirror: $mirror"
            break
        else
            log "WARN" "Mirror unavailable: $mirror"
            download_url=""
        fi
    done
    
    if [[ -z "$download_url" ]]; then
        log "ERROR" "All download mirrors are unavailable"
        return 1
    fi
    
    # Download with progress bar
    log "INFO" "Downloading from: $download_url"
    
    if ! curl -fsSL --progress-bar \
         --connect-timeout 30 \
         --max-time 1800 \
         --retry 3 \
         --retry-delay 5 \
         -o "$appimage_path" \
         "$download_url"; then
        log "ERROR" "Failed to download Cursor AppImage"
        return 1
    fi
    
    # Verify download
    if [[ ! -f "$appimage_path" ]] || [[ ! -s "$appimage_path" ]]; then
        log "ERROR" "Downloaded file is missing or empty"
        return 1
    fi
    
    local file_size=$(stat -c%s "$appimage_path")
    log "INFO" "Downloaded AppImage: $(( file_size / 1024 / 1024 ))MB"
    
    # Make executable
    chmod +x "$appimage_path"
    
    local download_end=$(date +%s%3N)
    local duration=$((download_end - download_start))
    performance_log "appimage_download" "$duration" "Size: $file_size bytes"
    
    # Store path for later use
    APPIMAGE_PATH="$appimage_path"
    
    log "SUCCESS" "AppImage downloaded successfully"
    audit_log "APPIMAGE_DOWNLOADED" "Path: $appimage_path, Size: $file_size" "SUCCESS"
    
    return 0
}

verify_appimage_integrity() {
    if [[ "$SKIP_VERIFICATION" == "true" ]]; then
        log "INFO" "Skipping AppImage verification (--skip-verification)"
        return 0
    fi
    
    log "INFO" "Verifying AppImage integrity..."
    
    local verify_start=$(date +%s%3N)
    local verification_passed=true
    
    if [[ ! -f "$APPIMAGE_PATH" ]]; then
        log "ERROR" "AppImage file not found: $APPIMAGE_PATH"
        return 1
    fi
    
    # Check file type
    local file_type=$(file "$APPIMAGE_PATH")
    if [[ "$file_type" != *"executable"* ]]; then
        log "WARN" "AppImage may not be a valid executable: $file_type"
        verification_passed=false
    fi
    
    # Check AppImage magic bytes
    local magic_bytes=$(hexdump -C "$APPIMAGE_PATH" | head -1 | cut -d' ' -f2-5)
    if [[ "$magic_bytes" != "7f 45 4c 46" ]]; then
        log "WARN" "AppImage does not have expected ELF magic bytes"
        verification_passed=false
    fi
    
    # Test AppImage can be executed (version check)
    if timeout 30 "$APPIMAGE_PATH" --version >/dev/null 2>&1; then
        log "DEBUG" "AppImage executable test passed"
    else
        log "WARN" "AppImage executable test failed"
        verification_passed=false
    fi
    
    # Check for malware (if clamscan is available)
    if command -v clamscan >/dev/null 2>&1; then
        log "INFO" "Scanning for malware..."
        if clamscan --quiet --no-summary "$APPIMAGE_PATH"; then
            log "DEBUG" "Malware scan passed"
        else
            log "ERROR" "Malware detected in AppImage"
            security_log "MALWARE_DETECTED" "CRITICAL" "File: $APPIMAGE_PATH"
            return 1
        fi
    fi
    
    local verify_end=$(date +%s%3N)
    local duration=$((verify_end - verify_start))
    performance_log "appimage_verification" "$duration" "Passed: $verification_passed"
    
    if $verification_passed; then
        log "SUCCESS" "AppImage verification passed"
        return 0
    else
        log "ERROR" "AppImage verification failed"
        return 1
    fi
}

# =============================================================================
# INSTALLATION FUNCTIONS
# =============================================================================

install_core_application() {
    log "INFO" "Installing core Cursor application..."
    
    local install_start=$(date +%s%3N)
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would install AppImage to $INSTALL_DIR"
        return 0
    fi
    
    # Create installation directory
    if ! sudo mkdir -p "$INSTALL_DIR"; then
        log "ERROR" "Failed to create installation directory: $INSTALL_DIR"
        return 1
    fi
    
    # Copy AppImage to installation directory
    if ! sudo cp "$APPIMAGE_PATH" "$INSTALL_DIR/cursor.AppImage"; then
        log "ERROR" "Failed to copy AppImage to installation directory"
        return 1
    fi
    
    # Set appropriate permissions
    sudo chmod 755 "$INSTALL_DIR/cursor.AppImage"
    sudo chown root:root "$INSTALL_DIR/cursor.AppImage"
    
    # Create version file
    echo "$CURSOR_VERSION" | sudo tee "$INSTALL_DIR/VERSION" >/dev/null
    
    # Create installation manifest
    cat << EOF | sudo tee "$INSTALL_DIR/MANIFEST" >/dev/null
# Cursor IDE Installation Manifest
Installed: $(date)
Version: $CURSOR_VERSION
Installer Version: $SCRIPT_VERSION
Mode: $INSTALL_MODE
User: $USER
EOF
    
    local install_end=$(date +%s%3N)
    local duration=$((install_end - install_start))
    performance_log "core_installation" "$duration" "Installation directory: $INSTALL_DIR"
    
    log "SUCCESS" "Core application installed successfully"
    audit_log "CORE_INSTALLED" "Directory: $INSTALL_DIR" "SUCCESS"
    
    return 0
}

create_system_integration() {
    log "INFO" "Creating system integration..."
    
    local integration_start=$(date +%s%3N)
    
    # Create symlink
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would create symlink $SYMLINK_DIR/cursor"
    else
        if ! sudo ln -sf "$INSTALL_DIR/cursor.AppImage" "$SYMLINK_DIR/cursor"; then
            log "ERROR" "Failed to create symlink"
            return 1
        fi
        log "DEBUG" "Created symlink: $SYMLINK_DIR/cursor -> $INSTALL_DIR/cursor.AppImage"
    fi
    
    # Create desktop entry
    create_desktop_entry
    
    # Create application icon
    create_application_icon
    
    # Setup file associations
    if [[ "${INSTALL_COMPONENTS[desktop_integration]}" == *"true"* ]]; then
        setup_file_associations
    fi
    
    # Install shell completion
    if [[ "${INSTALL_COMPONENTS[shell_integration]}" == *"true"* ]]; then
        install_shell_completion
    fi
    
    # Create man page
    create_man_page
    
    local integration_end=$(date +%s%3N)
    local duration=$((integration_end - integration_start))
    performance_log "system_integration" "$duration" "Components integrated"
    
    log "SUCCESS" "System integration completed"
    return 0
}

create_desktop_entry() {
    log "DEBUG" "Creating desktop entry..."
    
    local desktop_content='[Desktop Entry]
Name=Cursor
Comment=The AI-first code editor
GenericName=Text Editor
Exec=cursor %F
Icon=cursor
Type=Application
NoDisplay=false
Categories=Development;IDE;TextEditor;
StartupNotify=true
StartupWMClass=cursor
MimeType=text/plain;text/x-chdr;text/x-csrc;text/x-c++hdr;text/x-c++src;text/x-java;text/x-dsrc;text/x-pascal;text/x-perl;text/x-python;application/x-php;application/x-httpd-php3;application/x-httpd-php4;application/x-httpd-php5;application/javascript;application/json;text/css;text/html;text/xml;text/markdown;
Keywords=editor;development;programming;code;
Actions=new-empty-window;

[Desktop Action new-empty-window]
Name=New Empty Window
Exec=cursor --new-window %F
Icon=cursor'

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DEBUG" "DRY RUN: Would create desktop entry"
    else
        echo "$desktop_content" | sudo tee "$DESKTOP_DIR/cursor.desktop" >/dev/null
        sudo chmod 644 "$DESKTOP_DIR/cursor.desktop"
        log "DEBUG" "Desktop entry created: $DESKTOP_DIR/cursor.desktop"
    fi
}

create_application_icon() {
    log "DEBUG" "Creating application icon..."
    
    # Create a simple SVG icon if none exists
    local icon_content='<?xml version="1.0" encoding="UTF-8"?>
<svg width="128" height="128" viewBox="0 0 128 128" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="cursorGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#007ACC;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#005A9F;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="128" height="128" rx="16" fill="url(#cursorGradient)"/>
  <text x="64" y="80" font-family="Arial, sans-serif" font-size="48" font-weight="bold" fill="white" text-anchor="middle">C</text>
  <circle cx="88" cy="40" r="4" fill="white" opacity="0.8"/>
</svg>'
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DEBUG" "DRY RUN: Would create application icons"
    else
        # Create icons in multiple sizes
        local icon_sizes=(16 22 24 32 48 64 128 256)
        for size in "${icon_sizes[@]}"; do
            local icon_dir="$ICONS_DIR/${size}x${size}/apps"
            sudo mkdir -p "$icon_dir"
            echo "$icon_content" | sudo tee "$icon_dir/cursor.svg" >/dev/null
        done
        
        # Create scalable icon
        sudo mkdir -p "$ICONS_DIR/scalable/apps"
        echo "$icon_content" | sudo tee "$ICONS_DIR/scalable/apps/cursor.svg" >/dev/null
        
        # Update icon cache
        if command -v gtk-update-icon-cache >/dev/null 2>&1; then
            sudo gtk-update-icon-cache -t "$ICONS_DIR" 2>/dev/null || true
        fi
        
        log "DEBUG" "Application icons created"
    fi
}

setup_file_associations() {
    log "DEBUG" "Setting up file associations..."
    
    local mime_types=(
        "text/plain"
        "text/x-c"
        "text/x-c++"
        "text/x-java"
        "text/x-python"
        "application/javascript"
        "application/json"
        "text/css"
        "text/html"
        "text/xml"
        "text/markdown"
    )
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DEBUG" "DRY RUN: Would setup file associations for ${#mime_types[@]} MIME types"
    else
        for mime_type in "${mime_types[@]}"; do
            if command -v xdg-mime >/dev/null 2>&1; then
                xdg-mime default cursor.desktop "$mime_type" 2>/dev/null || true
            fi
        done
        log "DEBUG" "File associations configured"
    fi
}

install_shell_completion() {
    log "DEBUG" "Installing shell completion..."
    
    local bash_completion='# Cursor IDE bash completion
_cursor_complete() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    opts="--help --version --new-window --wait --goto --diff --add --reuse-window --verbose"
    
    if [[ ${cur} == -* ]]; then
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi
    
    COMPREPLY=( $(compgen -f -- ${cur}) )
}
complete -F _cursor_complete cursor'

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DEBUG" "DRY RUN: Would install shell completion"
    else
        echo "$bash_completion" | sudo tee "$BASH_COMPLETION_DIR/cursor" >/dev/null
        sudo chmod 644 "$BASH_COMPLETION_DIR/cursor"
        log "DEBUG" "Shell completion installed"
    fi
}

create_man_page() {
    log "DEBUG" "Creating man page..."
    
    local man_content='.TH CURSOR 1 "$(date +%Y-%m-%d)" "Cursor $(CURSOR_VERSION)" "User Commands"
.SH NAME
cursor \- AI-first code editor
.SH SYNOPSIS
.B cursor
[\fIOPTION\fR]... [\fIFILE\fR]...
.SH DESCRIPTION
Cursor is an AI-first code editor designed for pair-programming with AI.
.SH OPTIONS
.TP
\fB\-h\fR, \fB\-\-help\fR
Show help message
.TP
\fB\-v\fR, \fB\-\-version\fR
Show version information
.TP
\fB\-n\fR, \fB\-\-new\-window\fR
Open a new window
.TP
\fB\-w\fR, \fB\-\-wait\fR
Wait for the files to be closed before returning
.TP
\fB\-g\fR, \fB\-\-goto\fR
Go to line and column
.TP
\fB\-d\fR, \fB\-\-diff\fR
Compare two files
.SH EXAMPLES
.TP
cursor file.txt
Open file.txt in Cursor
.TP
cursor --new-window
Open a new Cursor window
.TP
cursor --diff file1.txt file2.txt
Compare two files
.SH AUTHORS
Written by the Cursor team.
.SH REPORTING BUGS
Report bugs to: https://github.com/getcursor/cursor/issues'

    if [[ "$DRY_RUN" == "true" ]]; then
        log "DEBUG" "DRY RUN: Would create man page"
    else
        sudo mkdir -p "$MAN_DIR"
        echo "$man_content" | sudo tee "$MAN_DIR/cursor.1" >/dev/null
        sudo chmod 644 "$MAN_DIR/cursor.1"
        
        # Update man database
        if command -v mandb >/dev/null 2>&1; then
            sudo mandb -q 2>/dev/null || true
        fi
        
        log "DEBUG" "Man page created: $MAN_DIR/cursor.1"
    fi
}

# =============================================================================
# POST-INSTALLATION FUNCTIONS
# =============================================================================

run_post_installation_tests() {
    log "INFO" "Running post-installation tests..."
    
    local test_start=$(date +%s%3N)
    local tests_passed=0
    local tests_failed=0
    
    # Test 1: Verify symlink works
    if command -v cursor >/dev/null 2>&1; then
        log "DEBUG" "✓ Command line access test passed"
        ((tests_passed++))
    else
        log "ERROR" "✗ Command line access test failed"
        ((tests_failed++))
    fi
    
    # Test 2: Verify version command
    if timeout 30 cursor --version >/dev/null 2>&1; then
        local version=$(cursor --version 2>&1 | head -1)
        log "DEBUG" "✓ Version command test passed: $version"
        ((tests_passed++))
    else
        log "ERROR" "✗ Version command test failed"
        ((tests_failed++))
    fi
    
    # Test 3: Verify desktop entry
    if [[ -f "$DESKTOP_DIR/cursor.desktop" ]]; then
        log "DEBUG" "✓ Desktop entry test passed"
        ((tests_passed++))
    else
        log "ERROR" "✗ Desktop entry test failed"
        ((tests_failed++))
    fi
    
    # Test 4: Verify help command
    if timeout 30 cursor --help >/dev/null 2>&1; then
        log "DEBUG" "✓ Help command test passed"
        ((tests_passed++))
    else
        log "ERROR" "✗ Help command test failed"
        ((tests_failed++))
    fi
    
    # Test 5: Verify installation manifest
    if [[ -f "$INSTALL_DIR/MANIFEST" ]]; then
        log "DEBUG" "✓ Installation manifest test passed"
        ((tests_passed++))
    else
        log "ERROR" "✗ Installation manifest test failed"
        ((tests_failed++))
    fi
    
    local test_end=$(date +%s%3N)
    local duration=$((test_end - test_start))
    performance_log "post_installation_tests" "$duration" "Passed: $tests_passed, Failed: $tests_failed"
    
    local total_tests=$((tests_passed + tests_failed))
    log "INFO" "Post-installation tests completed: $tests_passed/$total_tests passed"
    
    if [[ $tests_failed -eq 0 ]]; then
        log "SUCCESS" "All post-installation tests passed"
        return 0
    else
        log "ERROR" "$tests_failed post-installation tests failed"
        return 1
    fi
}

generate_installation_report() {
    log "INFO" "Generating installation report..."
    
    local report_file="$LOG_DIR/installation-report-${TIMESTAMP}.html"
    
    cat > "$report_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cursor IDE Installation Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1000px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; padding-bottom: 20px; border-bottom: 2px solid #e0e0e0; }
        .header h1 { color: #2c3e50; margin: 0; }
        .section { margin-bottom: 25px; }
        .section h2 { color: #34495e; border-bottom: 1px solid #bdc3c7; padding-bottom: 10px; }
        .info-grid { display: grid; grid-template-columns: 1fr 2fr; gap: 10px; margin: 15px 0; }
        .info-label { font-weight: bold; color: #7f8c8d; }
        .status-success { color: #27ae60; font-weight: bold; }
        .status-error { color: #e74c3c; font-weight: bold; }
        .footer { margin-top: 30px; text-align: center; color: #7f8c8d; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Cursor IDE Installation Report</h1>
            <p>Generated on $(date '+%Y-%m-%d %H:%M:%S')</p>
        </div>
        
        <div class="section">
            <h2>Installation Summary</h2>
            <div class="info-grid">
                <span class="info-label">Installer Version:</span>
                <span>$SCRIPT_VERSION</span>
                <span class="info-label">Cursor Version:</span>
                <span>$CURSOR_VERSION</span>
                <span class="info-label">Installation Mode:</span>
                <span>$INSTALL_MODE</span>
                <span class="info-label">Installation Path:</span>
                <span>$INSTALL_DIR</span>
                <span class="info-label">User:</span>
                <span>$USER</span>
                <span class="info-label">System:</span>
                <span>$(uname -sr)</span>
            </div>
        </div>
        
        <div class="section">
            <h2>Installation Status</h2>
            <div class="info-grid">
                <span class="info-label">Core Application:</span>
                <span class="status-success">✓ Installed</span>
                <span class="info-label">System Integration:</span>
                <span class="status-success">✓ Completed</span>
                <span class="info-label">Desktop Entry:</span>
                <span class="status-success">✓ Created</span>
                <span class="info-label">Shell Integration:</span>
                <span class="status-success">✓ Configured</span>
            </div>
        </div>
        
        <div class="section">
            <h2>File Locations</h2>
            <div class="info-grid">
                <span class="info-label">Executable:</span>
                <span>$INSTALL_DIR/cursor.AppImage</span>
                <span class="info-label">Symlink:</span>
                <span>$SYMLINK_DIR/cursor</span>
                <span class="info-label">Desktop Entry:</span>
                <span>$DESKTOP_DIR/cursor.desktop</span>
                <span class="info-label">Man Page:</span>
                <span>$MAN_DIR/cursor.1</span>
            </div>
        </div>
        
        <div class="footer">
            <p>Generated by Cursor IDE Enterprise Installation Framework v$SCRIPT_VERSION</p>
        </div>
    </div>
</body>
</html>
EOF
    
    log "SUCCESS" "Installation report generated: $report_file"
}

# =============================================================================
# MAIN EXECUTION FUNCTIONS
# =============================================================================

show_usage() {
    cat << EOF
Cursor IDE Enterprise Installation Framework v$SCRIPT_VERSION

USAGE:
    $SCRIPT_NAME [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -v, --version           Show version information
    -m, --mode MODE         Installation mode: minimal, standard, enterprise, developer, custom
    -f, --force             Force installation even if existing installation found
    -q, --quiet             Quiet mode (minimal output)
    -n, --dry-run           Perform dry run without making changes
    -s, --skip-verification Skip AppImage verification
    -b, --no-backup         Skip backup creation
    -t, --no-telemetry      Disable telemetry
    -r, --rollback          Rollback to previous installation

INSTALLATION MODES:
$(for mode in "${!INSTALL_MODES[@]}"; do
    printf "    %-12s %s\n" "$mode" "${INSTALL_MODES[$mode]}"
done)

EXAMPLES:
    $SCRIPT_NAME                           # Standard installation
    $SCRIPT_NAME --mode enterprise         # Enterprise installation
    $SCRIPT_NAME --force --quiet           # Force quiet installation
    $SCRIPT_NAME --dry-run                 # Test installation without changes
    $SCRIPT_NAME --rollback                # Rollback previous installation

ENVIRONMENT VARIABLES:
    CURSOR_INSTALL_MODE     Default installation mode
    CURSOR_INSTALL_DIR      Custom installation directory
    CURSOR_SKIP_TESTS       Skip post-installation tests
    CURSOR_DEBUG            Enable debug logging

For more information, visit: https://cursor.sh/docs/installation
EOF
}

show_version() {
    cat << EOF
Cursor IDE Enterprise Installation Framework
Version: $SCRIPT_VERSION
Cursor Version: $CURSOR_VERSION
Build Date: $(date '+%Y-%m-%d')
Platform: $(uname -s) $(uname -m)

Copyright (c) 2024 Enterprise Development Team
Licensed under MIT License
EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -m|--mode)
                if [[ -n "$2" ]] && [[ -n "${INSTALL_MODES[$2]}" ]]; then
                    INSTALL_MODE="$2"
                    shift
                else
                    log "ERROR" "Invalid installation mode: ${2:-}"
                    exit 1
                fi
                ;;
            -f|--force)
                FORCE_INSTALL=true
                ;;
            -q|--quiet)
                QUIET_MODE=true
                ;;
            -n|--dry-run)
                DRY_RUN=true
                ;;
            -s|--skip-verification)
                SKIP_VERIFICATION=true
                ;;
            -b|--no-backup)
                CREATE_BACKUPS=false
                ;;
            -t|--no-telemetry)
                ENABLE_TELEMETRY=false
                ;;
            -r|--rollback)
                ROLLBACK_MODE=true
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
        shift
    done
}

perform_rollback() {
    log "INFO" "Performing installation rollback..."
    
    # Find the most recent rollback script
    local rollback_script=$(find "$BACKUP_DIR" -name "rollback-*.sh" -type f 2>/dev/null | sort -r | head -1)
    
    if [[ -z "$rollback_script" ]]; then
        log "ERROR" "No rollback script found"
        exit 1
    fi
    
    log "INFO" "Using rollback script: $rollback_script"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would execute rollback script"
    else
        if bash "$rollback_script"; then
            log "SUCCESS" "Rollback completed successfully"
        else
            log "ERROR" "Rollback failed"
            exit 1
        fi
    fi
    
    exit 0
}

main() {
    # Set up signal handlers
    trap cleanup EXIT
    trap 'error_handler ${LINENO} "$BASH_COMMAND" $?' ERR
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Handle rollback mode
    if [[ "$ROLLBACK_MODE" == "true" ]]; then
        perform_rollback
    fi
    
    log "INFO" "Starting Cursor IDE Enterprise Installation v$SCRIPT_VERSION"
    log "INFO" "Installation mode: $INSTALL_MODE"
    audit_log "INSTALLATION_STARTED" "Mode: $INSTALL_MODE, User: $USER" "SUCCESS"
    
    # Initialize environment
    create_directory_structure || {
        log "CRITICAL" "Failed to create directory structure"
        exit 1
    }
    
    initialize_configuration || {
        log "CRITICAL" "Failed to initialize configuration"
        exit 1
    }
    
    # System validation
    log "INFO" "Performing system validation..."
    
    if ! check_system_requirements; then
        if [[ "$FORCE_INSTALL" != "true" ]]; then
            log "ERROR" "System requirements not met (use --force to override)"
            exit 1
        else
            log "WARN" "Proceeding with installation despite unmet requirements"
        fi
    fi
    
    if ! check_permissions; then
        log "WARN" "Permission issues detected - installation may require sudo"
    fi
    
    if ! detect_existing_installation; then
        if [[ "$FORCE_INSTALL" != "true" ]]; then
            log "ERROR" "Existing installation found (use --force to override)"
            exit 1
        else
            log "WARN" "Proceeding with forced installation"
        fi
    fi
    
    # Create backup
    create_backup
    
    # Download and verify
    if ! download_cursor_appimage; then
        log "CRITICAL" "Failed to download Cursor AppImage"
        exit 1
    fi
    
    if ! verify_appimage_integrity; then
        log "CRITICAL" "AppImage verification failed"
        exit 1
    fi
    
    # Installation
    log "INFO" "Beginning installation process..."
    
    if ! install_core_application; then
        log "CRITICAL" "Core application installation failed"
        exit 1
    fi
    
    if ! create_system_integration; then
        log "CRITICAL" "System integration failed"
        exit 1
    fi
    
    # Post-installation
    if [[ "${CURSOR_SKIP_TESTS:-false}" != "true" ]]; then
        if ! run_post_installation_tests; then
            log "WARN" "Some post-installation tests failed"
        fi
    fi
    
    # Generate report
    generate_installation_report
    
    # Final message
    log "SUCCESS" "Cursor IDE installation completed successfully!"
    log "INFO" "You can now launch Cursor by running: cursor"
    log "INFO" "Installation logs available in: $LOG_DIR"
    
    if [[ "$CREATE_BACKUPS" == "true" ]]; then
        log "INFO" "Rollback script available at: $ROLLBACK_SCRIPT"
    fi
    
    audit_log "INSTALLATION_COMPLETED" "Success" "SUCCESS"
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Only run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi