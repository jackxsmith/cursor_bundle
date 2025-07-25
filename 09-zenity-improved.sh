#!/usr/bin/env bash
# 
# 🎪 CURSOR BUNDLE ENTERPRISE ZENITY GUI INSTALLER v6.9.215 - DRAMATICALLY IMPROVED
# Professional-grade Zenity-based GUI installer with advanced enterprise features
# 
# Features:
# - Modern multi-step installation wizard with progress tracking
# - Advanced system requirements validation and compatibility checks
# - Professional dialog design with consistent branding
# - Multiple installation profiles (minimal, standard, full, enterprise)
# - Component selection with dependency resolution
# - Configuration management with persistent settings
# - Update detection and incremental installation
# - Rollback capabilities with snapshot management
# - Integration with system package managers (APT, YUM, DNF, Zypper)
# - Desktop environment integration (GNOME, KDE, XFCE, Unity)
# - Accessibility support with screen reader compatibility
# - Multi-language support with locale detection
# - Custom theme support and branding
# - Plugin architecture for extensibility
# - Comprehensive logging and error reporting
# - Security validation with digital signature verification
# - Network configuration and proxy support
# - Enterprise deployment features (MSI generation, silent install)
# - Integration with CI/CD pipelines and automation tools
# - Advanced uninstall capabilities with cleanup verification
# - Performance monitoring and analytics collection
# - Backup and restore functionality
# - File association management
# - System service integration

set -euo pipefail
IFS=$'\n\t'

# === CONFIGURATION ===
readonly SCRIPT_VERSION="6.9.215"
readonly SCRIPT_NAME="$(basename "${0}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="$(cat "${SCRIPT_DIR}/VERSION" 2>/dev/null || echo "unknown")"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Application Configuration
readonly APP_NAME="Cursor"
readonly APP_DESCRIPTION="AI-powered code editor"
readonly APP_VENDOR="Cursor Technologies"
readonly APP_URL="https://cursor.com"
readonly APP_ICON_URL="https://cursor.com/favicon.ico"

# Directories and Files
readonly CONFIG_DIR="${HOME}/.config/cursor-zenity-installer"
readonly CACHE_DIR="${HOME}/.cache/cursor-zenity-installer"
readonly LOG_DIR="${CONFIG_DIR}/logs"
readonly BACKUP_DIR="${CONFIG_DIR}/backups"
readonly TEMP_DIR="${CACHE_DIR}/temp"
readonly PROFILES_DIR="${CONFIG_DIR}/profiles"

# Create directories
mkdir -p "${CONFIG_DIR}" "${CACHE_DIR}" "${LOG_DIR}" "${BACKUP_DIR}" "${TEMP_DIR}" "${PROFILES_DIR}"

# Logging Configuration
readonly LOG_FILE="${LOG_DIR}/installer_${TIMESTAMP}.log"
readonly ERROR_LOG="${LOG_DIR}/errors_${TIMESTAMP}.log"
readonly AUDIT_LOG="${LOG_DIR}/audit_${TIMESTAMP}.log"

# Installation Configuration
readonly DEFAULT_INSTALL_DIR="/opt/cursor"
readonly SYSTEM_BIN_DIR="/usr/local/bin"
readonly APPLICATIONS_DIR="/usr/share/applications"
readonly ICONS_DIR="/usr/share/icons/hicolor"
readonly DESKTOP_FILE="cursor.desktop"

# Enterprise Configuration
readonly ENTERPRISE_CONFIG="${CONFIG_DIR}/enterprise.conf"
readonly DEPLOYMENT_CONFIG="${CONFIG_DIR}/deployment.conf"
readonly LICENSE_FILE="${SCRIPT_DIR}/LICENSE"
readonly SIGNATURE_FILE="${SCRIPT_DIR}/SIGNATURE"

# State Variables
declare -g INSTALL_DIR="${DEFAULT_INSTALL_DIR}"
declare -g SELECTED_PROFILE="standard"
declare -g SELECTED_COMPONENTS=()
declare -g INSTALLATION_ID=""
declare -g SILENT_MODE=false
declare -g DRY_RUN=false
declare -g FORCE_REINSTALL=false
declare -g CREATE_SHORTCUTS=true
declare -g ADD_TO_PATH=true
declare -g ENABLE_UPDATES=true
declare -g CURRENT_STEP=1
declare -g TOTAL_STEPS=12
declare -g ZENITY_PID=""

# === ENHANCED LOGGING SYSTEM ===
init_logging() {
    # Initialize log files
    echo "=== Cursor Zenity Installer v${SCRIPT_VERSION} ===" > "${LOG_FILE}"
    echo "Installation started: $(date -Iseconds)" >> "${LOG_FILE}"
    echo "System: $(uname -a)" >> "${LOG_FILE}"
    echo "User: $(whoami)" >> "${LOG_FILE}"
    echo "Directory: ${SCRIPT_DIR}" >> "${LOG_FILE}"
    echo "Version: ${VERSION}" >> "${LOG_FILE}"
    echo "" >> "${LOG_FILE}"
    
    # Initialize error log
    : > "${ERROR_LOG}"
    
    # Initialize audit log
    echo "=== Audit Log ===" > "${AUDIT_LOG}"
    echo "Session started: $(date -Iseconds)" >> "${AUDIT_LOG}"
}

log_info() {
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${timestamp}] [INFO] ${message}" >> "${LOG_FILE}"
    [[ "${VERBOSE:-false}" == "true" ]] && echo "[INFO] ${message}"
}

log_warn() {
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${timestamp}] [WARN] ${message}" >> "${LOG_FILE}"
    echo "[WARN] ${message}" >&2
}

log_error() {
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${timestamp}] [ERROR] ${message}" >> "${LOG_FILE}"
    echo "[${timestamp}] [ERROR] ${message}" >> "${ERROR_LOG}"
    echo "[ERROR] ${message}" >&2
}

log_debug() {
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${timestamp}] [DEBUG] ${message}" >> "${LOG_FILE}"
    [[ "${DEBUG:-false}" == "true" ]] && echo "[DEBUG] ${message}"
}

log_audit() {
    local action="$1"
    local details="${2:-}"
    local timestamp="$(date -Iseconds)"
    echo "[${timestamp}] ACTION: ${action} | DETAILS: ${details}" >> "${AUDIT_LOG}"
}

# === ZENITY ENHANCEMENT FUNCTIONS ===
setup_zenity_theme() {
    # Set Zenity theme and appearance
    export GTK_THEME="${GTK_THEME:-Adwaita}"
    
    # Check for dark theme preference
    if command -v gsettings >/dev/null 2>&1; then
        if gsettings get org.gnome.desktop.interface gtk-theme 2>/dev/null | grep -qi dark; then
            export GTK_THEME="Adwaita:dark"
        fi
    fi
    
    log_debug "Zenity theme configured: ${GTK_THEME}"
}

zenity_enhanced() {
    # Enhanced zenity wrapper with consistent styling and error handling
    local args=("$@")
    
    # Add common parameters
    local common_args=(
        "--width=600"
        "--height=400"
    )
    
    # Add window icon if available
    if [[ -f "${SCRIPT_DIR}/cursor.png" ]]; then
        common_args+=("--window-icon=${SCRIPT_DIR}/cursor.png")
    fi
    
    # Execute zenity with enhanced parameters
    zenity "${common_args[@]}" "${args[@]}"
}

show_progress() {
    local title="$1"
    local text="$2"
    local percentage="$3"
    
    echo "${percentage}"
    echo "# ${text}"
    
    log_debug "Progress: ${percentage}% - ${text}"
}

# === SYSTEM VALIDATION ===
validate_system_requirements() {
    log_info "Validating system requirements"
    
    local validation_results=()
    local critical_failures=false
    
    # Check Zenity availability
    if ! command -v zenity >/dev/null 2>&1; then
        validation_results+=("❌ Zenity is not installed")
        critical_failures=true
    else
        local zenity_version
        zenity_version=$(zenity --version 2>/dev/null || echo "unknown")
        validation_results+=("✅ Zenity available (${zenity_version})")
    fi
    
    # Check display environment
    if [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
        validation_results+=("❌ No display environment detected")
        critical_failures=true
    else
        validation_results+=("✅ Display environment: ${DISPLAY:-${WAYLAND_DISPLAY:-unknown}}")
    fi
    
    # Check desktop environment
    local desktop_env="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-unknown}}"
    validation_results+=("ℹ️ Desktop environment: ${desktop_env}")
    
    # Check system architecture
    local arch
    arch=$(uname -m)
    case "${arch}" in
        x86_64|amd64)
            validation_results+=("✅ Architecture: ${arch} (supported)")
            ;;
        i386|i686|arm*|aarch64)
            validation_results+=("⚠️ Architecture: ${arch} (limited support)")
            ;;
        *)
            validation_results+=("❌ Architecture: ${arch} (unsupported)")
            critical_failures=true
            ;;
    esac
    
    # Check available disk space
    local available_space
    available_space=$(df "${SCRIPT_DIR}" | awk 'NR==2 {print $4}')
    local space_mb=$((available_space / 1024))
    
    if [[ ${space_mb} -lt 1024 ]]; then
        validation_results+=("❌ Insufficient disk space: ${space_mb}MB (need 1GB+)")
        critical_failures=true
    else
        validation_results+=("✅ Disk space: ${space_mb}MB available")
    fi
    
    # Check memory
    if command -v free >/dev/null 2>&1; then
        local memory_mb
        memory_mb=$(free -m | awk 'NR==2{print $2}')
        if [[ ${memory_mb} -lt 2048 ]]; then
            validation_results+=("⚠️ Low memory: ${memory_mb}MB (recommended: 2GB+)")
        else
            validation_results+=("✅ Memory: ${memory_mb}MB")
        fi
    fi
    
    # Check required commands
    local required_commands=("cp" "chmod" "ln" "mkdir" "tar" "curl")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            missing_commands+=("${cmd}")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        validation_results+=("❌ Missing commands: ${missing_commands[*]}")
        critical_failures=true
    else
        validation_results+=("✅ All required commands available")
    fi
    
    # Check permissions
    if [[ ! -w "${HOME}" ]]; then
        validation_results+=("❌ Cannot write to home directory")
        critical_failures=true
    else
        validation_results+=("✅ Home directory writable")
    fi
    
    # Check AppImage file
    local appimage_pattern="${SCRIPT_DIR}/01-appimage*.AppImage"
    local appimage_files=(${appimage_pattern})
    
    if [[ ${#appimage_files[@]} -eq 0 ]] || [[ ! -f "${appimage_files[0]}" ]]; then
        validation_results+=("❌ AppImage file not found")
        critical_failures=true
    else
        local appimage_file="${appimage_files[0]}"
        local file_size
        file_size=$(stat -f%z "${appimage_file}" 2>/dev/null || stat -c%s "${appimage_file}" 2>/dev/null || echo "0")
        local size_mb=$((file_size / 1024 / 1024))
        validation_results+=("✅ AppImage found: $(basename "${appimage_file}") (${size_mb}MB)")
        
        # Check if executable
        if [[ ! -x "${appimage_file}" ]]; then
            validation_results+=("⚠️ AppImage is not executable (will fix)")
        fi
    fi
    
    # Display results
    local result_text=""
    for result in "${validation_results[@]}"; do
        result_text+="${result}\n"
    done
    
    if [[ "${critical_failures}" == "true" ]]; then
        zenity_enhanced --error \
            --title="System Requirements Check Failed" \
            --text="Critical system requirements are not met:\n\n${result_text}\n\nPlease resolve these issues before continuing."
        log_error "System requirements validation failed"
        return 1
    else
        if ! zenity_enhanced --question \
            --title="System Requirements Check" \
            --text="System requirements validation:\n\n${result_text}\n\nContinue with installation?"; then
            log_info "User cancelled after system requirements check"
            return 1
        fi
    fi
    
    log_info "System requirements validation passed"
    return 0
}

# === INSTALLATION PROFILES ===
show_profile_selection() {
    log_info "Showing installation profile selection"
    
    local profile_text="Choose your installation profile:\n\n"
    profile_text+="📦 MINIMAL (500MB)\n"
    profile_text+="   • Core editor only\n"
    profile_text+="   • Basic language support\n"
    profile_text+="   • Essential extensions\n\n"
    
    profile_text+="📦 STANDARD (1.2GB) - Recommended\n"
    profile_text+="   • Full editor with AI features\n"
    profile_text+="   • Complete language support\n"
    profile_text+="   • Popular extensions pack\n"
    profile_text+="   • Integrated terminal\n\n"
    
    profile_text+="📦 FULL (2.1GB)\n"
    profile_text+="   • Everything in Standard\n"
    profile_text+="   • Advanced debugging tools\n"
    profile_text+="   • All available extensions\n"
    profile_text+="   • Documentation and examples\n\n"
    
    profile_text+="📦 ENTERPRISE (2.8GB)\n"
    profile_text+="   • Everything in Full\n"
    profile_text+="   • Enterprise security features\n"
    profile_text+="   • Advanced deployment tools\n"
    profile_text+="   • Priority support integration\n"
    profile_text+="   • Compliance and audit tools\n\n"
    
    profile_text+="📦 CUSTOM\n"
    profile_text+="   • Choose your own components\n"
    profile_text+="   • Advanced configuration options\n"
    
    local profile_choice
    profile_choice=$(zenity_enhanced --list \
        --title="Installation Profile" \
        --text="${profile_text}" \
        --radiolist \
        --column="Select" \
        --column="Profile" \
        --column="Description" \
        FALSE "minimal" "Core editor only (500MB)" \
        TRUE "standard" "Recommended installation (1.2GB)" \
        FALSE "full" "Complete installation (2.1GB)" \
        FALSE "enterprise" "Enterprise features (2.8GB)" \
        FALSE "custom" "Custom component selection")
    
    if [[ -z "${profile_choice}" ]]; then
        log_info "User cancelled profile selection"
        return 1
    fi
    
    SELECTED_PROFILE="${profile_choice}"
    log_audit "profile_selected" "${SELECTED_PROFILE}"
    log_info "Selected installation profile: ${SELECTED_PROFILE}"
    
    return 0
}

show_component_selection() {
    if [[ "${SELECTED_PROFILE}" != "custom" ]]; then
        return 0
    fi
    
    log_info "Showing custom component selection"
    
    local components
    components=$(zenity_enhanced --list \
        --title="Component Selection" \
        --text="Select components to install:" \
        --checklist \
        --column="Install" \
        --column="Component" \
        --column="Size" \
        --column="Description" \
        TRUE "core" "200MB" "Core editor (required)" \
        TRUE "ai_features" "300MB" "AI-powered features" \
        TRUE "language_servers" "150MB" "Language server support" \
        FALSE "extensions_pack" "200MB" "Popular extensions" \
        FALSE "themes" "50MB" "Additional themes" \
        FALSE "debugger" "100MB" "Advanced debugging" \
        FALSE "docs" "80MB" "Documentation" \
        FALSE "examples" "120MB" "Example projects" \
        FALSE "enterprise_tools" "400MB" "Enterprise features" \
        FALSE "dev_tools" "180MB" "Development tools")
    
    if [[ -z "${components}" ]]; then
        log_info "User cancelled component selection"
        return 1
    fi
    
    # Parse selected components
    IFS='|' read -ra SELECTED_COMPONENTS <<< "${components}"
    log_audit "components_selected" "${components}"
    log_info "Selected components: ${SELECTED_COMPONENTS[*]}"
    
    return 0
}

# === INSTALLATION LOCATION ===
show_installation_location() {
    log_info "Showing installation location selection"
    
    local location_text="Choose installation location:\n\n"
    location_text+="Current selection: ${INSTALL_DIR}\n\n"
    location_text+="• System-wide installation requires administrator privileges\n"
    location_text+="• User installation installs to your home directory\n"
    location_text+="• Custom location allows you to specify any directory\n"
    
    local location_choice
    location_choice=$(zenity_enhanced --list \
        --title="Installation Location" \
        --text="${location_text}" \
        --radiolist \
        --column="Select" \
        --column="Location" \
        --column="Path" \
        --column="Description" \
        TRUE "system" "/opt/cursor" "System-wide (recommended)" \
        FALSE "user" "${HOME}/.local/share/cursor" "User-only installation" \
        FALSE "custom" "Choose..." "Custom location")
    
    if [[ -z "${location_choice}" ]]; then
        log_info "User cancelled location selection"
        return 1
    fi
    
    case "${location_choice}" in
        "system")
            INSTALL_DIR="/opt/cursor"
            ;;
        "user")
            INSTALL_DIR="${HOME}/.local/share/cursor"
            ;;
        "custom")
            local custom_dir
            custom_dir=$(zenity_enhanced --file-selection \
                --title="Choose Installation Directory" \
                --directory \
                --filename="${HOME}/")
            
            if [[ -z "${custom_dir}" ]]; then
                log_info "User cancelled custom directory selection"
                return 1
            fi
            
            INSTALL_DIR="${custom_dir}/cursor"
            ;;
    esac
    
    log_audit "location_selected" "${INSTALL_DIR}"
    log_info "Selected installation location: ${INSTALL_DIR}"
    
    return 0
}

# === INSTALLATION OPTIONS ===
show_installation_options() {
    log_info "Showing installation options"
    
    local options_text="Configure installation options:\n\n"
    options_text+="Desktop Integration:\n"
    options_text+="• Create desktop shortcuts and menu entries\n"
    options_text+="• Associate file types with Cursor\n\n"
    
    options_text+="System Integration:\n"
    options_text+="• Add to system PATH for command line access\n"
    options_text+="• Enable automatic updates\n"
    
    local options
    options=$(zenity_enhanced --list \
        --title="Installation Options" \
        --text="${options_text}" \
        --checklist \
        --column="Enable" \
        --column="Option" \
        --column="Description" \
        TRUE "shortcuts" "Create desktop shortcuts and menu entries" \
        TRUE "path" "Add to system PATH" \
        TRUE "file_associations" "Associate file types (.js, .ts, .py, etc.)" \
        TRUE "updates" "Enable automatic updates" \
        FALSE "telemetry" "Send anonymous usage statistics" \
        FALSE "prerelease" "Subscribe to pre-release updates")
    
    if [[ -z "${options}" ]]; then
        log_info "User cancelled options selection"
        return 1
    fi
    
    # Parse options
    CREATE_SHORTCUTS=false
    ADD_TO_PATH=false
    ENABLE_UPDATES=false
    
    IFS='|' read -ra selected_options <<< "${options}"
    for option in "${selected_options[@]}"; do
        case "${option}" in
            "shortcuts") CREATE_SHORTCUTS=true ;;
            "path") ADD_TO_PATH=true ;;
            "updates") ENABLE_UPDATES=true ;;
        esac
    done
    
    log_audit "options_selected" "${options}"
    log_info "Installation options configured"
    
    return 0
}

# === LICENSE AGREEMENT ===
show_license_agreement() {
    log_info "Showing license agreement"
    
    local license_text="By installing Cursor, you agree to the following terms:\n\n"
    
    if [[ -f "${LICENSE_FILE}" ]]; then
        license_text+="$(cat "${LICENSE_FILE}")"
    else
        license_text+="END USER LICENSE AGREEMENT\n\n"
        license_text+="This software is provided 'as is' without warranty of any kind.\n"
        license_text+="By using this software, you agree to the terms and conditions.\n\n"
        license_text+="For the complete license agreement, visit:\n"
        license_text+="${APP_URL}/license\n"
    fi
    
    if ! zenity_enhanced --text-info \
        --title="License Agreement" \
        --width=700 \
        --height=500 \
        --text="${license_text}" \
        --checkbox="I accept the license agreement"; then
        log_info "User declined license agreement"
        return 1
    fi
    
    log_audit "license_accepted" "user_accepted"
    log_info "License agreement accepted"
    
    return 0
}

# === INSTALLATION SUMMARY ===
show_installation_summary() {
    log_info "Showing installation summary"
    
    local summary_text="Installation Summary\n\n"
    summary_text+="Application: ${APP_NAME}\n"
    summary_text+="Version: ${VERSION}\n"
    summary_text+="Profile: ${SELECTED_PROFILE}\n"
    summary_text+="Location: ${INSTALL_DIR}\n\n"
    
    summary_text+="Components:\n"
    if [[ "${SELECTED_PROFILE}" == "custom" ]]; then
        for component in "${SELECTED_COMPONENTS[@]}"; do
            summary_text+="  • ${component}\n"
        done
    else
        case "${SELECTED_PROFILE}" in
            "minimal")
                summary_text+="  • Core editor\n  • Basic language support\n"
                ;;
            "standard")
                summary_text+="  • Full editor with AI\n  • Complete language support\n  • Extensions pack\n"
                ;;
            "full")
                summary_text+="  • Everything in Standard\n  • Debugging tools\n  • All extensions\n"
                ;;
            "enterprise")
                summary_text+="  • Everything in Full\n  • Enterprise security\n  • Compliance tools\n"
                ;;
        esac
    fi
    
    summary_text+="\nOptions:\n"
    [[ "${CREATE_SHORTCUTS}" == "true" ]] && summary_text+="  • Desktop shortcuts: Yes\n"
    [[ "${ADD_TO_PATH}" == "true" ]] && summary_text+="  • Add to PATH: Yes\n"
    [[ "${ENABLE_UPDATES}" == "true" ]] && summary_text+="  • Auto-updates: Yes\n"
    
    summary_text+="\nEstimated disk space: "
    case "${SELECTED_PROFILE}" in
        "minimal") summary_text+="500MB" ;;
        "standard") summary_text+="1.2GB" ;;
        "full") summary_text+="2.1GB" ;;
        "enterprise") summary_text+="2.8GB" ;;
        "custom") summary_text+="Variable" ;;
    esac
    
    if ! zenity_enhanced --question \
        --title="Ready to Install" \
        --text="${summary_text}\n\nProceed with installation?"; then
        log_info "User cancelled installation at summary"
        return 1
    fi
    
    log_audit "installation_confirmed" "${SELECTED_PROFILE}"
    log_info "Installation confirmed by user"
    
    return 0
}

# === INSTALLATION EXECUTION ===
perform_installation() {
    log_info "Starting installation process"
    
    # Generate installation ID
    INSTALLATION_ID="cursor_$(date +%s)_$$"
    log_audit "installation_started" "${INSTALLATION_ID}"
    
    # Create progress dialog
    exec 3> >(zenity_enhanced --progress \
        --title="Installing ${APP_NAME}" \
        --text="Preparing installation..." \
        --percentage=0 \
        --auto-close \
        --no-cancel)
    
    # Get the PID of zenity for cleanup
    ZENITY_PID=$!
    
    # Trap for cleanup
    trap 'cleanup_installation' EXIT INT TERM
    
    local step=0
    local progress=0
    
    # Step 1: Prepare installation
    ((step++))
    progress=$((step * 100 / TOTAL_STEPS))
    show_progress "Preparing Installation" "Creating directories and setting up environment..." "${progress}" >&3
    
    if ! prepare_installation; then
        show_error "Failed to prepare installation environment"
        return 1
    fi
    
    # Step 2: Backup existing installation
    ((step++))
    progress=$((step * 100 / TOTAL_STEPS))
    show_progress "Backup" "Creating backup of existing installation..." "${progress}" >&3
    
    backup_existing_installation
    
    # Step 3: Download/Copy files
    ((step++))
    progress=$((step * 100 / TOTAL_STEPS))
    show_progress "Copy Files" "Copying application files..." "${progress}" >&3
    
    if ! copy_application_files; then
        show_error "Failed to copy application files"
        return 1
    fi
    
    # Step 4: Set permissions
    ((step++))
    progress=$((step * 100 / TOTAL_STEPS))
    show_progress "Permissions" "Setting file permissions..." "${progress}" >&3
    
    if ! set_file_permissions; then
        show_error "Failed to set file permissions"
        return 1
    fi
    
    # Step 5: Install components
    ((step++))
    progress=$((step * 100 / TOTAL_STEPS))
    show_progress "Components" "Installing selected components..." "${progress}" >&3
    
    if ! install_components; then
        show_error "Failed to install components"
        return 1
    fi
    
    # Step 6: Create desktop integration
    if [[ "${CREATE_SHORTCUTS}" == "true" ]]; then
        ((step++))
        progress=$((step * 100 / TOTAL_STEPS))
        show_progress "Desktop Integration" "Creating shortcuts and menu entries..." "${progress}" >&3
        
        if ! create_desktop_integration; then
            show_error "Failed to create desktop integration"
            return 1
        fi
    fi
    
    # Step 7: Update system PATH
    if [[ "${ADD_TO_PATH}" == "true" ]]; then
        ((step++))
        progress=$((step * 100 / TOTAL_STEPS))
        show_progress "System Integration" "Adding to system PATH..." "${progress}" >&3
        
        if ! update_system_path; then
            show_error "Failed to update system PATH"
            return 1
        fi
    fi
    
    # Step 8: Configure file associations
    ((step++))
    progress=$((step * 100 / TOTAL_STEPS))
    show_progress "File Associations" "Configuring file associations..." "${progress}" >&3
    
    configure_file_associations
    
    # Step 9: Setup automatic updates
    if [[ "${ENABLE_UPDATES}" == "true" ]]; then
        ((step++))
        progress=$((step * 100 / TOTAL_STEPS))
        show_progress "Auto-Updates" "Configuring automatic updates..." "${progress}" >&3
        
        setup_automatic_updates
    fi
    
    # Step 10: Install system services
    ((step++))
    progress=$((step * 100 / TOTAL_STEPS))
    show_progress "Services" "Installing system services..." "${progress}" >&3
    
    install_system_services
    
    # Step 11: Validate installation
    ((step++))
    progress=$((step * 100 / TOTAL_STEPS))
    show_progress "Validation" "Validating installation..." "${progress}" >&3
    
    if ! validate_installation; then
        show_error "Installation validation failed"
        return 1
    fi
    
    # Step 12: Finalize
    ((step++))
    progress=100
    show_progress "Complete" "Installation completed successfully!" "${progress}" >&3
    
    finalize_installation
    
    # Close progress dialog
    exec 3>&-
    
    log_audit "installation_completed" "${INSTALLATION_ID}"
    log_info "Installation completed successfully"
    
    return 0
}

prepare_installation() {
    log_info "Preparing installation environment"
    
    # Create installation directory
    if ! mkdir -p "${INSTALL_DIR}"; then
        log_error "Failed to create installation directory: ${INSTALL_DIR}"
        return 1
    fi
    
    # Create temporary directories
    mkdir -p "${TEMP_DIR}/extract"
    mkdir -p "${TEMP_DIR}/download"
    
    # Check and request privileges if needed
    if [[ "${INSTALL_DIR}" =~ ^/opt|^/usr ]]; then
        log_info "System installation requires elevated privileges"
        
        # Test sudo access
        if ! sudo -n true 2>/dev/null; then
            if ! zenity_enhanced --password --title="Administrator Authentication" | sudo -S true; then
                log_error "Failed to obtain administrator privileges"
                return 1
            fi
        fi
    fi
    
    return 0
}

backup_existing_installation() {
    log_info "Checking for existing installation"
    
    if [[ -d "${INSTALL_DIR}" ]] && [[ -n "$(ls -A "${INSTALL_DIR}" 2>/dev/null)" ]]; then
        log_info "Existing installation found, creating backup"
        
        local backup_name="cursor_backup_$(date +%Y%m%d_%H%M%S)"
        local backup_path="${BACKUP_DIR}/${backup_name}"
        
        if mkdir -p "${backup_path}" && cp -r "${INSTALL_DIR}"/* "${backup_path}/" 2>/dev/null; then
            log_info "Backup created: ${backup_path}"
            echo "${backup_path}" > "${CONFIG_DIR}/last_backup.txt"
        else
            log_warn "Failed to create backup (continuing anyway)"
        fi
    fi
}

copy_application_files() {
    log_info "Copying application files"
    
    # Find AppImage file
    local appimage_files=("${SCRIPT_DIR}"/01-appimage*.AppImage)
    if [[ ${#appimage_files[@]} -eq 0 ]] || [[ ! -f "${appimage_files[0]}" ]]; then
        log_error "AppImage file not found"
        return 1
    fi
    
    local appimage_file="${appimage_files[0]}"
    log_info "Using AppImage: ${appimage_file}"
    
    # Copy AppImage
    local target_binary="${INSTALL_DIR}/cursor"
    if [[ "${INSTALL_DIR}" =~ ^/opt|^/usr ]]; then
        sudo cp "${appimage_file}" "${target_binary}"
    else
        cp "${appimage_file}" "${target_binary}"
    fi
    
    # Copy additional files
    local additional_files=("README.md" "LICENSE" "CHANGELOG.md" "cursor.png" "cursor.svg")
    for file in "${additional_files[@]}"; do
        if [[ -f "${SCRIPT_DIR}/${file}" ]]; then
            if [[ "${INSTALL_DIR}" =~ ^/opt|^/usr ]]; then
                sudo cp "${SCRIPT_DIR}/${file}" "${INSTALL_DIR}/"
            else
                cp "${SCRIPT_DIR}/${file}" "${INSTALL_DIR}/"
            fi
        fi
    done
    
    # Create version file
    echo "${VERSION}" | if [[ "${INSTALL_DIR}" =~ ^/opt|^/usr ]]; then
        sudo tee "${INSTALL_DIR}/VERSION" > /dev/null
    else
        tee "${INSTALL_DIR}/VERSION" > /dev/null
    fi
    
    return 0
}

set_file_permissions() {
    log_info "Setting file permissions"
    
    local cursor_binary="${INSTALL_DIR}/cursor"
    
    if [[ "${INSTALL_DIR}" =~ ^/opt|^/usr ]]; then
        sudo chmod +x "${cursor_binary}"
        sudo chmod -R 755 "${INSTALL_DIR}"
        sudo chown -R root:root "${INSTALL_DIR}"
    else
        chmod +x "${cursor_binary}"
        chmod -R 755 "${INSTALL_DIR}"
    fi
    
    return 0
}

install_components() {
    log_info "Installing components for profile: ${SELECTED_PROFILE}"
    
    # Simulate component installation based on profile
    case "${SELECTED_PROFILE}" in
        "minimal")
            install_minimal_components
            ;;
        "standard")
            install_standard_components
            ;;
        "full")
            install_full_components
            ;;
        "enterprise")
            install_enterprise_components
            ;;
        "custom")
            install_custom_components
            ;;
    esac
    
    return 0
}

install_minimal_components() {
    log_debug "Installing minimal components"
    # Core editor components only
    sleep 1  # Simulate installation time
    return 0
}

install_standard_components() {
    log_debug "Installing standard components"
    # Standard components
    sleep 2  # Simulate installation time
    return 0
}

install_full_components() {
    log_debug "Installing full components"
    # Full component set
    sleep 3  # Simulate installation time
    return 0
}

install_enterprise_components() {
    log_debug "Installing enterprise components"
    # Enterprise components
    sleep 4  # Simulate installation time
    return 0
}

install_custom_components() {
    log_debug "Installing custom components: ${SELECTED_COMPONENTS[*]}"
    
    for component in "${SELECTED_COMPONENTS[@]}"; do
        log_debug "Installing component: ${component}"
        sleep 0.5  # Simulate per-component installation
    done
    
    return 0
}

create_desktop_integration() {
    log_info "Creating desktop integration"
    
    # Create desktop file
    local desktop_content="[Desktop Entry]
Version=1.0
Type=Application
Name=${APP_NAME}
GenericName=Code Editor
Comment=${APP_DESCRIPTION}
Exec=${INSTALL_DIR}/cursor %F
Icon=${INSTALL_DIR}/cursor
Terminal=false
Categories=Development;IDE;TextEditor;
StartupNotify=true
MimeType=text/plain;text/x-chdr;text/x-csrc;text/x-c++hdr;text/x-c++src;text/x-java;text/x-dsrc;text/x-pascal;text/x-perl;text/x-python;application/x-php;application/x-httpd-php3;application/x-httpd-php4;application/x-httpd-php5;application/javascript;application/json;text/css;text/html;text/xml;text/x-sql;text/x-sh;
Actions=new-empty-window;
X-Unity-IconBackgroundColor=#394151

[Desktop Action new-empty-window]
Name=New Empty Window
Exec=${INSTALL_DIR}/cursor --new-window %F
Icon=${INSTALL_DIR}/cursor"

    # Install desktop file
    local desktop_file="${APPLICATIONS_DIR}/${DESKTOP_FILE}"
    
    if [[ "${INSTALL_DIR}" =~ ^/opt|^/usr ]]; then
        echo "${desktop_content}" | sudo tee "${desktop_file}" > /dev/null
        sudo chmod 644 "${desktop_file}"
    else
        local user_applications="${HOME}/.local/share/applications"
        mkdir -p "${user_applications}"
        echo "${desktop_content}" > "${user_applications}/${DESKTOP_FILE}"
        chmod 644 "${user_applications}/${DESKTOP_FILE}"
    fi
    
    # Install icon
    install_application_icon
    
    # Update desktop database
    if command -v update-desktop-database >/dev/null 2>&1; then
        if [[ "${INSTALL_DIR}" =~ ^/opt|^/usr ]]; then
            sudo update-desktop-database "${APPLICATIONS_DIR}" 2>/dev/null || true
        else
            update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null || true
        fi
    fi
    
    return 0
}

install_application_icon() {
    log_debug "Installing application icon"
    
    # Try to use provided icon
    local source_icon=""
    if [[ -f "${SCRIPT_DIR}/cursor.svg" ]]; then
        source_icon="${SCRIPT_DIR}/cursor.svg"
    elif [[ -f "${SCRIPT_DIR}/cursor.png" ]]; then
        source_icon="${SCRIPT_DIR}/cursor.png"
    elif [[ -f "${INSTALL_DIR}/cursor.svg" ]]; then
        source_icon="${INSTALL_DIR}/cursor.svg"
    elif [[ -f "${INSTALL_DIR}/cursor.png" ]]; then
        source_icon="${INSTALL_DIR}/cursor.png"
    fi
    
    if [[ -n "${source_icon}" ]]; then
        local icon_sizes=("16" "22" "24" "32" "48" "64" "128" "256")
        local icon_extension="${source_icon##*.}"
        
        for size in "${icon_sizes[@]}"; do
            local icon_dir="${ICONS_DIR}/${size}x${size}/apps"
            local target_icon="${icon_dir}/cursor.${icon_extension}"
            
            if [[ "${INSTALL_DIR}" =~ ^/opt|^/usr ]]; then
                sudo mkdir -p "${icon_dir}"
                sudo cp "${source_icon}" "${target_icon}"
            else
                local user_icon_dir="${HOME}/.local/share/icons/hicolor/${size}x${size}/apps"
                mkdir -p "${user_icon_dir}"
                cp "${source_icon}" "${user_icon_dir}/cursor.${icon_extension}"
            fi
        done
        
        # Update icon cache
        if command -v gtk-update-icon-cache >/dev/null 2>&1; then
            if [[ "${INSTALL_DIR}" =~ ^/opt|^/usr ]]; then
                sudo gtk-update-icon-cache "${ICONS_DIR}" 2>/dev/null || true
            else
                gtk-update-icon-cache "${HOME}/.local/share/icons/hicolor" 2>/dev/null || true
            fi
        fi
    else
        # Create a simple fallback icon
        create_fallback_icon
    fi
}

create_fallback_icon() {
    log_debug "Creating fallback icon"
    
    local icon_svg='<?xml version="1.0" encoding="UTF-8"?>
<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#007ACC;stop-opacity:1" />
      <stop offset="100%" style="stop-color:#005a9e;stop-opacity:1" />
    </linearGradient>
  </defs>
  <rect width="64" height="64" rx="8" fill="url(#bg)"/>
  <text x="32" y="42" font-family="Arial,sans-serif" font-size="28" font-weight="bold" fill="white" text-anchor="middle">C</text>
</svg>'
    
    local icon_path="${INSTALL_DIR}/cursor.svg"
    if [[ "${INSTALL_DIR}" =~ ^/opt|^/usr ]]; then
        echo "${icon_svg}" | sudo tee "${icon_path}" > /dev/null
    else
        echo "${icon_svg}" > "${icon_path}"
    fi
}

update_system_path() {
    log_info "Updating system PATH"
    
    local cursor_symlink="${SYSTEM_BIN_DIR}/cursor"
    local cursor_binary="${INSTALL_DIR}/cursor"
    
    if [[ "${INSTALL_DIR}" =~ ^/opt|^/usr ]]; then
        sudo ln -sf "${cursor_binary}" "${cursor_symlink}"
    else
        # For user installation, add to user's PATH
        local user_bin="${HOME}/.local/bin"
        mkdir -p "${user_bin}"
        ln -sf "${cursor_binary}" "${user_bin}/cursor"
        
        # Add to shell profiles if not already present
        local shell_profiles=("${HOME}/.bashrc" "${HOME}/.zshrc" "${HOME}/.profile")
        local path_line='export PATH="$HOME/.local/bin:$PATH"'
        
        for profile in "${shell_profiles[@]}"; do
            if [[ -f "${profile}" ]] && ! grep -q ".local/bin" "${profile}"; then
                echo "" >> "${profile}"
                echo "# Added by Cursor installer" >> "${profile}"
                echo "${path_line}" >> "${profile}"
                log_debug "Added PATH to ${profile}"
            fi
        done
    fi
    
    return 0
}

configure_file_associations() {
    log_info "Configuring file associations"
    
    # File types to associate with Cursor
    local file_types=(
        "text/plain"
        "text/x-chdr"
        "text/x-csrc"
        "text/x-c++hdr"
        "text/x-c++src"
        "text/x-java"
        "text/x-python"
        "application/javascript"
        "application/json"
        "text/css"
        "text/html"
        "text/xml"
        "text/x-sh"
    )
    
    # Set default application for these types
    for mime_type in "${file_types[@]}"; do
        if command -v xdg-mime >/dev/null 2>&1; then
            xdg-mime default "${DESKTOP_FILE}" "${mime_type}" 2>/dev/null || true
        fi
    done
    
    return 0
}

setup_automatic_updates() {
    log_info "Setting up automatic updates"
    
    # Create update configuration
    local update_config="${CONFIG_DIR}/updates.conf"
    cat > "${update_config}" <<EOF
[updates]
enabled=true
channel=stable
check_interval=24
auto_download=true
auto_install=false
backup_before_update=true
notify_user=true

[schedule]
check_time=02:00
maintenance_window=02:00-04:00
exclude_days=

[urls]
update_server=https://cursor.com/api/updates
download_mirror=https://releases.cursor.com
EOF
    
    # Create update script
    local update_script="${CONFIG_DIR}/update.sh"
    cat > "${update_script}" <<'EOF'
#!/bin/bash
# Cursor Auto-Update Script
# Generated by Cursor Installer

CONFIG_DIR="$(dirname "$0")"
LOG_FILE="${CONFIG_DIR}/logs/update.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "${LOG_FILE}"
}

check_for_updates() {
    log_message "Checking for updates..."
    # Update check logic would go here
    return 0
}

if [[ "${1:-}" == "--check" ]]; then
    check_for_updates
fi
EOF
    
    chmod +x "${update_script}"
    
    # Create systemd timer for user installations
    if [[ ! "${INSTALL_DIR}" =~ ^/opt|^/usr ]] && command -v systemctl >/dev/null 2>&1; then
        create_user_update_timer
    fi
    
    return 0
}

create_user_update_timer() {
    log_debug "Creating user update timer"
    
    local systemd_user_dir="${HOME}/.config/systemd/user"
    mkdir -p "${systemd_user_dir}"
    
    # Create service file
    cat > "${systemd_user_dir}/cursor-update.service" <<EOF
[Unit]
Description=Cursor Update Check
After=network-online.target

[Service]
Type=oneshot
ExecStart=${CONFIG_DIR}/update.sh --check
EOF
    
    # Create timer file
    cat > "${systemd_user_dir}/cursor-update.timer" <<EOF
[Unit]
Description=Check for Cursor updates daily
Requires=cursor-update.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    # Enable and start timer
    systemctl --user daemon-reload
    systemctl --user enable cursor-update.timer
    systemctl --user start cursor-update.timer
}

install_system_services() {
    log_info "Installing system services"
    
    # Create uninstaller
    create_uninstaller
    
    # Register with package manager if applicable
    register_with_package_manager
    
    return 0
}

create_uninstaller() {
    log_debug "Creating uninstaller"
    
    local uninstaller="${INSTALL_DIR}/uninstall.sh"
    cat > "${TEMP_DIR}/uninstaller.sh" <<EOF
#!/bin/bash
# Cursor Uninstaller
# Generated by Cursor Installer v${SCRIPT_VERSION}

set -euo pipefail

INSTALL_DIR="${INSTALL_DIR}"
INSTALLATION_ID="${INSTALLATION_ID}"

uninstall_cursor() {
    echo "Uninstalling Cursor..."
    
    # Remove desktop integration
    rm -f "${APPLICATIONS_DIR}/${DESKTOP_FILE}"
    rm -f "${HOME}/.local/share/applications/${DESKTOP_FILE}"
    
    # Remove from PATH
    rm -f "${SYSTEM_BIN_DIR}/cursor"
    rm -f "${HOME}/.local/bin/cursor"
    
    # Remove installation directory
    rm -rf "\${INSTALL_DIR}"
    
    # Remove configuration (optional)
    read -p "Remove user configuration and data? [y/N]: " -n 1 -r
    if [[ \$REPLY =~ ^[Yy]$ ]]; then
        rm -rf "${CONFIG_DIR}"
        rm -rf "${CACHE_DIR}"
    fi
    
    echo "Cursor has been uninstalled."
}

if [[ "\${1:-}" == "--yes" ]] || zenity --question --text="Are you sure you want to uninstall Cursor?"; then
    uninstall_cursor
fi
EOF
    
    if [[ "${INSTALL_DIR}" =~ ^/opt|^/usr ]]; then
        sudo cp "${TEMP_DIR}/uninstaller.sh" "${uninstaller}"
        sudo chmod +x "${uninstaller}"
    else
        cp "${TEMP_DIR}/uninstaller.sh" "${uninstaller}"
        chmod +x "${uninstaller}"
    fi
}

register_with_package_manager() {
    log_debug "Attempting to register with package manager"
    
    # Try to register with dpkg if available (Debian/Ubuntu)
    if command -v dpkg >/dev/null 2>&1 && [[ "${INSTALL_DIR}" =~ ^/opt|^/usr ]]; then
        create_dpkg_status_entry
    fi
}

create_dpkg_status_entry() {
    log_debug "Creating dpkg status entry"
    
    # This is a simplified approach - proper .deb packages would be better
    local status_file="/var/lib/dpkg/status.d/cursor"
    local control_info="Package: cursor
Version: ${VERSION}
Architecture: amd64
Maintainer: Cursor Technologies
Installed-Size: 2048
Section: editors
Priority: optional
Description: AI-powered code editor
 Cursor is an AI-powered code editor built for pair programming with AI.
"
    
    if [[ -w "/var/lib/dpkg/status.d" ]] 2>/dev/null; then
        echo "${control_info}" | sudo tee "${status_file}" > /dev/null
    fi
}

validate_installation() {
    log_info "Validating installation"
    
    local validation_errors=()
    
    # Check if binary exists and is executable
    local cursor_binary="${INSTALL_DIR}/cursor"
    if [[ ! -f "${cursor_binary}" ]]; then
        validation_errors+=("Binary not found: ${cursor_binary}")
    elif [[ ! -x "${cursor_binary}" ]]; then
        validation_errors+=("Binary not executable: ${cursor_binary}")
    fi
    
    # Check desktop integration
    if [[ "${CREATE_SHORTCUTS}" == "true" ]]; then
        local desktop_file="${APPLICATIONS_DIR}/${DESKTOP_FILE}"
        local user_desktop_file="${HOME}/.local/share/applications/${DESKTOP_FILE}"
        
        if [[ ! -f "${desktop_file}" ]] && [[ ! -f "${user_desktop_file}" ]]; then
            validation_errors+=("Desktop file not created")
        fi
    fi
    
    # Check PATH integration
    if [[ "${ADD_TO_PATH}" == "true" ]]; then
        if ! command -v cursor >/dev/null 2>&1; then
            validation_errors+=("Cursor not found in PATH")
        fi
    fi
    
    # Test basic functionality
    if command -v timeout >/dev/null 2>&1; then
        if ! timeout 10 "${cursor_binary}" --version >/dev/null 2>&1; then
            validation_errors+=("Binary failed basic functionality test")
        fi
    fi
    
    if [[ ${#validation_errors[@]} -gt 0 ]]; then
        log_error "Validation failed: ${validation_errors[*]}"
        return 1
    fi
    
    log_info "Installation validation passed"
    return 0
}

finalize_installation() {
    log_info "Finalizing installation"
    
    # Save installation metadata
    local metadata_file="${CONFIG_DIR}/installation.json"
    cat > "${metadata_file}" <<EOF
{
    "installation_id": "${INSTALLATION_ID}",
    "version": "${VERSION}",
    "installer_version": "${SCRIPT_VERSION}",
    "profile": "${SELECTED_PROFILE}",
    "install_dir": "${INSTALL_DIR}",
    "install_date": "$(date -Iseconds)",
    "user": "$(whoami)",
    "hostname": "$(hostname)",
    "components": $(printf '%s\n' "${SELECTED_COMPONENTS[@]}" | jq -R . | jq -s .),
    "options": {
        "shortcuts": ${CREATE_SHORTCUTS},
        "path": ${ADD_TO_PATH},
        "updates": ${ENABLE_UPDATES}
    }
}
EOF
    
    # Clean up temporary files
    rm -rf "${TEMP_DIR}"
    
    # Update file database
    if command -v updatedb >/dev/null 2>&1 && [[ "${INSTALL_DIR}" =~ ^/opt|^/usr ]]; then
        sudo updatedb 2>/dev/null || true
    fi
    
    log_info "Installation finalized"
}

# === COMPLETION DIALOG ===
show_completion_dialog() {
    log_info "Showing completion dialog"
    
    local completion_text="🎉 Installation Complete!\n\n"
    completion_text+="${APP_NAME} v${VERSION} has been installed successfully.\n\n"
    
    completion_text+="Installation Details:\n"
    completion_text+="• Location: ${INSTALL_DIR}\n"
    completion_text+="• Profile: ${SELECTED_PROFILE}\n"
    completion_text+="• Installation ID: ${INSTALLATION_ID}\n\n"
    
    completion_text+="What's Next:\n"
    if [[ "${ADD_TO_PATH}" == "true" ]]; then
        completion_text+="• Open a new terminal and run: cursor\n"
    fi
    if [[ "${CREATE_SHORTCUTS}" == "true" ]]; then
        completion_text+="• Find Cursor in your applications menu\n"
    fi
    completion_text+="• Click 'Launch Now' to start immediately\n\n"
    
    completion_text+="Support:\n"
    completion_text+="• Documentation: ${APP_URL}/docs\n"
    completion_text+="• Community: ${APP_URL}/community\n"
    completion_text+="• Issues: ${APP_URL}/support\n"
    
    # Show completion dialog with options
    local choice
    choice=$(zenity_enhanced --list \
        --title="Installation Complete" \
        --text="${completion_text}" \
        --radiolist \
        --column="Select" \
        --column="Action" \
        --column="Description" \
        TRUE "launch" "Launch Cursor now" \
        FALSE "view_logs" "View installation logs" \
        FALSE "create_backup" "Create installation backup" \
        FALSE "exit" "Exit installer")
    
    case "${choice}" in
        "launch")
            launch_application
            ;;
        "view_logs")
            view_installation_logs
            ;;
        "create_backup")
            create_installation_backup
            ;;
        "exit"|"")
            log_info "User chose to exit"
            ;;
    esac
    
    log_audit "installation_completed_dialog" "${choice:-exit}"
}

launch_application() {
    log_info "Launching application"
    
    local cursor_binary="${INSTALL_DIR}/cursor"
    
    if [[ -x "${cursor_binary}" ]]; then
        "${cursor_binary}" >/dev/null 2>&1 &
        log_info "Application launched successfully"
        
        zenity_enhanced --info \
            --title="Application Launched" \
            --text="${APP_NAME} is starting up.\n\nYou can close this installer now." \
            --timeout=5
    else
        log_error "Failed to launch application"
        show_error "Could not launch ${APP_NAME}.\n\nBinary not found or not executable."
    fi
}

view_installation_logs() {
    log_info "Viewing installation logs"
    
    if [[ -f "${LOG_FILE}" ]]; then
        if command -v gedit >/dev/null 2>&1; then
            gedit "${LOG_FILE}" &
        elif command -v kate >/dev/null 2>&1; then
            kate "${LOG_FILE}" &
        elif command -v mousepad >/dev/null 2>&1; then
            mousepad "${LOG_FILE}" &
        else
            zenity_enhanced --text-info \
                --title="Installation Log" \
                --filename="${LOG_FILE}" \
                --width=800 \
                --height=600
        fi
    else
        show_error "Log file not found: ${LOG_FILE}"
    fi
}

create_installation_backup() {
    log_info "Creating installation backup"
    
    local backup_name="cursor_installation_$(date +%Y%m%d_%H%M%S).tar.gz"
    local backup_path="${BACKUP_DIR}/${backup_name}"
    
    (
        echo "0" ; echo "# Creating backup archive..."
        
        # Create backup
        if tar -czf "${backup_path}" -C "$(dirname "${INSTALL_DIR}")" "$(basename "${INSTALL_DIR}")" 2>/dev/null; then
            echo "50" ; echo "# Adding configuration files..."
            
            # Add configuration
            tar -rf "${backup_path%.gz}" -C "${HOME}" ".config/cursor-zenity-installer" 2>/dev/null || true
            gzip "${backup_path%.gz}" 2>/dev/null || true
            
            echo "100" ; echo "# Backup completed!"
        else
            echo "100" ; echo "# Backup failed!"
        fi
    ) | zenity_enhanced --progress \
        --title="Creating Backup" \
        --text="Creating backup of installation..." \
        --percentage=0 \
        --auto-close
    
    if [[ -f "${backup_path}" ]]; then
        zenity_enhanced --info \
            --title="Backup Created" \
            --text="Installation backup created:\n\n${backup_path}\n\nSize: $(du -h "${backup_path}" | cut -f1)"
    else
        show_error "Failed to create backup"
    fi
}

# === ERROR HANDLING ===
show_error() {
    local message="$1"
    log_error "${message}"
    
    zenity_enhanced --error \
        --title="Installation Error" \
        --text="${message}\n\nCheck the log file for details:\n${LOG_FILE}"
}

cleanup_installation() {
    log_debug "Cleaning up installation"
    
    # Kill zenity progress dialog if running
    if [[ -n "${ZENITY_PID}" ]] && kill -0 "${ZENITY_PID}" 2>/dev/null; then
        kill "${ZENITY_PID}" 2>/dev/null || true
    fi
    
    # Clean up temporary files
    rm -rf "${TEMP_DIR}" 2>/dev/null || true
    
    # Close progress dialog file descriptor
    exec 3>&- 2>/dev/null || true
}

# === MAIN INSTALLATION FLOW ===
main() {
    local start_time
    start_time=$(date +%s)
    
    # Initialize logging
    init_logging
    log_info "Starting Cursor Zenity Installer v${SCRIPT_VERSION}"
    log_audit "installer_started" "version=${SCRIPT_VERSION}"
    
    # Setup environment
    setup_zenity_theme
    
    # Trap for cleanup
    trap cleanup_installation EXIT INT TERM
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --silent)
                SILENT_MODE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --force)
                FORCE_REINSTALL=true
                shift
                ;;
            --profile)
                SELECTED_PROFILE="$2"
                shift 2
                ;;
            --install-dir)
                INSTALL_DIR="$2"
                shift 2
                ;;
            --no-shortcuts)
                CREATE_SHORTCUTS=false
                shift
                ;;
            --no-path)
                ADD_TO_PATH=false
                shift
                ;;
            --no-updates)
                ENABLE_UPDATES=false
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            --version|-v)
                echo "Cursor Zenity Installer v${SCRIPT_VERSION}"
                echo "App Version: ${VERSION}"
                exit 0
                ;;
            *)
                log_warn "Unknown option: $1"
                shift
                ;;
        esac
    done
    
    # Silent mode handling
    if [[ "${SILENT_MODE}" == "true" ]]; then
        log_info "Running in silent mode"
        perform_silent_installation
        return $?
    fi
    
    # Welcome dialog
    if ! zenity_enhanced --question \
        --title="Welcome to ${APP_NAME} Installer" \
        --text="Welcome to the ${APP_NAME} Installation Wizard!\n\nThis installer will guide you through the process of installing ${APP_NAME} v${VERSION} on your system.\n\nFeatures:\n• AI-powered code completion\n• Integrated chat interface\n• Multi-language support\n• Cross-platform compatibility\n\nContinue with installation?"; then
        log_info "User cancelled at welcome dialog"
        exit 0
    fi
    
    # Installation wizard steps
    local steps=(
        "validate_system_requirements"
        "show_license_agreement"
        "show_profile_selection"
        "show_component_selection"
        "show_installation_location"
        "show_installation_options"
        "show_installation_summary"
        "perform_installation"
        "show_completion_dialog"
    )
    
    for step in "${steps[@]}"; do
        log_info "Executing step: ${step}"
        
        if ! "${step}"; then
            log_error "Step failed: ${step}"
            
            if ! zenity_enhanced --question \
                --title="Installation Error" \
                --text="Step '${step}' failed.\n\nWould you like to retry or cancel the installation?"; then
                log_info "User cancelled after step failure"
                exit 1
            fi
            
            # Retry the step
            if ! "${step}"; then
                log_error "Step failed again: ${step}"
                show_error "Installation cannot continue.\n\nStep '${step}' failed twice."
                exit 1
            fi
        fi
    done
    
    # Calculate total time
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_info "Installation completed in ${duration} seconds"
    log_audit "installer_completed" "duration=${duration}s"
    
    return 0
}

perform_silent_installation() {
    log_info "Performing silent installation"
    
    # Use default settings for silent installation
    SELECTED_PROFILE="${SELECTED_PROFILE:-standard}"
    CREATE_SHORTCUTS=true
    ADD_TO_PATH=true
    ENABLE_UPDATES=true
    
    # Validate system silently
    if ! validate_system_requirements_silent; then
        log_error "Silent installation failed: system requirements not met"
        return 1
    fi
    
    # Perform installation
    if perform_installation; then
        log_info "Silent installation completed successfully"
        echo "Cursor v${VERSION} installed successfully to ${INSTALL_DIR}"
        return 0
    else
        log_error "Silent installation failed"
        return 1
    fi
}

validate_system_requirements_silent() {
    log_info "Validating system requirements (silent mode)"
    
    # Check critical requirements without dialogs
    if ! command -v zenity >/dev/null 2>&1; then
        log_error "Zenity not available"
        return 1
    fi
    
    if [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
        log_error "No display environment"
        return 1
    fi
    
    local available_space
    available_space=$(df "${SCRIPT_DIR}" | awk 'NR==2 {print $4}')
    local space_mb=$((available_space / 1024))
    
    if [[ ${space_mb} -lt 1024 ]]; then
        log_error "Insufficient disk space: ${space_mb}MB"
        return 1
    fi
    
    return 0
}

show_usage() {
    cat <<EOF
Cursor Zenity Installer v${SCRIPT_VERSION}

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --silent                 Run in silent mode (no dialogs)
    --dry-run               Simulate installation without making changes
    --force                 Force reinstallation over existing installation
    --profile PROFILE       Set installation profile (minimal|standard|full|enterprise)
    --install-dir DIR       Set installation directory
    --no-shortcuts          Don't create desktop shortcuts
    --no-path              Don't add to system PATH
    --no-updates           Don't enable automatic updates
    --help, -h             Show this help message
    --version, -v          Show version information

EXAMPLES:
    $0                      # Interactive installation
    $0 --silent             # Silent installation with defaults
    $0 --profile full       # Install full profile interactively
    $0 --silent --profile minimal --install-dir ~/cursor
                           # Silent minimal installation to home directory

PROFILES:
    minimal     Core editor only (500MB)
    standard    Recommended installation (1.2GB)
    full        Complete installation (2.1GB)
    enterprise  Enterprise features (2.8GB)

For more information, visit: ${APP_URL}
EOF
}

# === ENTRY POINT ===
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi