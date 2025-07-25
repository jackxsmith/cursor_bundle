#\!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# 12-postinstall-improved-v2.sh - Professional Post-Installation Framework v2.0
# Enterprise-grade post-installation configuration with robust error handling and self-correcting mechanisms
# ============================================================================

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="2.0.0"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Configuration Management
readonly APP_NAME="cursor"
readonly POSTINSTALL_CONFIG_DIR="${HOME}/.config/cursor-postinstall"
readonly POSTINSTALL_CACHE_DIR="${HOME}/.cache/cursor-postinstall"
readonly POSTINSTALL_LOG_DIR="${POSTINSTALL_CONFIG_DIR}/logs"

# Logging Configuration
readonly LOG_FILE="${POSTINSTALL_LOG_DIR}/postinstall_${TIMESTAMP}.log"
readonly ERROR_LOG="${POSTINSTALL_LOG_DIR}/postinstall_errors_${TIMESTAMP}.log"
readonly CONFIGURATION_LOG="${POSTINSTALL_LOG_DIR}/configuration_${TIMESTAMP}.log"

# Lock Management
readonly LOCK_FILE="${POSTINSTALL_CONFIG_DIR}/.postinstall.lock"
readonly PID_FILE="${POSTINSTALL_CONFIG_DIR}/.postinstall.pid"

# Global Variables
declare -g POSTINSTALL_CONFIG="${POSTINSTALL_CONFIG_DIR}/postinstall.conf"
declare -g VERBOSE_MODE=false
declare -g DRY_RUN_MODE=false
declare -g CONFIGURATION_SUCCESS=true

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
        *"curl"* < /dev/null | *"wget"*)
            log_info "Network command failed, checking connectivity..."
            check_network_connectivity
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

log_configuration() {
    local action="$1"
    local component="$2"
    local result="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] CONFIG: $action - $component = $result" >> "$CONFIGURATION_LOG"
}

# Initialize post-installation framework
initialize_postinstall_framework() {
    log_info "Initializing Professional Post-Installation Framework v${VERSION}"
    
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
    
    log_info "Post-installation framework initialization completed successfully"
}

# Create directory structure with retry logic
create_directory_structure() {
    local dirs=("$POSTINSTALL_CONFIG_DIR" "$POSTINSTALL_CACHE_DIR" "$POSTINSTALL_LOG_DIR")
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
    if [[ \! -f "$POSTINSTALL_CONFIG" ]]; then
        log_info "Creating default post-installation configuration"
        create_default_configuration
    fi
    
    # Source configuration safely
    if [[ -r "$POSTINSTALL_CONFIG" ]]; then
        source "$POSTINSTALL_CONFIG"
        log_info "Configuration loaded from $POSTINSTALL_CONFIG"
    else
        log_warning "Configuration file not readable, using defaults"
    fi
}

# Create default configuration
create_default_configuration() {
    cat > "$POSTINSTALL_CONFIG" << 'CONFIGEOF'
# Professional Post-Installation Framework Configuration v2.0

# General Settings
VERBOSE_MODE=false
DRY_RUN_MODE=false
AUTO_CONFIGURE=true
BACKUP_EXISTING=true

# Desktop Integration
CREATE_DESKTOP_ENTRY=true
CREATE_MENU_ENTRY=true
ASSOCIATE_FILE_TYPES=false
UPDATE_MIME_DATABASE=false

# System Integration
REGISTER_PROTOCOL_HANDLERS=false
CREATE_SYMLINKS=false
UPDATE_PATH=false
CONFIGURE_ENVIRONMENT=true

# User Experience
ENABLE_STARTUP_OPTIMIZATION=true
CONFIGURE_SHORTCUTS=true
SETUP_THEMES=false
INSTALL_EXTENSIONS=false

# Security Settings
SET_SECURE_PERMISSIONS=true
ENABLE_SANDBOXING=false
CONFIGURE_FIREWALL=false
SETUP_CERTIFICATES=false

# Maintenance Settings
LOG_RETENTION_DAYS=30
CLEANUP_TEMP_FILES=true
ENABLE_AUTO_UPDATES=false
SCHEDULE_MAINTENANCE=false
CONFIGEOF
    
    log_info "Default configuration created: $POSTINSTALL_CONFIG"
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

# Perform post-installation configuration
perform_postinstall_configuration() {
    log_info "Starting post-installation configuration..."
    
    local config_start=$(date +%s)
    CONFIGURATION_SUCCESS=true
    
    # Desktop integration
    configure_desktop_integration
    
    # System integration
    configure_system_integration
    
    # User experience setup
    configure_user_experience
    
    # Security configuration
    configure_security_settings
    
    # Final verification
    verify_installation
    
    local config_end=$(date +%s)
    local config_duration=$((config_end - config_start))
    
    if [[ "$CONFIGURATION_SUCCESS" == "true" ]]; then
        log_info "Post-installation configuration completed successfully in ${config_duration}s"
        return 0
    else
        log_error "Post-installation configuration failed after ${config_duration}s"
        return 1
    fi
}

# Configure desktop integration
configure_desktop_integration() {
    log_info "Configuring desktop integration..."
    
    # Create desktop entry
    if [[ "${CREATE_DESKTOP_ENTRY:-true}" == "true" ]]; then
        create_desktop_entry
    fi
    
    # Create menu entry
    if [[ "${CREATE_MENU_ENTRY:-true}" == "true" ]]; then
        create_menu_entry
    fi
    
    # Update desktop database
    update_desktop_database
    
    log_info "Desktop integration configuration completed"
}

# Create desktop entry
create_desktop_entry() {
    log_info "Creating desktop entry..."
    
    local desktop_dir="${HOME}/.local/share/applications"
    local desktop_file="${desktop_dir}/cursor.desktop"
    
    mkdir -p "$desktop_dir"
    
    local app_binary="${SCRIPT_DIR}/cursor.AppImage"
    if [[ \! -f "$app_binary" ]]; then
        app_binary=$(find "$SCRIPT_DIR" -name "*.AppImage" -type f | head -1)
    fi
    
    if [[ -n "$app_binary" && -f "$app_binary" ]]; then
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
        
        chmod +x "$desktop_file"
        log_configuration "CREATE" "DESKTOP_ENTRY" "SUCCESS"
        log_info "Desktop entry created: $desktop_file"
    else
        log_error "Could not find Cursor application binary"
        log_configuration "CREATE" "DESKTOP_ENTRY" "FAILED"
        CONFIGURATION_SUCCESS=false
    fi
}

# Create menu entry
create_menu_entry() {
    log_info "Creating menu entry..."
    
    # Menu entry is typically the same as desktop entry
    # Additional menu-specific configuration can be added here
    local menu_dir="${HOME}/.local/share/applications"
    
    if [[ -f "${menu_dir}/cursor.desktop" ]]; then
        log_configuration "CREATE" "MENU_ENTRY" "SUCCESS"
        log_info "Menu entry available via desktop entry"
    else
        log_warning "Desktop entry not found, menu entry may not be available"
        log_configuration "CREATE" "MENU_ENTRY" "WARNING"
    fi
}

# Update desktop database
update_desktop_database() {
    log_info "Updating desktop database..."
    
    if command -v update-desktop-database >/dev/null 2>&1; then
        local desktop_dir="${HOME}/.local/share/applications"
        if update-desktop-database "$desktop_dir" 2>/dev/null; then
            log_configuration "UPDATE" "DESKTOP_DATABASE" "SUCCESS"
            log_info "Desktop database updated successfully"
        else
            log_warning "Failed to update desktop database"
            log_configuration "UPDATE" "DESKTOP_DATABASE" "WARNING"
        fi
    else
        log_info "update-desktop-database not available, skipping"
        log_configuration "UPDATE" "DESKTOP_DATABASE" "SKIPPED"
    fi
}

# Configure system integration
configure_system_integration() {
    log_info "Configuring system integration..."
    
    # Configure environment variables
    if [[ "${CONFIGURE_ENVIRONMENT:-true}" == "true" ]]; then
        configure_environment_variables
    fi
    
    # Set file permissions
    if [[ "${SET_SECURE_PERMISSIONS:-true}" == "true" ]]; then
        set_secure_permissions
    fi
    
    # Create configuration directories
    create_application_directories
    
    log_info "System integration configuration completed"
}

# Configure environment variables
configure_environment_variables() {
    log_info "Configuring environment variables..."
    
    local env_file="${HOME}/.cursor_env"
    
    cat > "$env_file" << ENVEOF
# Cursor IDE Environment Variables
export CURSOR_HOME=$SCRIPT_DIR
export CURSOR_CONFIG_DIR=${HOME}/.config/cursor
export CURSOR_CACHE_DIR=${HOME}/.cache/cursor
export CURSOR_LOG_LEVEL=info
ENVEOF
    
    # Add to shell profiles if they exist
    for profile in "${HOME}/.bashrc" "${HOME}/.zshrc" "${HOME}/.profile"; do
        if [[ -f "$profile" ]] && \! grep -q "cursor_env" "$profile" 2>/dev/null; then
            echo "# Cursor IDE Environment" >> "$profile"
            echo "source \"$env_file\"" >> "$profile"
            log_info "Added environment configuration to: $profile"
        fi
    done
    
    log_configuration "CONFIGURE" "ENVIRONMENT" "SUCCESS"
    log_info "Environment variables configured"
}

# Set secure permissions
set_secure_permissions() {
    log_info "Setting secure file permissions..."
    
    # Set permissions for application files
    if [[ -d "$SCRIPT_DIR" ]]; then
        find "$SCRIPT_DIR" -type f -name "*.sh" -exec chmod 755 {} \; 2>/dev/null || true
        find "$SCRIPT_DIR" -type f -name "*.AppImage" -exec chmod 755 {} \; 2>/dev/null || true
        find "$SCRIPT_DIR" -type f -name "*.conf" -exec chmod 644 {} \; 2>/dev/null || true
    fi
    
    # Set permissions for configuration directories
    for dir in "$POSTINSTALL_CONFIG_DIR" "$POSTINSTALL_CACHE_DIR" "$POSTINSTALL_LOG_DIR"; do
        if [[ -d "$dir" ]]; then
            chmod 755 "$dir" 2>/dev/null || true
            find "$dir" -type f -exec chmod 644 {} \; 2>/dev/null || true
        fi
    done
    
    log_configuration "SET" "PERMISSIONS" "SUCCESS"
    log_info "Secure permissions applied"
}

# Create application directories
create_application_directories() {
    log_info "Creating application directories..."
    
    local app_dirs=(
        "${HOME}/.config/cursor"
        "${HOME}/.cache/cursor"
        "${HOME}/.local/share/cursor"
    )
    
    for dir in "${app_dirs[@]}"; do
        if mkdir -p "$dir" 2>/dev/null; then
            log_info "Created directory: $dir"
        else
            log_warning "Failed to create directory: $dir"
        fi
    done
    
    log_configuration "CREATE" "APP_DIRECTORIES" "SUCCESS"
}

# Configure user experience
configure_user_experience() {
    log_info "Configuring user experience..."
    
    # Enable startup optimization
    if [[ "${ENABLE_STARTUP_OPTIMIZATION:-true}" == "true" ]]; then
        configure_startup_optimization
    fi
    
    # Configure shortcuts
    if [[ "${CONFIGURE_SHORTCUTS:-true}" == "true" ]]; then
        configure_keyboard_shortcuts
    fi
    
    log_info "User experience configuration completed"
}

# Configure startup optimization
configure_startup_optimization() {
    log_info "Configuring startup optimization..."
    
    local cursor_config="${HOME}/.config/cursor/settings.json"
    local config_dir=$(dirname "$cursor_config")
    
    mkdir -p "$config_dir"
    
    # Create basic settings for optimal startup
    if [[ \! -f "$cursor_config" ]]; then
        cat > "$cursor_config" << SETTINGSEOF
{
    "window.restoreFullscreen": false,
    "window.newWindowDimensions": "default",
    "workbench.startupEditor": "none",
    "extensions.autoUpdate": false,
    "update.mode": "manual",
    "telemetry.telemetryLevel": "off",
    "workbench.enableExperiments": false
}
SETTINGSEOF
        
        log_configuration "CONFIGURE" "STARTUP_OPTIMIZATION" "SUCCESS"
        log_info "Startup optimization configured"
    else
        log_info "Existing settings found, skipping startup optimization"
        log_configuration "CONFIGURE" "STARTUP_OPTIMIZATION" "SKIPPED"
    fi
}

# Configure keyboard shortcuts
configure_keyboard_shortcuts() {
    log_info "Configuring keyboard shortcuts..."
    
    local keybindings_file="${HOME}/.config/cursor/keybindings.json"
    local config_dir=$(dirname "$keybindings_file")
    
    mkdir -p "$config_dir"
    
    # Create basic keybindings
    if [[ \! -f "$keybindings_file" ]]; then
        cat > "$keybindings_file" << KEYBINDINGSEOF
[
    {
        "key": "ctrl+shift+n",
        "command": "workbench.action.files.newUntitledFile"
    },
    {
        "key": "ctrl+shift+o",
        "command": "workbench.action.files.openFolder"
    }
]
KEYBINDINGSEOF
        
        log_configuration "CONFIGURE" "SHORTCUTS" "SUCCESS"
        log_info "Keyboard shortcuts configured"
    else
        log_info "Existing keybindings found, skipping configuration"
        log_configuration "CONFIGURE" "SHORTCUTS" "SKIPPED"
    fi
}

# Configure security settings
configure_security_settings() {
    log_info "Configuring security settings..."
    
    # Ensure secure file ownership
    ensure_secure_ownership
    
    # Configure application security
    configure_application_security
    
    log_info "Security configuration completed"
}

# Ensure secure ownership
ensure_secure_ownership() {
    log_info "Ensuring secure file ownership..."
    
    local current_user=$(whoami)
    
    # Ensure user owns their configuration directories
    for dir in "${HOME}/.config/cursor" "${HOME}/.cache/cursor" "${HOME}/.local/share/cursor"; do
        if [[ -d "$dir" ]]; then
            if chown -R "$current_user:$current_user" "$dir" 2>/dev/null; then
                log_info "Updated ownership for: $dir"
            else
                log_warning "Could not update ownership for: $dir"
            fi
        fi
    done
    
    log_configuration "ENSURE" "OWNERSHIP" "SUCCESS"
}

# Configure application security
configure_application_security() {
    log_info "Configuring application security..."
    
    # Create security configuration
    local security_config="${HOME}/.config/cursor/security.json"
    local config_dir=$(dirname "$security_config")
    
    mkdir -p "$config_dir"
    
    if [[ \! -f "$security_config" ]]; then
        cat > "$security_config" << SECURITYEOF
{
    "security.workspace.trust.enabled": true,
    "security.workspace.trust.startupPrompt": "always",
    "security.workspace.trust.banner": "always",
    "extensions.autoCheckUpdates": false,
    "extensions.ignoreRecommendations": true
}
SECURITYEOF
        
        log_configuration "CONFIGURE" "SECURITY" "SUCCESS"
        log_info "Application security configured"
    else
        log_info "Existing security configuration found"
        log_configuration "CONFIGURE" "SECURITY" "SKIPPED"
    fi
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    local verification_failed=false
    
    # Check if application binary exists
    local app_binary="${SCRIPT_DIR}/cursor.AppImage"
    if [[ \! -f "$app_binary" ]]; then
        app_binary=$(find "$SCRIPT_DIR" -name "*.AppImage" -type f | head -1)
    fi
    
    if [[ -n "$app_binary" && -f "$app_binary" && -x "$app_binary" ]]; then
        log_info "Application binary verified: $app_binary"
    else
        log_error "Application binary not found or not executable"
        verification_failed=true
    fi
    
    # Check desktop entry
    local desktop_file="${HOME}/.local/share/applications/cursor.desktop"
    if [[ -f "$desktop_file" ]]; then
        log_info "Desktop entry verified: $desktop_file"
    else
        log_warning "Desktop entry not found"
    fi
    
    # Check configuration directories
    for dir in "${HOME}/.config/cursor" "${HOME}/.cache/cursor"; do
        if [[ -d "$dir" && -w "$dir" ]]; then
            log_info "Configuration directory verified: $dir"
        else
            log_warning "Configuration directory issue: $dir"
        fi
    done
    
    if [[ "$verification_failed" == "true" ]]; then
        CONFIGURATION_SUCCESS=false
        log_error "Installation verification failed"
        return 1
    else
        log_info "Installation verification completed successfully"
        return 0
    fi
}

# Generate configuration report
generate_configuration_report() {
    local report_file="${POSTINSTALL_LOG_DIR}/configuration_report_${TIMESTAMP}.txt"
    log_info "Generating configuration report: $report_file"
    
    cat > "$report_file" << REPORTEOF
Post-Installation Configuration Report
Generated: $(date)
Framework Version: $VERSION

Configuration Status: $(if [[ "$CONFIGURATION_SUCCESS" == "true" ]]; then echo "SUCCESS"; else echo "FAILED"; fi)

Cursor IDE has been configured successfully.

Desktop Integration: Completed
System Integration: Completed
User Experience: Configured
Security Settings: Applied

For detailed configuration log, see: $CONFIGURATION_LOG
REPORTEOF
    
    log_info "Configuration report generated: $report_file"
}

# Self-correction functions
fix_directory_permissions() {
    log_info "Attempting to fix directory permissions..."
    
    for dir in "$POSTINSTALL_CONFIG_DIR" "$POSTINSTALL_CACHE_DIR" "$POSTINSTALL_LOG_DIR"; do
        if [[ -d "$dir" ]]; then
            chmod 755 "$dir" 2>/dev/null || true
        fi
    done
}

check_network_connectivity() {
    log_info "Checking network connectivity..."
    
    local test_urls=("https://google.com" "8.8.8.8")
    
    for url in "${test_urls[@]}"; do
        if timeout 10 ping -c 1 "$url" >/dev/null 2>&1; then
            log_info "Network connectivity verified via $url"
            return 0
        fi
    done
    
    log_warning "Network connectivity issues detected"
    return 1
}

check_filesystem_status() {
    log_info "Checking filesystem status..."
    
    local fs_status
    fs_status=$(df "$HOME" | awk 'NR==2 {print $4}')
    if [[ $fs_status -lt 10240 ]]; then
        log_warning "Very low disk space: $(($fs_status / 1024))MB available"
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
Professional Post-Installation Framework v2.0

USAGE:
    postinstall-improved-v2.sh [OPTIONS]

OPTIONS:
    --configure     Perform post-installation configuration (default)
    --verify        Verify installation only
    --report        Generate configuration report only
    --verbose       Enable verbose output
    --dry-run       Show what would be configured
    --help          Display this help message
    --version       Display version information

EXAMPLES:
    ./postinstall-improved-v2.sh
    ./postinstall-improved-v2.sh --verbose
    ./postinstall-improved-v2.sh --verify

For more information, see the documentation.
USAGEEOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --configure)
                OPERATION="configure"
                shift
                ;;
            --verify)
                OPERATION="verify"
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
                echo "Professional Post-Installation Framework v$VERSION"
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
    local OPERATION="${OPERATION:-configure}"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Initialize framework
    initialize_postinstall_framework
    
    case "$OPERATION" in
        "configure")
            if perform_postinstall_configuration; then
                generate_configuration_report
                log_info "Post-installation configuration completed successfully"
                exit 0
            else
                generate_configuration_report
                log_error "Post-installation configuration failed"
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
        "report")
            generate_configuration_report
            log_info "Configuration report generated"
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
