#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# 10-select-improved-v2.sh - Professional Language Selector v2.0
# Enterprise-grade language selection framework with robust error handling and self-correcting mechanisms
# ============================================================================

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="2.0.0"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Configuration Management
readonly APP_NAME="cursor"
readonly LANG_CONFIG_DIR="${HOME}/.config/cursor-language"
readonly LANG_CACHE_DIR="${HOME}/.cache/cursor-language"
readonly LANG_LOG_DIR="${LANG_CONFIG_DIR}/logs"

# Logging Configuration
readonly LOG_FILE="${LANG_LOG_DIR}/language_${TIMESTAMP}.log"
readonly ERROR_LOG="${LANG_LOG_DIR}/language_errors_${TIMESTAMP}.log"
readonly SELECTION_LOG="${LANG_LOG_DIR}/selections_${TIMESTAMP}.log"

# Lock Management
readonly LOCK_FILE="${LANG_CONFIG_DIR}/.language.lock"
readonly PID_FILE="${LANG_CONFIG_DIR}/.language.pid"

# Global Variables
declare -g LANG_CONFIG="${LANG_CONFIG_DIR}/language.conf"
declare -g VERBOSE_MODE=false
declare -g INTERACTIVE_MODE=true
declare -g SELECTED_LANGUAGE=""

# Supported languages with proper codes
declare -A SUPPORTED_LANGUAGES=(
    ["en"]="English"
    ["es"]="Spanish"
    ["fr"]="French"
    ["de"]="German"
    ["it"]="Italian"
    ["pt"]="Portuguese"
    ["ru"]="Russian"
    ["zh"]="Chinese"
    ["ja"]="Japanese"
    ["ko"]="Korean"
    ["ar"]="Arabic"
    ["hi"]="Hindi"
)

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
        *"dialog"*|*"whiptail"*)
            log_info "Dialog failed, falling back to basic interface..."
            INTERACTIVE_MODE=false
            ;;
        *"locale"*)
            log_info "Locale command failed, checking system locale support..."
            check_locale_support
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

log_selection() {
    local language="$1"
    local method="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] SELECTION: $language via $method" >> "$SELECTION_LOG"
}

# Initialize language selector with robust setup
initialize_language_selector() {
    log_info "Initializing Professional Language Selector v${VERSION}"
    
    # Set up error handling
    trap 'error_handler ${LINENO} "$BASH_COMMAND" $?' ERR
    trap 'cleanup_on_exit' EXIT
    trap 'log_info "Received interrupt signal, cleaning up..."; cleanup_on_exit; exit 130' INT TERM
    
    # Create directory structure
    create_directory_structure
    
    # Load configuration
    load_configuration
    
    # Validate system requirements
    validate_system_requirements
    
    # Acquire lock
    acquire_lock
    
    log_info "Language selector initialization completed successfully"
}

# Create directory structure with retry logic
create_directory_structure() {
    local dirs=("$LANG_CONFIG_DIR" "$LANG_CACHE_DIR" "$LANG_LOG_DIR")
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
    if [[ ! -f "$LANG_CONFIG" ]]; then
        log_info "Creating default language configuration"
        create_default_configuration
    fi
    
    # Source configuration safely
    if [[ -r "$LANG_CONFIG" ]]; then
        source "$LANG_CONFIG"
        log_info "Configuration loaded from $LANG_CONFIG"
    else
        log_warning "Configuration file not readable, using defaults"
    fi
}

# Create default configuration
create_default_configuration() {
    cat > "$LANG_CONFIG" << 'EOF'
# Professional Language Selector Configuration v2.0

# General Settings
VERBOSE_MODE=false
INTERACTIVE_MODE=true
DEFAULT_LANGUAGE=en
REMEMBER_SELECTION=true

# Interface Settings
USE_DIALOG=true
USE_WHIPTAIL=true
FALLBACK_TO_TEXT=true
SHOW_NATIVE_NAMES=true

# System Integration
SYNC_WITH_SYSTEM_LOCALE=true
UPDATE_ENVIRONMENT_VARS=true
RESTART_APPLICATIONS=false
NOTIFY_USER_CHANGES=true

# Advanced Settings
ENABLE_LANGUAGE_VALIDATION=true
CHECK_FONT_SUPPORT=false
ENABLE_RTL_SUPPORT=false
CACHE_SELECTIONS=true

# Maintenance Settings
LOG_RETENTION_DAYS=30
CLEANUP_INTERVAL_DAYS=7
AUTO_UPDATE_CONFIG=false
ENABLE_USAGE_STATS=false
EOF
    
    log_info "Default configuration created: $LANG_CONFIG"
}

# Validate system requirements
validate_system_requirements() {
    log_info "Validating system requirements..."
    
    # Check for dialog tools
    local dialog_tools=("dialog" "whiptail" "zenity")
    local available_tools=()
    
    for tool in "${dialog_tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            available_tools+=("$tool")
        fi
    done
    
    if [[ ${#available_tools[@]} -eq 0 ]]; then
        log_warning "No dialog tools available, using text-only interface"
        INTERACTIVE_MODE=false
    else
        log_info "Available dialog tools: ${available_tools[*]}"
    fi
    
    # Check locale support
    if ! command -v locale &>/dev/null; then
        log_warning "locale command not available, some features may be limited"
    fi
    
    # Check system locale
    local current_locale
    current_locale=$(locale 2>/dev/null | grep "LANG=" | cut -d'=' -f2 | cut -d'_' -f1)
    if [[ -n "$current_locale" ]]; then
        log_info "Current system language: $current_locale"
    fi
    
    log_info "System requirements validation completed"
}

# Acquire lock with timeout
acquire_lock() {
    local timeout=5
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
            if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
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

# Display language selection interface
display_language_selection() {
    log_info "Displaying language selection interface..."
    
    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        if command -v dialog &>/dev/null; then
            select_language_with_dialog
        elif command -v whiptail &>/dev/null; then
            select_language_with_whiptail
        elif command -v zenity &>/dev/null; then
            select_language_with_zenity
        else
            select_language_with_text
        fi
    else
        select_language_with_text
    fi
}

# Select language using dialog
select_language_with_dialog() {
    log_info "Using dialog for language selection"
    
    local menu_items=()
    for code in "${!SUPPORTED_LANGUAGES[@]}"; do
        menu_items+=("$code" "${SUPPORTED_LANGUAGES[$code]}")
    done
    
    local selected
    if selected=$(dialog --clear --title "Language Selection" \
                        --menu "Choose your preferred language:" 15 50 8 \
                        "${menu_items[@]}" 2>&1 >/dev/tty); then
        SELECTED_LANGUAGE="$selected"
        log_selection "$selected" "dialog"
        clear
        return 0
    else
        log_warning "Dialog selection cancelled"
        return 1
    fi
}

# Select language using whiptail
select_language_with_whiptail() {
    log_info "Using whiptail for language selection"
    
    local menu_items=()
    for code in "${!SUPPORTED_LANGUAGES[@]}"; do
        menu_items+=("$code" "${SUPPORTED_LANGUAGES[$code]}")
    done
    
    local selected
    if selected=$(whiptail --clear --title "Language Selection" \
                          --menu "Choose your preferred language:" 15 50 8 \
                          "${menu_items[@]}" 3>&1 1>&2 2>&3); then
        SELECTED_LANGUAGE="$selected"
        log_selection "$selected" "whiptail"
        return 0
    else
        log_warning "Whiptail selection cancelled"
        return 1
    fi
}

# Select language using zenity
select_language_with_zenity() {
    log_info "Using zenity for language selection"
    
    local list_items=()
    for code in "${!SUPPORTED_LANGUAGES[@]}"; do
        list_items+=("FALSE" "$code" "${SUPPORTED_LANGUAGES[$code]}")
    done
    
    local selected
    if selected=$(zenity --list --radiolist \
                        --title="Language Selection" \
                        --text="Choose your preferred language:" \
                        --column="Select" --column="Code" --column="Language" \
                        "${list_items[@]}" 2>/dev/null); then
        SELECTED_LANGUAGE="$selected"
        log_selection "$selected" "zenity"
        return 0
    else
        log_warning "Zenity selection cancelled"
        return 1
    fi
}

# Select language using text interface
select_language_with_text() {
    log_info "Using text interface for language selection"
    
    echo
    echo "=== Cursor IDE Language Selection ==="
    echo
    echo "Available languages:"
    echo
    
    local -a codes=()
    local index=1
    
    for code in $(printf '%s\n' "${!SUPPORTED_LANGUAGES[@]}" | sort); do
        echo "  $index. $code - ${SUPPORTED_LANGUAGES[$code]}"
        codes[index]="$code"
        ((index++))
    done
    
    echo
    while true; do
        read -p "Please select a language (1-${#codes[@]}): " selection
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#codes[@]} ]]; then
            SELECTED_LANGUAGE="${codes[$selection]}"
            log_selection "${codes[$selection]}" "text"
            break
        else
            echo "Invalid selection. Please enter a number between 1 and ${#codes[@]}."
        fi
    done
    
    return 0
}

# Apply language selection
apply_language_selection() {
    local language="$1"
    
    if [[ -z "$language" ]]; then
        log_error "No language specified for application"
        return 1
    fi
    
    log_info "Applying language selection: $language"
    
    # Validate language code
    if [[ ! -n "${SUPPORTED_LANGUAGES[$language]:-}" ]]; then
        log_error "Unsupported language code: $language"
        return 1
    fi
    
    # Update configuration
    update_language_configuration "$language"
    
    # Set environment variables
    set_language_environment "$language"
    
    # Update application settings
    update_application_settings "$language"
    
    # Save selection for future use
    if [[ "${REMEMBER_SELECTION:-true}" == "true" ]]; then
        save_language_selection "$language"
    fi
    
    log_info "Language selection applied successfully: ${SUPPORTED_LANGUAGES[$language]}"
    echo "Language set to: ${SUPPORTED_LANGUAGES[$language]} ($language)"
    
    return 0
}

# Update language configuration
update_language_configuration() {
    local language="$1"
    local config_file="${LANG_CONFIG_DIR}/current_language.conf"
    
    cat > "$config_file" << EOF
# Current Language Configuration
CURRENT_LANGUAGE=$language
LANGUAGE_NAME=${SUPPORTED_LANGUAGES[$language]}
SELECTION_DATE=$(date -Iseconds)
SELECTION_METHOD=user
EOF
    
    log_info "Language configuration updated: $config_file"
}

# Set language environment variables
set_language_environment() {
    local language="$1"
    
    # Set LANG environment variable
    export LANG="${language}.UTF-8"
    export LANGUAGE="$language"
    export LC_ALL="${language}.UTF-8"
    
    # Update current shell environment
    if [[ "${UPDATE_ENVIRONMENT_VARS:-true}" == "true" ]]; then
        # Create environment script for sourcing
        local env_script="${LANG_CONFIG_DIR}/language_env.sh"
        cat > "$env_script" << EOF
# Language Environment Variables
export LANG=${language}.UTF-8
export LANGUAGE=$language
export LC_ALL=${language}.UTF-8
EOF
        
        log_info "Environment variables set for language: $language"
    fi
}

# Update application settings
update_application_settings() {
    local language="$1"
    
    # Create application-specific language file
    local app_config="${LANG_CONFIG_DIR}/cursor_language.json"
    
    cat > "$app_config" << EOF
{
    "language": "$language",
    "displayName": "${SUPPORTED_LANGUAGES[$language]}",
    "locale": "${language}.UTF-8",
    "dateFormat": "default",
    "numberFormat": "default",
    "updated": "$(date -Iseconds)"
}
EOF
    
    log_info "Application settings updated for language: $language"
}

# Save language selection
save_language_selection() {
    local language="$1"
    local selection_file="${LANG_CONFIG_DIR}/selection_history.txt"
    
    echo "$(date -Iseconds) $language ${SUPPORTED_LANGUAGES[$language]}" >> "$selection_file"
    
    # Keep only last 10 selections
    if [[ -f "$selection_file" ]]; then
        tail -10 "$selection_file" > "${selection_file}.tmp"
        mv "${selection_file}.tmp" "$selection_file"
    fi
    
    log_info "Language selection saved to history"
}

# Get current language
get_current_language() {
    local current_config="${LANG_CONFIG_DIR}/current_language.conf"
    
    if [[ -f "$current_config" ]]; then
        source "$current_config"
        echo "${CURRENT_LANGUAGE:-en}"
    else
        echo "en"
    fi
}

# List available languages
list_available_languages() {
    echo "Available languages:"
    echo
    
    for code in $(printf '%s\n' "${!SUPPORTED_LANGUAGES[@]}" | sort); do
        local current=""
        if [[ "$code" == "$(get_current_language)" ]]; then
            current=" (current)"
        fi
        echo "  $code - ${SUPPORTED_LANGUAGES[$code]}$current"
    done
}

# Self-correction functions
fix_directory_permissions() {
    log_info "Attempting to fix directory permissions..."
    
    for dir in "$LANG_CONFIG_DIR" "$LANG_CACHE_DIR" "$LANG_LOG_DIR"; do
        if [[ -d "$dir" ]]; then
            chmod 755 "$dir" 2>/dev/null || true
            find "$dir" -type f -exec chmod 644 {} \; 2>/dev/null || true
        fi
    done
}

check_locale_support() {
    log_info "Checking locale support..."
    
    if command -v locale &>/dev/null; then
        local supported_locales
        supported_locales=$(locale -a 2>/dev/null | grep -E "^(en|es|fr|de|it|pt|ru|zh|ja|ko|ar|hi)" | head -5)
        if [[ -n "$supported_locales" ]]; then
            log_info "Found supported locales: $(echo "$supported_locales" | tr '\n' ' ')"
        else
            log_warning "No matching locales found, language support may be limited"
        fi
    fi
}

# Cleanup functions
cleanup_on_error() {
    log_warning "Performing error cleanup..."
    cleanup_on_exit
}

cleanup_on_exit() {
    # Remove lock files
    [[ -f "$LOCK_FILE" ]] && rm -f "$LOCK_FILE"
    [[ -f "$PID_FILE" ]] && rm -f "$PID_FILE"
    
    # Kill any background processes
    jobs -p | xargs -r kill 2>/dev/null || true
    
    log_info "Cleanup completed"
}

# Display usage information
display_usage() {
    cat << 'EOF'
Professional Language Selector v2.0

USAGE:
    select-improved-v2.sh [OPTIONS] [LANGUAGE]

OPTIONS:
    --list              List available languages
    --current           Show current language
    --interactive       Use interactive selection (default)
    --text              Use text-only interface
    --verbose           Enable verbose output
    --help              Display this help message
    --version           Display version information

LANGUAGE:
    Two-letter language code (e.g., en, es, fr, de)

EXAMPLES:
    ./select-improved-v2.sh
    ./select-improved-v2.sh --list
    ./select-improved-v2.sh --current
    ./select-improved-v2.sh en
    ./select-improved-v2.sh --text --verbose

CONFIGURATION:
    Configuration file: ~/.config/cursor-language/language.conf
    Log directory: ~/.config/cursor-language/logs/

For more information, see the documentation.
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --list)
                list_available_languages
                exit 0
                ;;
            --current)
                echo "Current language: $(get_current_language)"
                exit 0
                ;;
            --interactive)
                INTERACTIVE_MODE=true
                shift
                ;;
            --text)
                INTERACTIVE_MODE=false
                shift
                ;;
            --verbose)
                VERBOSE_MODE=true
                shift
                ;;
            --help)
                display_usage
                exit 0
                ;;
            --version)
                echo "Professional Language Selector v$VERSION"
                exit 0
                ;;
            -*)
                log_warning "Unknown option: $1"
                shift
                ;;
            *)
                SELECTED_LANGUAGE="$1"
                shift
                ;;
        esac
    done
}

# Main execution function
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Initialize language selector
    initialize_language_selector
    
    # If language was specified on command line, use it
    if [[ -n "$SELECTED_LANGUAGE" ]]; then
        if apply_language_selection "$SELECTED_LANGUAGE"; then
            log_info "Language selection completed successfully"
            exit 0
        else
            log_error "Failed to apply language selection"
            exit 1
        fi
    fi
    
    # Otherwise, display selection interface
    if display_language_selection; then
        if [[ -n "$SELECTED_LANGUAGE" ]]; then
            if apply_language_selection "$SELECTED_LANGUAGE"; then
                log_info "Language selection completed successfully"
                exit 0
            else
                log_error "Failed to apply language selection"
                exit 1
            fi
        else
            log_warning "No language selected"
            exit 1
        fi
    else
        log_error "Language selection cancelled or failed"
        exit 1
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi