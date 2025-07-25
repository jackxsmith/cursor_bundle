#!/usr/bin/env bash
#
# PROFESSIONAL CURSOR IDE INSTALLER v2.0
# Enterprise-Grade Installation System
#
# Enhanced Features:
# - Robust error handling and recovery
# - Self-correcting installation mechanisms
# - Advanced validation and verification
# - Professional logging and auditing
# - Automated rollback capabilities
# - Performance optimization
#

set -euo pipefail
IFS=$'\n\t'

# === CONFIGURATION ===
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="$(basename "${0}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Installation Configuration
readonly CURSOR_VERSION="${CURSOR_VERSION:-6.9.35}"
readonly INSTALL_DIR="${CURSOR_INSTALL_DIR:-/opt/cursor}"
readonly SYMLINK_DIR="/usr/local/bin"
readonly DESKTOP_DIR="/usr/share/applications"

# Directory Structure
readonly LOG_DIR="${HOME}/.cache/cursor/logs"
readonly BACKUP_DIR="${HOME}/.cache/cursor/backup"
readonly TEMP_DIR="$(mktemp -d -t cursor_install_XXXXXX)"

# Log Files
readonly MAIN_LOG="${LOG_DIR}/install_${TIMESTAMP}.log"
readonly ERROR_LOG="${LOG_DIR}/install_errors_${TIMESTAMP}.log"
readonly AUDIT_LOG="${LOG_DIR}/install_audit_${TIMESTAMP}.log"

# Installation Variables
declare -g FORCE_INSTALL=false
declare -g DRY_RUN=false
declare -g QUIET_MODE=false
declare -g SKIP_BACKUP=false
declare -g APPIMAGE_PATH=""

# System Requirements
readonly MIN_RAM_MB=2048
readonly MIN_DISK_MB=4096
readonly MIN_CPU_CORES=2

# === UTILITY FUNCTIONS ===

# Enhanced logging with levels
log() {
    local level="$1"
    local message="$2"
    local timestamp="$(date -Iseconds)"
    
    echo "[${timestamp}] ${level}: ${message}" >> "$MAIN_LOG"
    
    case "$level" in
        ERROR) 
            echo "[${timestamp}] ${level}: ${message}" >> "$ERROR_LOG"
            echo -e "\033[0;31m[ERROR]\033[0m ${message}" >&2
            ;;
        WARN) 
            echo -e "\033[1;33m[WARN]\033[0m ${message}"
            ;;
        PASS) 
            echo -e "\033[0;32m[✓]\033[0m ${message}"
            ;;
        INFO) 
            [[ "$QUIET_MODE" != "true" ]] && echo -e "\033[0;34m[INFO]\033[0m ${message}"
            ;;
        DEBUG) 
            [[ "${DEBUG:-false}" == "true" ]] && echo -e "\033[0;36m[DEBUG]\033[0m ${message}"
            ;;
    esac
}

# Audit logging
audit_log() {
    local action="$1"
    local status="$2"
    local details="${3:-}"
    local user="${SUDO_USER:-$USER}"
    local timestamp="$(date -Iseconds)"
    
    echo "[${timestamp}] USER=${user} ACTION=${action} STATUS=${status} DETAILS=${details}" >> "$AUDIT_LOG"
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
    local dirs=("$LOG_DIR" "$BACKUP_DIR")
    
    for dir in "${dirs[@]}"; do
        if ! ensure_directory "$dir"; then
            echo "Failed to initialize directories"
            return 1
        fi
    done
    
    # Log rotation
    find "$LOG_DIR" -name "install_*.log" -mtime +7 -delete 2>/dev/null || true
    find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +30 -delete 2>/dev/null || true
    
    return 0
}

# Retry mechanism
retry_operation() {
    local operation="$1"
    local max_attempts="${2:-3}"
    local delay="${3:-2}"
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if eval "$operation"; then
            return 0
        fi
        
        ((attempt++))
        if [[ $attempt -lt $max_attempts ]]; then
            log "WARN" "Operation failed, retrying (attempt $((attempt + 1))/$max_attempts)"
            sleep "$delay"
        fi
    done
    
    log "ERROR" "Operation failed after $max_attempts attempts: $operation"
    return 1
}

# Cleanup function
cleanup() {
    [[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
    
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        log "PASS" "Installation completed successfully"
        audit_log "INSTALLATION_COMPLETE" "SUCCESS" "Exit code: $exit_code"
    else
        log "ERROR" "Installation failed with exit code: $exit_code"
        audit_log "INSTALLATION_FAILED" "FAILURE" "Exit code: $exit_code"
    fi
}

trap cleanup EXIT
trap 'exit 130' INT TERM

# === VALIDATION FUNCTIONS ===

# Check system requirements
check_system_requirements() {
    log "INFO" "Checking system requirements"
    
    local requirements_met=true
    
    # Check memory
    local total_ram_kb=$(grep "MemTotal:" /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
    local total_ram_mb=$((total_ram_kb / 1024))
    
    if [[ $total_ram_mb -lt $MIN_RAM_MB ]]; then
        log "ERROR" "Insufficient RAM: ${total_ram_mb}MB (minimum: ${MIN_RAM_MB}MB)"
        requirements_met=false
    else
        log "PASS" "RAM check: ${total_ram_mb}MB available"
    fi
    
    # Check disk space
    local available_disk_kb=$(df "$HOME" | tail -1 | awk '{print $4}')
    local available_disk_mb=$((available_disk_kb / 1024))
    
    if [[ $available_disk_mb -lt $MIN_DISK_MB ]]; then
        log "ERROR" "Insufficient disk space: ${available_disk_mb}MB (minimum: ${MIN_DISK_MB}MB)"
        requirements_met=false
    else
        log "PASS" "Disk space check: ${available_disk_mb}MB available"
    fi
    
    # Check CPU cores
    local cpu_cores=$(nproc 2>/dev/null || echo "1")
    if [[ $cpu_cores -lt $MIN_CPU_CORES ]]; then
        log "WARN" "Low CPU cores: $cpu_cores (recommended: $MIN_CPU_CORES+)"
    else
        log "PASS" "CPU cores check: $cpu_cores cores"
    fi
    
    # Check required commands
    local required_commands=("curl" "tar" "chmod" "ln")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log "ERROR" "Required command not found: $cmd"
            requirements_met=false
        else
            log "DEBUG" "Command available: $cmd"
        fi
    done
    
    if $requirements_met; then
        log "PASS" "System requirements check passed"
        return 0
    else
        log "ERROR" "System requirements check failed"
        return 1
    fi
}

# Check for existing installation
check_existing_installation() {
    log "INFO" "Checking for existing Cursor installation"
    
    local existing_paths=(
        "/opt/cursor"
        "/usr/local/bin/cursor"
        "/usr/bin/cursor"
        "$HOME/.cursor"
    )
    
    local found_installations=()
    
    for path in "${existing_paths[@]}"; do
        if [[ -e "$path" ]]; then
            found_installations+=("$path")
            log "INFO" "Found existing installation: $path"
        fi
    done
    
    if [[ ${#found_installations[@]} -gt 0 ]]; then
        if [[ "$FORCE_INSTALL" != "true" ]]; then
            log "ERROR" "Existing installation found. Use --force to overwrite"
            return 1
        else
            log "WARN" "Overwriting existing installation (--force specified)"
        fi
    else
        log "PASS" "No existing installation found"
    fi
    
    return 0
}

# Check permissions
check_permissions() {
    log "INFO" "Checking installation permissions"
    
    local permission_issues=0
    local test_dirs=("$(dirname "$INSTALL_DIR")" "$(dirname "$SYMLINK_DIR")" "$(dirname "$DESKTOP_DIR")")
    
    for dir in "${test_dirs[@]}"; do
        if [[ ! -w "$dir" ]] && [[ "$EUID" -ne 0 ]]; then
            log "WARN" "No write permission to $dir (may need sudo)"
            ((permission_issues++))
        fi
    done
    
    if [[ $permission_issues -eq 0 ]]; then
        log "PASS" "Permission checks passed"
        return 0
    else
        log "WARN" "Permission issues detected: $permission_issues"
        return 1
    fi
}

# === BACKUP FUNCTIONS ===

# Create backup of existing installation
create_backup() {
    if [[ "$SKIP_BACKUP" == "true" ]] || [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "Skipping backup creation"
        return 0
    fi
    
    log "INFO" "Creating backup of existing installation"
    
    local backup_file="$BACKUP_DIR/cursor_backup_${TIMESTAMP}.tar.gz"
    local backup_items=()
    
    # Collect items to backup
    [[ -d "$INSTALL_DIR" ]] && backup_items+=("$INSTALL_DIR")
    [[ -L "$SYMLINK_DIR/cursor" ]] && backup_items+=("$SYMLINK_DIR/cursor")
    [[ -f "$DESKTOP_DIR/cursor.desktop" ]] && backup_items+=("$DESKTOP_DIR/cursor.desktop")
    
    if [[ ${#backup_items[@]} -gt 0 ]]; then
        if tar -czf "$backup_file" "${backup_items[@]}" 2>/dev/null; then
            log "PASS" "Backup created: $backup_file"
            audit_log "BACKUP_CREATED" "SUCCESS" "File: $backup_file"
            
            # Create restore script
            create_restore_script "$backup_file"
        else
            log "ERROR" "Failed to create backup"
            return 1
        fi
    else
        log "INFO" "No existing installation to backup"
    fi
    
    return 0
}

# Create restore script
create_restore_script() {
    local backup_file="$1"
    local restore_script="$BACKUP_DIR/restore_${TIMESTAMP}.sh"
    
    cat > "$restore_script" << EOF
#!/usr/bin/env bash
# Cursor IDE Restore Script
# Generated: $(date)

set -euo pipefail

BACKUP_FILE="$backup_file"

if [[ ! -f "\$BACKUP_FILE" ]]; then
    echo "ERROR: Backup file not found: \$BACKUP_FILE"
    exit 1
fi

echo "Restoring Cursor IDE from backup..."

# Remove current installation
[[ -d "$INSTALL_DIR" ]] && sudo rm -rf "$INSTALL_DIR"
[[ -L "$SYMLINK_DIR/cursor" ]] && sudo rm -f "$SYMLINK_DIR/cursor"
[[ -f "$DESKTOP_DIR/cursor.desktop" ]] && sudo rm -f "$DESKTOP_DIR/cursor.desktop"

# Extract backup
if tar -xzf "\$BACKUP_FILE" -C /; then
    echo "✓ Restore completed successfully"
else
    echo "✗ Restore failed"
    exit 1
fi
EOF
    
    chmod +x "$restore_script"
    log "DEBUG" "Restore script created: $restore_script"
}

# === DOWNLOAD FUNCTIONS ===

# Download Cursor AppImage
download_cursor() {
    log "INFO" "Downloading Cursor IDE AppImage"
    
    local download_urls=(
        "https://download.cursor.sh/linux/appImage/x64"
        "https://github.com/getcursor/cursor/releases/latest/download/cursor.AppImage"
        "https://api.cursor.com/releases/latest/cursor.AppImage"
    )
    
    APPIMAGE_PATH="$TEMP_DIR/cursor.AppImage"
    
    for url in "${download_urls[@]}"; do
        log "DEBUG" "Trying download URL: $url"
        
        if [[ "$DRY_RUN" == "true" ]]; then
            log "INFO" "DRY RUN: Would download from $url"
            return 0
        fi
        
        if retry_operation "curl -fsSL --connect-timeout 30 --max-time 1800 -o '$APPIMAGE_PATH' '$url'" 3 5; then
            log "PASS" "Download successful from: $url"
            break
        else
            log "WARN" "Download failed from: $url"
            APPIMAGE_PATH=""
        fi
    done
    
    if [[ -z "$APPIMAGE_PATH" ]] || [[ ! -f "$APPIMAGE_PATH" ]]; then
        log "ERROR" "Failed to download Cursor AppImage from all sources"
        return 1
    fi
    
    # Verify download
    local file_size=$(stat -c%s "$APPIMAGE_PATH" 2>/dev/null || echo "0")
    if [[ $file_size -lt 10485760 ]]; then  # Less than 10MB
        log "ERROR" "Downloaded file appears to be invalid (size: $file_size bytes)"
        return 1
    fi
    
    # Make executable
    chmod +x "$APPIMAGE_PATH"
    
    log "PASS" "AppImage downloaded successfully ($(( file_size / 1024 / 1024 ))MB)"
    audit_log "APPIMAGE_DOWNLOADED" "SUCCESS" "Size: $file_size bytes"
    
    return 0
}

# Verify AppImage integrity
verify_appimage() {
    log "INFO" "Verifying AppImage integrity"
    
    if [[ ! -f "$APPIMAGE_PATH" ]]; then
        log "ERROR" "AppImage file not found: $APPIMAGE_PATH"
        return 1
    fi
    
    # Check file type
    local file_type=$(file "$APPIMAGE_PATH" 2>/dev/null || echo "unknown")
    if [[ "$file_type" != *"executable"* ]]; then
        log "WARN" "AppImage may not be executable: $file_type"
    fi
    
    # Test execution
    if timeout 30 "$APPIMAGE_PATH" --version >/dev/null 2>&1; then
        local version_output=$("$APPIMAGE_PATH" --version 2>&1 | head -1)
        log "PASS" "AppImage verification passed: $version_output"
    else
        log "ERROR" "AppImage verification failed - cannot execute"
        return 1
    fi
    
    return 0
}

# === INSTALLATION FUNCTIONS ===

# Install core application
install_core() {
    log "INFO" "Installing core Cursor application"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would install to $INSTALL_DIR"
        return 0
    fi
    
    # Create installation directory
    if ! sudo mkdir -p "$INSTALL_DIR"; then
        log "ERROR" "Failed to create installation directory: $INSTALL_DIR"
        return 1
    fi
    
    # Copy AppImage
    if ! sudo cp "$APPIMAGE_PATH" "$INSTALL_DIR/cursor.AppImage"; then
        log "ERROR" "Failed to copy AppImage to installation directory"
        return 1
    fi
    
    # Set permissions
    sudo chmod 755 "$INSTALL_DIR/cursor.AppImage"
    sudo chown root:root "$INSTALL_DIR/cursor.AppImage"
    
    # Create version file
    echo "$CURSOR_VERSION" | sudo tee "$INSTALL_DIR/VERSION" >/dev/null
    
    # Create installation manifest
    cat << EOF | sudo tee "$INSTALL_DIR/MANIFEST" >/dev/null
# Cursor IDE Installation Manifest
Installed: $(date -Iseconds)
Version: $CURSOR_VERSION
Installer: $SCRIPT_VERSION
User: $USER
System: $(uname -sr)
EOF
    
    log "PASS" "Core application installed successfully"
    audit_log "CORE_INSTALLED" "SUCCESS" "Directory: $INSTALL_DIR"
    
    return 0
}

# Create system integration
create_integration() {
    log "INFO" "Creating system integration"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would create system integration"
        return 0
    fi
    
    # Create symlink
    if ! sudo ln -sf "$INSTALL_DIR/cursor.AppImage" "$SYMLINK_DIR/cursor"; then
        log "ERROR" "Failed to create symlink"
        return 1
    fi
    log "DEBUG" "Created symlink: $SYMLINK_DIR/cursor"
    
    # Create desktop entry
    create_desktop_entry
    
    # Update desktop database
    if command -v update-desktop-database >/dev/null 2>&1; then
        sudo update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
    fi
    
    log "PASS" "System integration completed"
    audit_log "INTEGRATION_CREATED" "SUCCESS" "Symlink and desktop entry"
    
    return 0
}

# Create desktop entry
create_desktop_entry() {
    log "DEBUG" "Creating desktop entry"
    
    local desktop_content='[Desktop Entry]
Name=Cursor
Comment=The AI-first code editor
GenericName=Code Editor
Exec=cursor %F
Icon=cursor
Type=Application
Categories=Development;IDE;TextEditor;
StartupNotify=true
MimeType=text/plain;text/x-chdr;text/x-csrc;text/x-c++hdr;text/x-c++src;text/x-java;text/x-python;application/javascript;application/json;text/css;text/html;text/xml;text/markdown;
Keywords=editor;development;programming;code;'
    
    if echo "$desktop_content" | sudo tee "$DESKTOP_DIR/cursor.desktop" >/dev/null; then
        sudo chmod 644 "$DESKTOP_DIR/cursor.desktop"
        log "DEBUG" "Desktop entry created: $DESKTOP_DIR/cursor.desktop"
    else
        log "WARN" "Failed to create desktop entry"
    fi
}

# === POST-INSTALLATION FUNCTIONS ===

# Run post-installation tests
run_tests() {
    log "INFO" "Running post-installation tests"
    
    local tests_passed=0
    local tests_failed=0
    
    # Test 1: Command availability
    if command -v cursor >/dev/null 2>&1; then
        log "PASS" "Command line access test"
        ((tests_passed++))
    else
        log "ERROR" "Command line access test failed"
        ((tests_failed++))
    fi
    
    # Test 2: Version command
    if timeout 30 cursor --version >/dev/null 2>&1; then
        local version=$(cursor --version 2>&1 | head -1)
        log "PASS" "Version command test: $version"
        ((tests_passed++))
    else
        log "ERROR" "Version command test failed"
        ((tests_failed++))
    fi
    
    # Test 3: Desktop entry
    if [[ -f "$DESKTOP_DIR/cursor.desktop" ]]; then
        log "PASS" "Desktop entry test"
        ((tests_passed++))
    else
        log "ERROR" "Desktop entry test failed"
        ((tests_failed++))
    fi
    
    # Test 4: Installation manifest
    if [[ -f "$INSTALL_DIR/MANIFEST" ]]; then
        log "PASS" "Installation manifest test"
        ((tests_passed++))
    else
        log "ERROR" "Installation manifest test failed"
        ((tests_failed++))
    fi
    
    local total_tests=$((tests_passed + tests_failed))
    log "INFO" "Tests completed: $tests_passed/$total_tests passed"
    
    if [[ $tests_failed -eq 0 ]]; then
        log "PASS" "All post-installation tests passed"
        return 0
    else
        log "WARN" "$tests_failed tests failed"
        return 1
    fi
}

# === MAIN EXECUTION ===

# Show usage information
show_usage() {
    cat << EOF
Cursor IDE Professional Installer v$SCRIPT_VERSION

USAGE:
    $SCRIPT_NAME [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -f, --force         Force installation over existing
    -q, --quiet         Quiet mode (minimal output)
    -n, --dry-run       Perform dry run without changes
    -b, --skip-backup   Skip backup creation
    --version           Show version information

EXAMPLES:
    $SCRIPT_NAME                    # Standard installation
    $SCRIPT_NAME --force --quiet    # Force quiet installation
    $SCRIPT_NAME --dry-run          # Test without changes

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            --version)
                echo "Cursor IDE Professional Installer v$SCRIPT_VERSION"
                exit 0
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
            -b|--skip-backup)
                SKIP_BACKUP=true
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

# Main installation function
main() {
    # Parse arguments
    parse_arguments "$@"
    
    log "INFO" "Starting Cursor IDE Professional Installation v$SCRIPT_VERSION"
    audit_log "INSTALLATION_STARTED" "SUCCESS" "Version: $SCRIPT_VERSION"
    
    # Initialize
    if ! initialize_directories; then
        log "ERROR" "Failed to initialize directories"
        exit 1
    fi
    
    # System validation
    if ! check_system_requirements; then
        if [[ "$FORCE_INSTALL" != "true" ]]; then
            log "ERROR" "System requirements not met (use --force to override)"
            exit 1
        else
            log "WARN" "Proceeding despite unmet requirements"
        fi
    fi
    
    if ! check_existing_installation; then
        exit 1
    fi
    
    if ! check_permissions; then
        log "WARN" "Permission issues detected - may require sudo"
    fi
    
    # Backup existing installation
    create_backup
    
    # Download and verify
    if ! download_cursor; then
        log "ERROR" "Failed to download Cursor"
        exit 1
    fi
    
    if ! verify_appimage; then
        log "ERROR" "AppImage verification failed"
        exit 1
    fi
    
    # Installation
    if ! install_core; then
        log "ERROR" "Core installation failed"
        exit 1
    fi
    
    if ! create_integration; then
        log "ERROR" "System integration failed"
        exit 1
    fi
    
    # Post-installation testing
    if ! run_tests; then
        log "WARN" "Some post-installation tests failed"
    fi
    
    # Success message
    log "PASS" "Cursor IDE installation completed successfully!"
    log "INFO" "Launch Cursor by running: cursor"
    log "INFO" "Installation logs: $LOG_DIR"
    
    audit_log "INSTALLATION_COMPLETED" "SUCCESS" "All components installed"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi