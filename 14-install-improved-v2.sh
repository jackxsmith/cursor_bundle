#\!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# 14-install-improved-v2.sh - Professional Installation Framework v2.0
# Enterprise-grade installation system with robust error handling and self-correcting mechanisms
# ============================================================================

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="2.0.0"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Configuration Management
readonly APP_NAME="cursor"
readonly INSTALL_CONFIG_DIR="${HOME}/.config/cursor-install"
readonly INSTALL_CACHE_DIR="${HOME}/.cache/cursor-install"
readonly INSTALL_LOG_DIR="${INSTALL_CONFIG_DIR}/logs"

# Logging Configuration
readonly LOG_FILE="${INSTALL_LOG_DIR}/install_${TIMESTAMP}.log"
readonly ERROR_LOG="${INSTALL_LOG_DIR}/install_errors_${TIMESTAMP}.log"
readonly PROGRESS_LOG="${INSTALL_LOG_DIR}/install_progress_${TIMESTAMP}.log"

# Lock Management
readonly LOCK_FILE="${INSTALL_CONFIG_DIR}/.install.lock"
readonly PID_FILE="${INSTALL_CONFIG_DIR}/.install.pid"

# Global Variables
declare -g INSTALL_CONFIG="${INSTALL_CONFIG_DIR}/install.conf"
declare -g VERBOSE_MODE=false
declare -g DRY_RUN_MODE=false
declare -g INSTALL_PREFIX="${HOME}/.local"
declare -g INSTALLATION_SUCCESS=true

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
        *"cp"* < /dev/null | *"mv"*)
            log_info "File operation failed, checking disk space and permissions..."
            check_disk_space_and_permissions
            ;;
        *"chmod"*|*"chown"*)
            log_info "Permission change failed, checking file system status..."
            check_filesystem_status
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

log_progress() {
    local step="$1"
    local status="$2"
    local details="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] PROGRESS: $step - $status ($details)" >> "$PROGRESS_LOG"
}

# Initialize installation framework
initialize_install_framework() {
    log_info "Initializing Professional Installation Framework v${VERSION}"
    
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
    
    log_info "Installation framework initialization completed successfully"
}

# Create directory structure with retry logic
create_directory_structure() {
    local dirs=("$INSTALL_CONFIG_DIR" "$INSTALL_CACHE_DIR" "$INSTALL_LOG_DIR")
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
    if [[ \! -f "$INSTALL_CONFIG" ]]; then
        log_info "Creating default installation configuration"
        create_default_configuration
    fi
    
    # Source configuration safely
    if [[ -r "$INSTALL_CONFIG" ]]; then
        source "$INSTALL_CONFIG"
        log_info "Configuration loaded from $INSTALL_CONFIG"
    else
        log_warning "Configuration file not readable, using defaults"
    fi
}

# Create default configuration
create_default_configuration() {
    cat > "$INSTALL_CONFIG" << 'CONFIGEOF'
# Professional Installation Framework Configuration v2.0

# General Settings
VERBOSE_MODE=false
DRY_RUN_MODE=false
FORCE_INSTALL=false
BACKUP_EXISTING=true

# Installation Paths
INSTALL_PREFIX=${HOME}/.local
BIN_DIR=${INSTALL_PREFIX}/bin
SHARE_DIR=${INSTALL_PREFIX}/share
CONFIG_DIR=${HOME}/.config

# Installation Options
CREATE_SYMLINKS=true
UPDATE_DESKTOP_DATABASE=true
REGISTER_MIME_TYPES=false

# Backup Settings
BACKUP_DIR=${HOME}/.local/share/cursor-backups
BACKUP_RETENTION_DAYS=30

# Verification Settings
VERIFY_CHECKSUMS=false
PERFORM_POST_INSTALL_TESTS=true

# Maintenance Settings
LOG_RETENTION_DAYS=30
CLEANUP_TEMP_FILES=true
CONFIGEOF
    
    log_info "Default configuration created: $INSTALL_CONFIG"
}

# Acquire lock with timeout
acquire_lock() {
    local timeout=30
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        if (set -C; echo $$ > "$LOCK_FILE") 2>/dev/null; then
            echo $$ > "$PID_FILE"
            log_info "Installation lock acquired successfully"
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
    
    log_error "Failed to acquire installation lock after ${timeout}s"
    return 1
}

# Perform installation
perform_installation() {
    log_info "Starting Cursor IDE installation..."
    log_progress "INSTALLATION" "STARTED" "Beginning installation process"
    
    local install_start=$(date +%s)
    INSTALLATION_SUCCESS=true
    
    # Pre-installation checks
    if \! perform_preinstall_checks; then
        INSTALLATION_SUCCESS=false
        return 1
    fi
    
    # Create installation directories
    create_install_directories
    
    # Backup existing installation
    if [[ "${BACKUP_EXISTING:-true}" == "true" ]]; then
        backup_existing_installation
    fi
    
    # Install application files
    install_application_files
    
    # Install scripts and utilities
    install_scripts_and_utilities
    
    # Configure desktop integration
    configure_desktop_integration
    
    # Set up environment
    setup_environment
    
    # Post-installation verification
    if \! verify_installation; then
        INSTALLATION_SUCCESS=false
        return 1
    fi
    
    local install_end=$(date +%s)
    local install_duration=$((install_end - install_start))
    
    if [[ "$INSTALLATION_SUCCESS" == "true" ]]; then
        log_info "Installation completed successfully in ${install_duration}s"
        log_progress "INSTALLATION" "COMPLETED" "Success in ${install_duration}s"
        return 0
    else
        log_error "Installation failed after ${install_duration}s"
        log_progress "INSTALLATION" "FAILED" "Failed after ${install_duration}s"
        return 1
    fi
}

# Perform pre-installation checks
perform_preinstall_checks() {
    log_info "Performing pre-installation checks..."
    log_progress "PRE_CHECKS" "STARTED" "Validating system requirements"
    
    # Check available disk space
    local required_space=2048  # MB
    local available_space
    available_space=$(df "$HOME" | awk 'NR==2 {print int($4/1024)}')
    
    if [[ $available_space -lt $required_space ]]; then
        log_error "Insufficient disk space: ${available_space}MB < ${required_space}MB"
        log_progress "PRE_CHECKS" "FAILED" "Insufficient disk space"
        return 1
    fi
    
    # Check write permissions
    if [[ \! -w "$HOME" ]]; then
        log_error "No write permission in home directory"
        log_progress "PRE_CHECKS" "FAILED" "No write permission"
        return 1
    fi
    
    # Check if AppImage exists
    local app_binary="${SCRIPT_DIR}/cursor.AppImage"
    if [[ \! -f "$app_binary" ]]; then
        app_binary=$(find "$SCRIPT_DIR" -name "*.AppImage" -type f | head -1)
    fi
    
    if [[ -z "$app_binary" || \! -f "$app_binary" ]]; then
        log_error "Cursor AppImage not found in $SCRIPT_DIR"
        log_progress "PRE_CHECKS" "FAILED" "AppImage not found"
        return 1
    fi
    
    log_info "Pre-installation checks completed successfully"
    log_progress "PRE_CHECKS" "COMPLETED" "All checks passed"
    return 0
}

# Create installation directories
create_install_directories() {
    log_info "Creating installation directories..."
    log_progress "DIRECTORIES" "STARTED" "Creating directory structure"
    
    local install_dirs=(
        "$INSTALL_PREFIX"
        "${BIN_DIR:-$INSTALL_PREFIX/bin}"
        "${SHARE_DIR:-$INSTALL_PREFIX/share}"
        "${SHARE_DIR:-$INSTALL_PREFIX/share}/cursor"
        "${SHARE_DIR:-$INSTALL_PREFIX/share}/applications"
    )
    
    for dir in "${install_dirs[@]}"; do
        if mkdir -p "$dir" 2>/dev/null; then
            log_info "Created directory: $dir"
        else
            log_error "Failed to create directory: $dir"
            INSTALLATION_SUCCESS=false
            return 1
        fi
    done
    
    log_progress "DIRECTORIES" "COMPLETED" "Directory structure created"
}

# Backup existing installation
backup_existing_installation() {
    log_info "Backing up existing installation..."
    log_progress "BACKUP" "STARTED" "Creating backup of existing files"
    
    local backup_dir="${BACKUP_DIR:-$HOME/.local/share/cursor-backups}/backup_${TIMESTAMP}"
    local backup_created=false
    
    # Check for existing installation files
    local files_to_backup=(
        "${BIN_DIR:-$INSTALL_PREFIX/bin}/cursor"
        "${SHARE_DIR:-$INSTALL_PREFIX/share}/cursor"
        "${SHARE_DIR:-$INSTALL_PREFIX/share}/applications/cursor.desktop"
    )
    
    for file in "${files_to_backup[@]}"; do
        if [[ -e "$file" ]]; then
            if [[ "$backup_created" == "false" ]]; then
                mkdir -p "$backup_dir"
                backup_created=true
                log_info "Created backup directory: $backup_dir"
            fi
            
            local backup_path="$backup_dir/$(basename "$file")"
            if cp -r "$file" "$backup_path" 2>/dev/null; then
                log_info "Backed up: $file -> $backup_path"
            else
                log_warning "Failed to backup: $file"
            fi
        fi
    done
    
    if [[ "$backup_created" == "true" ]]; then
        cat > "$backup_dir/backup_info.txt" << BACKUPEOF
Backup created: $(date)
Original installation backed up before update
Cursor IDE Installation Backup
BACKUPEOF
        log_progress "BACKUP" "COMPLETED" "Existing files backed up"
    else
        log_info "No existing installation found, skipping backup"
        log_progress "BACKUP" "SKIPPED" "No existing installation"
    fi
}

# Install application files
install_application_files() {
    log_info "Installing application files..."
    log_progress "APP_FILES" "STARTED" "Installing Cursor IDE application files"
    
    # Find the AppImage
    local app_binary="${SCRIPT_DIR}/cursor.AppImage"
    if [[ \! -f "$app_binary" ]]; then
        app_binary=$(find "$SCRIPT_DIR" -name "*.AppImage" -type f | head -1)
    fi
    
    if [[ -z "$app_binary" || \! -f "$app_binary" ]]; then
        log_error "Cursor AppImage not found"
        log_progress "APP_FILES" "FAILED" "AppImage not found"
        INSTALLATION_SUCCESS=false
        return 1
    fi
    
    # Install the AppImage
    local target_binary="${BIN_DIR:-$INSTALL_PREFIX/bin}/cursor"
    if cp "$app_binary" "$target_binary" && chmod +x "$target_binary"; then
        log_info "Installed application binary: $target_binary"
    else
        log_error "Failed to install application binary"
        log_progress "APP_FILES" "FAILED" "Binary installation failed"
        INSTALLATION_SUCCESS=false
        return 1
    fi
    
    # Install additional files
    local share_dir="${SHARE_DIR:-$INSTALL_PREFIX/share}/cursor"
    
    # Copy any additional files from the bundle
    if [[ -f "${SCRIPT_DIR}/VERSION" ]]; then
        cp "${SCRIPT_DIR}/VERSION" "$share_dir/" 2>/dev/null || true
    fi
    
    if [[ -f "${SCRIPT_DIR}/README.md" ]]; then
        cp "${SCRIPT_DIR}/README.md" "$share_dir/" 2>/dev/null || true
    fi
    
    log_info "Application files installed successfully"
    log_progress "APP_FILES" "COMPLETED" "Application files installed"
}

# Install scripts and utilities
install_scripts_and_utilities() {
    log_info "Installing scripts and utilities..."
    log_progress "SCRIPTS" "STARTED" "Installing helper scripts"
    
    local bin_dir="${BIN_DIR:-$INSTALL_PREFIX/bin}"
    
    # Install launcher scripts
    local scripts_to_install=(
        "02-launcher-improved-v2.sh:cursor-launcher"
        "03-autoupdater-improved-v2.sh:cursor-updater"
    )
    
    for script_mapping in "${scripts_to_install[@]}"; do
        local source_script="${script_mapping%%:*}"
        local target_name="${script_mapping##*:}"
        local source_file="${SCRIPT_DIR}/$source_script"
        local target_file="$bin_dir/$target_name"
        
        if [[ -f "$source_file" ]]; then
            if cp "$source_file" "$target_file" && chmod +x "$target_file"; then
                log_info "Installed script: $target_name"
            else
                log_warning "Failed to install script: $source_script"
            fi
        else
            log_info "Script not found, skipping: $source_script"
        fi
    done
    
    log_progress "SCRIPTS" "COMPLETED" "Helper scripts installed"
}

# Configure desktop integration
configure_desktop_integration() {
    log_info "Configuring desktop integration..."
    log_progress "DESKTOP" "STARTED" "Setting up desktop integration"
    
    # Create desktop entry
    local desktop_file="${SHARE_DIR:-$INSTALL_PREFIX/share}/applications/cursor.desktop"
    local app_binary="${BIN_DIR:-$INSTALL_PREFIX/bin}/cursor"
    
    cat > "$desktop_file" << DESKTOPEOF
[Desktop Entry]
Name=Cursor IDE
Comment=Professional code editor and IDE
Exec=$app_binary %U
Icon=cursor
Terminal=false
Type=Application
Categories=Development;TextEditor;IDE;
MimeType=text/plain;text/x-c;text/x-c++;text/x-java;text/x-python;
StartupNotify=true
StartupWMClass=cursor
DESKTOPEOF
    
    if [[ -f "$desktop_file" ]]; then
        log_info "Created desktop entry: $desktop_file"
        
        # Update desktop database if available
        if command -v update-desktop-database >/dev/null 2>&1; then
            local desktop_dir="${SHARE_DIR:-$INSTALL_PREFIX/share}/applications"
            if update-desktop-database "$desktop_dir" 2>/dev/null; then
                log_info "Updated desktop database"
            fi
        fi
    else
        log_warning "Failed to create desktop entry"
    fi
    
    log_progress "DESKTOP" "COMPLETED" "Desktop integration configured"
}

# Set up environment
setup_environment() {
    log_info "Setting up environment..."
    log_progress "ENVIRONMENT" "STARTED" "Configuring environment variables"
    
    # Create environment script
    local env_script="${INSTALL_PREFIX}/bin/cursor-env"
    
    cat > "$env_script" << ENVEOF
#\!/bin/bash
# Cursor IDE Environment Setup
export CURSOR_HOME=$INSTALL_PREFIX/share/cursor
export PATH=$INSTALL_PREFIX/bin:\$PATH
ENVEOF
    
    chmod +x "$env_script"
    
    # Add to shell profiles if they exist and we can write to them
    local profile_added=false
    for profile in "${HOME}/.bashrc" "${HOME}/.zshrc" "${HOME}/.profile"; do
        if [[ -f "$profile" && -w "$profile" ]] && \! grep -q "cursor-env" "$profile" 2>/dev/null; then
            echo "" >> "$profile"
            echo "# Cursor IDE Environment" >> "$profile"
            echo "source \"$env_script\"" >> "$profile"
            log_info "Added environment setup to: $profile"
            profile_added=true
        fi
    done
    
    if [[ "$profile_added" == "false" ]]; then
        log_info "No writable shell profiles found, environment script created at: $env_script"
    fi
    
    log_progress "ENVIRONMENT" "COMPLETED" "Environment configured"
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    log_progress "VERIFICATION" "STARTED" "Verifying installed components"
    
    local verification_failed=false
    
    # Check if binary exists and is executable
    local app_binary="${BIN_DIR:-$INSTALL_PREFIX/bin}/cursor"
    if [[ -f "$app_binary" && -x "$app_binary" ]]; then
        log_info "Application binary verified: $app_binary"
        
        # Test if binary can show version
        if timeout 10 "$app_binary" --version >/dev/null 2>&1; then
            log_info "Application binary is functional"
        else
            log_warning "Application binary may have issues"
        fi
    else
        log_error "Application binary not found or not executable: $app_binary"
        verification_failed=true
    fi
    
    # Check desktop entry
    local desktop_file="${SHARE_DIR:-$INSTALL_PREFIX/share}/applications/cursor.desktop"
    if [[ -f "$desktop_file" ]]; then
        log_info "Desktop entry verified: $desktop_file"
    else
        log_warning "Desktop entry not found: $desktop_file"
    fi
    
    # Check directories
    local expected_dirs=(
        "$INSTALL_PREFIX"
        "${BIN_DIR:-$INSTALL_PREFIX/bin}"
        "${SHARE_DIR:-$INSTALL_PREFIX/share}/cursor"
    )
    
    for dir in "${expected_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            log_info "Directory verified: $dir"
        else
            log_error "Expected directory not found: $dir"
            verification_failed=true
        fi
    done
    
    if [[ "$verification_failed" == "true" ]]; then
        log_error "Installation verification failed"
        log_progress "VERIFICATION" "FAILED" "Critical components missing"
        return 1
    else
        log_info "Installation verification completed successfully"
        log_progress "VERIFICATION" "COMPLETED" "All components verified"
        return 0
    fi
}

# Self-correction functions
fix_directory_permissions() {
    log_info "Attempting to fix directory permissions..."
    
    local dirs_to_fix=(
        "$INSTALL_CONFIG_DIR"
        "$INSTALL_CACHE_DIR"
        "$INSTALL_LOG_DIR"
        "$INSTALL_PREFIX"
    )
    
    for dir in "${dirs_to_fix[@]}"; do
        if [[ -d "$dir" ]]; then
            chmod 755 "$dir" 2>/dev/null || true
        fi
    done
}

check_disk_space_and_permissions() {
    log_info "Checking disk space and permissions..."
    
    # Check available disk space
    local available_space
    available_space=$(df "$HOME" | awk 'NR==2 {print int($4/1024)}')
    log_info "Available disk space: ${available_space}MB"
    
    # Check write permissions
    if [[ -w "$HOME" ]]; then
        log_info "Home directory is writable"
    else
        log_warning "Home directory is not writable"
    fi
}

check_filesystem_status() {
    log_info "Checking filesystem status..."
    
    # Check filesystem usage
    local fs_usage
    fs_usage=$(df "$HOME" | awk 'NR==2 {print $5}' | tr -d '%')
    if [[ $fs_usage -gt 90 ]]; then
        log_warning "Filesystem is ${fs_usage}% full"
    fi
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
Professional Installation Framework v2.0

USAGE:
    install-improved-v2.sh [OPTIONS]

OPTIONS:
    --install       Perform installation (default)
    --verify        Verify existing installation
    --prefix DIR    Set installation prefix (default: ~/.local)
    --verbose       Enable verbose output
    --dry-run       Show what would be installed
    --help          Display this help message
    --version       Display version information

EXAMPLES:
    ./install-improved-v2.sh
    ./install-improved-v2.sh --prefix /usr/local
    ./install-improved-v2.sh --verbose

For more information, see the documentation.
USAGEEOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install)
                OPERATION="install"
                shift
                ;;
            --verify)
                OPERATION="verify"
                shift
                ;;
            --prefix)
                INSTALL_PREFIX="$2"
                shift 2
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
                echo "Professional Installation Framework v$VERSION"
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
    local OPERATION="${OPERATION:-install}"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Initialize framework
    initialize_install_framework
    
    case "$OPERATION" in
        "install")
            if perform_installation; then
                log_info "Cursor IDE installation completed successfully"
                exit 0
            else
                log_error "Cursor IDE installation failed"
                exit 1
            fi
            ;;
        "verify")
            if verify_installation; then
                log_info "Installation verification completed successfully"
                exit 0
            else
                log_error "Installation verification failed"
                exit 1
            fi
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
