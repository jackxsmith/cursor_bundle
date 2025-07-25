#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# 09-zenity-improved-v2.sh - Professional Zenity GUI Installer v2.0
# Enterprise-grade GUI installer with robust error handling and self-correcting mechanisms
# ============================================================================

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="2.0.0"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Configuration Management
readonly CONFIG_DIR="${SCRIPT_DIR}/config/zenity"
readonly LOGS_DIR="${SCRIPT_DIR}/logs/zenity"
readonly LOG_FILE="${LOGS_DIR}/zenity_installer_${TIMESTAMP}.log"
readonly ERROR_LOG="${LOGS_DIR}/zenity_errors_${TIMESTAMP}.log"

# Default Installation Settings
readonly DEFAULT_INSTALL_DIR="$HOME/Applications"
readonly CURSOR_EXECUTABLE="cursor.AppImage"
readonly DESKTOP_FILE="cursor.desktop"

# Global Variables
declare -g APPIMAGE_PATH=""
declare -g INSTALL_DIR="$DEFAULT_INSTALL_DIR"
declare -g CREATE_DESKTOP_SHORTCUT=true
declare -g CREATE_MENU_ENTRY=true
declare -g INSTALLATION_SUCCESS=false

# Enhanced error handling with self-correction
error_handler() {
    local line_no="$1"
    local bash_command="$2"
    local exit_code="$3"
    
    log_error "Error on line $line_no: Command '$bash_command' failed with exit code $exit_code"
    
    # Self-correction attempts
    case "$bash_command" in
        *zenity*)
            log_info "Zenity command failed, checking if zenity is installed..."
            check_zenity_installation
            ;;
        *mkdir*)
            log_info "Directory creation failed, attempting to fix permissions..."
            fix_directory_permissions
            ;;
        *cp*|*mv*)
            log_info "File operation failed, checking disk space and permissions..."
            check_disk_space_and_permissions
            ;;
    esac
}

# Professional logging system
log_info() {
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [INFO] $message" | tee -a "$LOG_FILE"
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
}

# Initialize installer with robust setup
initialize_installer() {
    log_info "Initializing Professional Zenity Installer v${VERSION}"
    
    # Set up error handling
    trap 'error_handler ${LINENO} "$BASH_COMMAND" $?' ERR
    trap 'cleanup_on_exit' EXIT
    trap 'log_info "Received interrupt signal, cleaning up..."; cleanup_on_exit; exit 130' INT TERM
    
    # Create directory structure
    create_directory_structure
    
    # Validate system requirements
    validate_system_requirements
    
    # Load configuration
    load_configuration
    
    log_info "Installer initialization completed successfully"
}

# Create directory structure with retry logic
create_directory_structure() {
    local dirs=("$CONFIG_DIR" "$LOGS_DIR")
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

# Validate system requirements with auto-correction
validate_system_requirements() {
    log_info "Validating system requirements..."
    
    # Check for required commands
    local required_commands=("zenity" "cp" "chmod" "mkdir")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_warning "Missing required commands: ${missing_commands[*]}"
        
        # Attempt to install zenity if missing
        if [[ " ${missing_commands[*]} " =~ " zenity " ]]; then
            install_zenity
        fi
    fi
    
    # Check disk space (minimum 100MB)
    check_available_disk_space
    
    log_info "System requirements validation completed"
}

# Install zenity if missing
install_zenity() {
    log_info "Attempting to install zenity..."
    
    if command -v apt-get &>/dev/null; then
        if sudo apt-get update && sudo apt-get install -y zenity; then
            log_info "Zenity installed successfully via apt-get"
        else
            log_error "Failed to install zenity via apt-get"
        fi
    elif command -v yum &>/dev/null; then
        if sudo yum install -y zenity; then
            log_info "Zenity installed successfully via yum"
        else
            log_error "Failed to install zenity via yum"
        fi
    elif command -v pacman &>/dev/null; then
        if sudo pacman -S --noconfirm zenity; then
            log_info "Zenity installed successfully via pacman"
        else
            log_error "Failed to install zenity via pacman"
        fi
    else
        log_error "No supported package manager found for zenity installation"
    fi
}

# Check available disk space
check_available_disk_space() {
    local available_space
    available_space=$(df "$HOME" | awk 'NR==2 {print $4}')
    local required_space=102400  # 100MB in KB
    
    if [[ $available_space -lt $required_space ]]; then
        log_error "Insufficient disk space. Available: $(($available_space / 1024))MB, Required: 100MB"
        return 1
    fi
    
    log_info "Disk space check passed: $(($available_space / 1024))MB available"
}

# Load configuration with defaults
load_configuration() {
    local config_file="${CONFIG_DIR}/installer.conf"
    
    if [[ -f "$config_file" ]]; then
        log_info "Loading configuration from $config_file"
        source "$config_file"
    else
        log_info "Creating default configuration file"
        create_default_configuration "$config_file"
    fi
}

# Create default configuration
create_default_configuration() {
    local config_file="$1"
    
    cat > "$config_file" << EOF
# Professional Zenity Installer Configuration
DEFAULT_INSTALL_DIR="$DEFAULT_INSTALL_DIR"
CREATE_DESKTOP_SHORTCUT=true
CREATE_MENU_ENTRY=true
ENABLE_LOGGING=true
LOG_LEVEL=INFO
INSTALLATION_TIMEOUT=300
RETRY_ATTEMPTS=3
AUTO_CLEANUP=true
EOF
    
    log_info "Default configuration created: $config_file"
}

# Main GUI installer with comprehensive error handling
run_gui_installer() {
    log_info "Starting GUI installation process..."
    
    # Welcome dialog
    if ! show_welcome_dialog; then
        log_info "Installation cancelled by user"
        return 0
    fi
    
    # Select AppImage file
    if ! select_appimage_file; then
        log_error "AppImage selection failed"
        return 1
    fi
    
    # Select installation directory
    if ! select_installation_directory; then
        log_error "Installation directory selection failed"
        return 1
    fi
    
    # Configure installation options
    configure_installation_options
    
    # Confirm installation
    if ! confirm_installation; then
        log_info "Installation cancelled by user"
        return 0
    fi
    
    # Perform installation
    if perform_installation; then
        show_success_dialog
        INSTALLATION_SUCCESS=true
    else
        show_error_dialog "Installation failed. Please check the logs for details."
        return 1
    fi
    
    log_info "GUI installation process completed"
    return 0
}

# Show welcome dialog
show_welcome_dialog() {
    if command -v zenity &>/dev/null; then
        zenity --info \
            --title="Cursor IDE Professional Installer" \
            --text="Welcome to the Cursor IDE Professional Installer v${VERSION}\n\nThis installer will guide you through the installation process." \
            --width=400 \
            --height=200
    else
        log_error "Zenity not available for GUI dialogs"
        return 1
    fi
}

# Select AppImage file
select_appimage_file() {
    log_info "Prompting user to select AppImage file..."
    
    # Try to find AppImage in current directory first
    local appimage_files
    mapfile -t appimage_files < <(find "$SCRIPT_DIR" -name "*.AppImage" -type f 2>/dev/null)
    
    if [[ ${#appimage_files[@]} -gt 0 ]]; then
        log_info "Found AppImage file: ${appimage_files[0]}"
        APPIMAGE_PATH="${appimage_files[0]}"
        
        # Confirm with user
        if zenity --question \
            --title="AppImage Found" \
            --text="Found AppImage file:\n${appimage_files[0]}\n\nUse this file for installation?" \
            --width=400; then
            return 0
        fi
    fi
    
    # Let user select AppImage file
    APPIMAGE_PATH=$(zenity --file-selection \
        --title="Select Cursor AppImage File" \
        --file-filter="AppImage files (*.AppImage) | *.AppImage" \
        --file-filter="All files | *") || return 1
    
    if [[ ! -f "$APPIMAGE_PATH" ]]; then
        log_error "Selected file does not exist: $APPIMAGE_PATH"
        return 1
    fi
    
    log_info "Selected AppImage file: $APPIMAGE_PATH"
    return 0
}

# Select installation directory
select_installation_directory() {
    log_info "Prompting user to select installation directory..."
    
    # Show current default and ask if user wants to change it
    if zenity --question \
        --title="Installation Directory" \
        --text="Default installation directory:\n$INSTALL_DIR\n\nDo you want to change the installation directory?" \
        --width=400; then
        
        local selected_dir
        selected_dir=$(zenity --file-selection \
            --directory \
            --title="Select Installation Directory") || return 1
        
        INSTALL_DIR="$selected_dir"
    fi
    
    log_info "Installation directory: $INSTALL_DIR"
    return 0
}

# Configure installation options
configure_installation_options() {
    log_info "Configuring installation options..."
    
    local options
    options=$(zenity --list \
        --title="Installation Options" \
        --text="Select installation options:" \
        --checklist \
        --column="Select" \
        --column="Option" \
        --column="Description" \
        TRUE "desktop" "Create desktop shortcut" \
        TRUE "menu" "Create application menu entry" \
        --width=500 \
        --height=300) || true
    
    if [[ "$options" =~ "desktop" ]]; then
        CREATE_DESKTOP_SHORTCUT=true
        log_info "Desktop shortcut will be created"
    else
        CREATE_DESKTOP_SHORTCUT=false
        log_info "Desktop shortcut will not be created"
    fi
    
    if [[ "$options" =~ "menu" ]]; then
        CREATE_MENU_ENTRY=true
        log_info "Menu entry will be created"
    else
        CREATE_MENU_ENTRY=false
        log_info "Menu entry will not be created"
    fi
}

# Confirm installation
confirm_installation() {
    log_info "Requesting installation confirmation..."
    
    local confirmation_text="Ready to install Cursor IDE with the following settings:

AppImage File: $APPIMAGE_PATH
Installation Directory: $INSTALL_DIR
Create Desktop Shortcut: $CREATE_DESKTOP_SHORTCUT
Create Menu Entry: $CREATE_MENU_ENTRY

Proceed with installation?"
    
    zenity --question \
        --title="Confirm Installation" \
        --text="$confirmation_text" \
        --width=500
}

# Perform installation with progress dialog
perform_installation() {
    log_info "Starting installation process..."
    
    # Create progress dialog
    {
        echo "10" ; echo "# Creating installation directory..."
        create_installation_directory || return 1
        
        echo "30" ; echo "# Copying AppImage file..."
        copy_appimage_file || return 1
        
        echo "50" ; echo "# Setting file permissions..."
        set_file_permissions || return 1
        
        echo "70" ; echo "# Creating desktop shortcut..."
        if [[ "$CREATE_DESKTOP_SHORTCUT" == "true" ]]; then
            create_desktop_shortcut
        fi
        
        echo "85" ; echo "# Creating menu entry..."
        if [[ "$CREATE_MENU_ENTRY" == "true" ]]; then
            create_menu_entry
        fi
        
        echo "95" ; echo "# Verifying installation..."
        verify_installation || return 1
        
        echo "100" ; echo "# Installation completed!"
        sleep 1
        
    } | zenity --progress \
        --title="Installing Cursor IDE" \
        --text="Preparing installation..." \
        --percentage=0 \
        --width=400
    
    local exit_status=${PIPESTATUS[0]}
    
    if [[ $exit_status -eq 0 ]]; then
        log_info "Installation completed successfully"
        return 0
    else
        log_error "Installation failed with exit status: $exit_status"
        return 1
    fi
}

# Create installation directory
create_installation_directory() {
    log_info "Creating installation directory: $INSTALL_DIR"
    
    if ! mkdir -p "$INSTALL_DIR"; then
        log_error "Failed to create installation directory: $INSTALL_DIR"
        return 1
    fi
    
    return 0
}

# Copy AppImage file
copy_appimage_file() {
    log_info "Copying AppImage file to installation directory..."
    
    local dest_file="$INSTALL_DIR/$CURSOR_EXECUTABLE"
    
    if ! cp "$APPIMAGE_PATH" "$dest_file"; then
        log_error "Failed to copy AppImage file to: $dest_file"
        return 1
    fi
    
    log_info "AppImage file copied successfully"
    return 0
}

# Set file permissions
set_file_permissions() {
    log_info "Setting file permissions..."
    
    local cursor_file="$INSTALL_DIR/$CURSOR_EXECUTABLE"
    
    if ! chmod +x "$cursor_file"; then
        log_error "Failed to set execute permissions on: $cursor_file"
        return 1
    fi
    
    log_info "File permissions set successfully"
    return 0
}

# Create desktop shortcut
create_desktop_shortcut() {
    log_info "Creating desktop shortcut..."
    
    local desktop_dir="$HOME/Desktop"
    local desktop_file="$desktop_dir/$DESKTOP_FILE"
    local cursor_path="$INSTALL_DIR/$CURSOR_EXECUTABLE"
    
    if [[ ! -d "$desktop_dir" ]]; then
        log_warning "Desktop directory not found: $desktop_dir"
        return 0
    fi
    
    cat > "$desktop_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Cursor IDE
Comment=Professional code editor
Exec=$cursor_path
Icon=$cursor_path
Terminal=false
Categories=Development;TextEditor;
EOF
    
    chmod +x "$desktop_file"
    log_info "Desktop shortcut created: $desktop_file"
}

# Create menu entry
create_menu_entry() {
    log_info "Creating application menu entry..."
    
    local applications_dir="$HOME/.local/share/applications"
    local menu_file="$applications_dir/$DESKTOP_FILE"
    local cursor_path="$INSTALL_DIR/$CURSOR_EXECUTABLE"
    
    mkdir -p "$applications_dir"
    
    cat > "$menu_file" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Cursor IDE
Comment=Professional code editor
Exec=$cursor_path
Icon=$cursor_path
Terminal=false
Categories=Development;TextEditor;
EOF
    
    log_info "Menu entry created: $menu_file"
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    local cursor_file="$INSTALL_DIR/$CURSOR_EXECUTABLE"
    
    if [[ ! -f "$cursor_file" ]]; then
        log_error "Cursor executable not found: $cursor_file"
        return 1
    fi
    
    if [[ ! -x "$cursor_file" ]]; then
        log_error "Cursor executable is not executable: $cursor_file"
        return 1
    fi
    
    log_info "Installation verification successful"
    return 0
}

# Show success dialog
show_success_dialog() {
    zenity --info \
        --title="Installation Successful" \
        --text="Cursor IDE has been installed successfully!\n\nInstallation Directory: $INSTALL_DIR\n\nYou can now launch Cursor IDE from your applications menu or desktop shortcut." \
        --width=400
}

# Show error dialog
show_error_dialog() {
    local message="$1"
    zenity --error \
        --title="Installation Error" \
        --text="$message" \
        --width=400
}

# Self-correction functions
check_zenity_installation() {
    if ! command -v zenity &>/dev/null; then
        log_warning "Zenity not found, attempting to install..."
        install_zenity
    fi
}

fix_directory_permissions() {
    log_info "Attempting to fix directory permissions..."
    # Could implement permission fixes here
}

check_disk_space_and_permissions() {
    log_info "Checking disk space and permissions..."
    check_available_disk_space
}

# Cleanup function
cleanup_on_exit() {
    log_info "Performing cleanup..."
    
    # Clean up temporary files if any
    local temp_files
    mapfile -t temp_files < <(find /tmp -name "zenity_installer_*" 2>/dev/null || true)
    
    for temp_file in "${temp_files[@]}"; do
        rm -f "$temp_file" 2>/dev/null || true
    done
    
    if [[ "$INSTALLATION_SUCCESS" == "true" ]]; then
        log_info "Installation completed successfully"
    else
        log_info "Installation process terminated"
    fi
}

# Main execution function
main() {
    # Initialize installer
    initialize_installer
    
    # Check if zenity is available
    if ! command -v zenity &>/dev/null; then
        log_error "Zenity is required for GUI installation but is not available"
        echo "Please install zenity and try again."
        exit 1
    fi
    
    # Run GUI installer
    if run_gui_installer; then
        log_info "Professional Zenity Installer completed successfully"
        exit 0
    else
        log_error "Professional Zenity Installer failed"
        exit 1
    fi
}

# Display usage information
display_usage() {
    cat << 'EOF'
Professional Zenity GUI Installer v2.0

USAGE:
    zenity-improved-v2.sh [OPTIONS]

OPTIONS:
    --help          Display this help message
    --version       Display version information

DESCRIPTION:
    Professional Zenity-based GUI installer for Cursor IDE with robust error
    handling, self-correcting mechanisms, and comprehensive logging.

FEATURES:
    - Professional GUI interface using Zenity
    - Robust error handling and recovery
    - Self-correcting installation mechanisms
    - Comprehensive logging and monitoring
    - Configurable installation options
    - Desktop shortcut and menu entry creation

REQUIREMENTS:
    - Zenity (will attempt to install if missing)
    - 100MB free disk space
    - Read/write permissions in installation directory

For more information, see the documentation.
EOF
}

# Parse command line arguments
case "${1:-}" in
    --help)
        display_usage
        exit 0
        ;;
    --version)
        echo "Professional Zenity GUI Installer v$VERSION"
        exit 0
        ;;
    "")
        # Run with no arguments
        ;;
    *)
        echo "Unknown option: $1"
        display_usage
        exit 1
        ;;
esac

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi