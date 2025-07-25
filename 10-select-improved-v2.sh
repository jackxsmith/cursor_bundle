#!/usr/bin/env bash
#
# PROFESSIONAL LANGUAGE SELECTOR FOR CURSOR IDE v2.0
# Enterprise-Grade Multi-Language Selection System
#
# Enhanced Features:
# - Robust error handling with automatic recovery
# - Self-correcting configuration management
# - Advanced validation and sanitization
# - Comprehensive logging and monitoring
# - Performance optimization with caching
# - Thread-safe operations
# - Graceful degradation
#

set -euo pipefail
IFS=$'\n\t'

# === CONFIGURATION ===
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="$(basename "${0}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Directory Structure
readonly LANG_BASE_DIR="/opt/cursor/languages"
readonly USER_LANG_DIR="${HOME}/.config/cursor/languages"
readonly CACHE_DIR="${HOME}/.cache/cursor/languages"
readonly LOG_DIR="${HOME}/.cache/cursor/logs"
readonly BACKUP_DIR="${HOME}/.cache/cursor/language_backups"
readonly TEMP_DIR="$(mktemp -d -t cursor_lang_XXXXXX)"

# Configuration Files
readonly MAIN_CONFIG="${USER_LANG_DIR}/config.json"
readonly LOCK_FILE="${USER_LANG_DIR}/.language_selector.lock"

# Logging
readonly MAIN_LOG="${LOG_DIR}/language_selector_${TIMESTAMP}.log"
readonly ERROR_LOG="${LOG_DIR}/language_errors_${TIMESTAMP}.log"

# Error Tracking
declare -A ERROR_COUNTS
readonly MAX_RETRIES=3

# === UTILITY FUNCTIONS ===

# Enhanced logging
log() {
    local level="${1}"
    local message="${2}"
    local timestamp="$(date -Iseconds)"
    
    echo "[${timestamp}] ${level}: ${message}" >> "$MAIN_LOG"
    
    if [[ "$level" == "ERROR" ]]; then
        echo "[${timestamp}] ${level}: ${message}" >> "$ERROR_LOG"
        ((ERROR_COUNTS[${3:-general}]++)) || true
    fi
    
    if [[ "$level" =~ ^(ERROR|WARN)$ ]] || [[ "${VERBOSE:-0}" -eq 1 ]]; then
        echo "[${timestamp}] ${level}: ${message}" >&2
    fi
}

# Self-correcting directory creation
ensure_directory() {
    local dir="$1"
    local mode="${2:-0755}"
    local attempt=0
    
    while [[ $attempt -lt $MAX_RETRIES ]]; do
        if [[ -d "$dir" ]]; then
            if [[ -w "$dir" && -r "$dir" ]]; then
                return 0
            elif chmod "$mode" "$dir" 2>/dev/null; then
                log "INFO" "Corrected permissions for: $dir"
                return 0
            fi
        elif mkdir -p "$dir" 2>/dev/null && chmod "$mode" "$dir" 2>/dev/null; then
            log "INFO" "Created directory: $dir"
            return 0
        fi
        
        ((attempt++))
        [[ $attempt -lt $MAX_RETRIES ]] && sleep 0.5
    done
    
    log "ERROR" "Failed to ensure directory: $dir"
    return 1
}

# Initialize directory structure
initialize_directories() {
    local dirs=("$USER_LANG_DIR" "$CACHE_DIR" "$LOG_DIR" "$BACKUP_DIR")
    
    for dir in "${dirs[@]}"; do
        if ! ensure_directory "$dir"; then
            return 1
        fi
    done
    
    # Log rotation
    find "$LOG_DIR" -name "language_*.log" -mtime +7 -delete 2>/dev/null || true
    
    return 0
}

# File locking
acquire_lock() {
    local timeout="${1:-30}"
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        if mkdir "$LOCK_FILE" 2>/dev/null; then
            echo $$ > "$LOCK_FILE/pid"
            return 0
        fi
        
        if [[ -f "$LOCK_FILE/pid" ]]; then
            local lock_pid=$(cat "$LOCK_FILE/pid" 2>/dev/null || echo "0")
            if ! kill -0 "$lock_pid" 2>/dev/null; then
                rm -rf "$LOCK_FILE"
                continue
            fi
        fi
        
        sleep 0.5
        ((elapsed++))
    done
    
    return 1
}

release_lock() {
    [[ -d "$LOCK_FILE" ]] && rm -rf "$LOCK_FILE"
}

# Cleanup
cleanup() {
    release_lock
    [[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
    log "INFO" "Script completed"
}

trap cleanup EXIT
trap 'exit 130' INT TERM

# === CONFIGURATION MANAGEMENT ===

# Load configuration with validation
load_configuration() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        create_default_configuration "$config_file"
        return $?
    fi
    
    # Validate JSON
    if ! jq -e '.' "$config_file" >/dev/null 2>&1; then
        log "ERROR" "Invalid JSON in configuration"
        backup_configuration "$config_file"
        create_default_configuration "$config_file"
        return $?
    fi
    
    # Check version
    local version=$(jq -r '.version // "1.0.0"' "$config_file")
    if [[ "$version" != "$SCRIPT_VERSION" ]]; then
        log "INFO" "Migrating configuration from $version to $SCRIPT_VERSION"
        migrate_configuration "$config_file"
    fi
    
    return 0
}

# Create default configuration
create_default_configuration() {
    local config_file="$1"
    
    cat > "$config_file" << EOF
{
    "version": "$SCRIPT_VERSION",
    "created": "$(date -Iseconds)",
    "languages": {
        "installed": ["en-US"],
        "available": []
    },
    "preferences": {
        "default_language": "en-US",
        "fallback_chain": ["en-US"],
        "auto_detect": true
    },
    "settings": {
        "cache_ttl": 86400,
        "max_retries": 3
    }
}
EOF
    
    chmod 600 "$config_file"
    log "INFO" "Created default configuration"
    return 0
}

# Backup configuration
backup_configuration() {
    local config_file="$1"
    local backup="${BACKUP_DIR}/$(basename "$config_file").${TIMESTAMP}.bak"
    
    if [[ -f "$config_file" ]] && cp "$config_file" "$backup" 2>/dev/null; then
        # Keep only last 5 backups
        ls -t "${BACKUP_DIR}"/$(basename "$config_file").*.bak 2>/dev/null | tail -n +6 | xargs -r rm -f
        log "INFO" "Created backup: $backup"
        return 0
    fi
    return 1
}

# Migrate configuration
migrate_configuration() {
    local config_file="$1"
    backup_configuration "$config_file"
    
    # Update version and timestamp
    jq --arg v "$SCRIPT_VERSION" --arg ts "$(date -Iseconds)" \
        '.version = $v | .updated = $ts' "$config_file" > "${config_file}.tmp" && \
        mv "${config_file}.tmp" "$config_file"
    
    log "INFO" "Configuration migrated to version $SCRIPT_VERSION"
}

# === LANGUAGE MANAGEMENT ===

# Get available languages
get_available_languages() {
    local cache_file="${CACHE_DIR}/languages.json"
    local cache_ttl=86400
    
    # Check cache
    if [[ -f "$cache_file" ]]; then
        local cache_age=$(($(date +%s) - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0)))
        if [[ $cache_age -lt $cache_ttl ]]; then
            cat "$cache_file"
            return 0
        fi
    fi
    
    # Generate language list
    cat > "$cache_file" << 'EOF'
{
    "languages": [
        {"code": "en-US", "name": "English (US)", "status": "stable"},
        {"code": "en-GB", "name": "English (UK)", "status": "stable"},
        {"code": "es-ES", "name": "Spanish (Spain)", "status": "stable"},
        {"code": "es-MX", "name": "Spanish (Mexico)", "status": "stable"},
        {"code": "fr-FR", "name": "French", "status": "stable"},
        {"code": "de-DE", "name": "German", "status": "stable"},
        {"code": "it-IT", "name": "Italian", "status": "stable"},
        {"code": "pt-BR", "name": "Portuguese (Brazil)", "status": "stable"},
        {"code": "ru-RU", "name": "Russian", "status": "stable"},
        {"code": "zh-CN", "name": "Chinese (Simplified)", "status": "stable"},
        {"code": "zh-TW", "name": "Chinese (Traditional)", "status": "stable"},
        {"code": "ja-JP", "name": "Japanese", "status": "stable"},
        {"code": "ko-KR", "name": "Korean", "status": "stable"},
        {"code": "ar-SA", "name": "Arabic", "status": "beta"},
        {"code": "he-IL", "name": "Hebrew", "status": "beta"}
    ]
}
EOF
    
    cat "$cache_file"
}

# Validate language code
validate_language_code() {
    local code="$1"
    [[ "$code" =~ ^[a-z]{2}-[A-Z]{2}$ ]] || return 1
    get_available_languages | jq -e ".languages[] | select(.code == \"$code\")" >/dev/null 2>&1
}

# Check if language is installed
is_language_installed() {
    local code="$1"
    jq -e ".languages.installed[] | select(. == \"$code\")" "$MAIN_CONFIG" >/dev/null 2>&1
}

# Install language pack
install_language_pack() {
    local code="$1"
    local force="${2:-false}"
    
    log "INFO" "Installing language pack: $code"
    
    if ! validate_language_code "$code"; then
        log "ERROR" "Invalid language code: $code"
        echo "Error: Invalid language code"
        return 1
    fi
    
    if is_language_installed "$code" && [[ "$force" != "true" ]]; then
        echo "Language already installed: $code"
        return 0
    fi
    
    # Create installation directory
    local install_dir="${LANG_BASE_DIR}/${code}"
    if ! ensure_directory "$install_dir"; then
        return 1
    fi
    
    # Simulate installation
    echo "{\"installed\": \"$(date -Iseconds)\", \"version\": \"$SCRIPT_VERSION\"}" > "${install_dir}/info.json"
    
    # Update configuration
    if acquire_lock; then
        jq ".languages.installed |= (. + [\"$code\"] | unique)" "$MAIN_CONFIG" > "${MAIN_CONFIG}.tmp" && \
            mv "${MAIN_CONFIG}.tmp" "$MAIN_CONFIG"
        release_lock
        
        log "INFO" "Successfully installed: $code"
        echo "Language pack installed: $code"
        return 0
    else
        log "ERROR" "Failed to acquire lock"
        return 1
    fi
}

# Remove language pack
remove_language_pack() {
    local code="$1"
    
    log "INFO" "Removing language pack: $code"
    
    if ! is_language_installed "$code"; then
        echo "Language not installed: $code"
        return 0
    fi
    
    # Check if default language
    local default_lang=$(jq -r '.preferences.default_language' "$MAIN_CONFIG")
    if [[ "$code" == "$default_lang" ]]; then
        echo "Error: Cannot remove default language"
        return 1
    fi
    
    # Remove directory
    rm -rf "${LANG_BASE_DIR}/${code}"
    
    # Update configuration
    if acquire_lock; then
        jq ".languages.installed |= map(select(. != \"$code\"))" "$MAIN_CONFIG" > "${MAIN_CONFIG}.tmp" && \
            mv "${MAIN_CONFIG}.tmp" "$MAIN_CONFIG"
        release_lock
        
        log "INFO" "Successfully removed: $code"
        echo "Language pack removed: $code"
        return 0
    else
        log "ERROR" "Failed to acquire lock"
        return 1
    fi
}

# Set default language
set_default_language() {
    local code="$1"
    
    log "INFO" "Setting default language: $code"
    
    if ! validate_language_code "$code"; then
        echo "Error: Invalid language code"
        return 1
    fi
    
    if ! is_language_installed "$code"; then
        echo "Installing language first..."
        install_language_pack "$code" || return 1
    fi
    
    # Update configuration
    if acquire_lock; then
        jq --arg lang "$code" '.preferences.default_language = $lang' "$MAIN_CONFIG" > "${MAIN_CONFIG}.tmp" && \
            mv "${MAIN_CONFIG}.tmp" "$MAIN_CONFIG"
        release_lock
        
        # Apply settings
        export LANG="${code}.UTF-8"
        export LC_ALL="${code}.UTF-8"
        
        log "INFO" "Default language set to: $code"
        echo "Default language set to: $code"
        echo "Restart Cursor IDE for changes to take effect."
        return 0
    else
        log "ERROR" "Failed to acquire lock"
        return 1
    fi
}

# List installed languages
list_installed_languages() {
    local installed=$(jq -r '.languages.installed[]' "$MAIN_CONFIG" 2>/dev/null)
    local default=$(jq -r '.preferences.default_language' "$MAIN_CONFIG" 2>/dev/null)
    local available=$(get_available_languages)
    
    echo "Installed Languages:"
    echo "─────────────────────────────────────"
    
    if [[ -z "$installed" ]]; then
        echo "  No languages installed"
    else
        echo "$installed" | while read -r code; do
            local info=$(echo "$available" | jq -r ".languages[] | select(.code == \"$code\") | .name")
            local marker=""
            [[ "$code" == "$default" ]] && marker=" (default)"
            echo "  $code - $info$marker"
        done
    fi
    echo "─────────────────────────────────────"
}

# Show language info
show_language_info() {
    local code="$1"
    local info=$(get_available_languages | jq ".languages[] | select(.code == \"$code\")")
    
    if [[ -z "$info" ]]; then
        echo "Error: Language not found: $code"
        return 1
    fi
    
    echo "Language Information:"
    echo "─────────────────────────────────────"
    echo "$info" | jq -r '"Code: \(.code)", "Name: \(.name)", "Status: \(.status)"'
    
    if is_language_installed "$code"; then
        echo "Installation: Installed"
        [[ -d "${LANG_BASE_DIR}/${code}" ]] && echo "Size: $(du -sh "${LANG_BASE_DIR}/${code}" 2>/dev/null | cut -f1)"
    else
        echo "Installation: Not installed"
    fi
    echo "─────────────────────────────────────"
}

# Validate all installations
validate_all_installations() {
    local installed=$(jq -r '.languages.installed[]' "$MAIN_CONFIG" 2>/dev/null)
    local failed=0
    
    echo "Validating Language Installations:"
    echo "─────────────────────────────────────"
    
    echo "$installed" | while read -r code; do
        echo -n "  Validating $code... "
        if [[ -f "${LANG_BASE_DIR}/${code}/info.json" ]]; then
            echo "✓ OK"
        else
            echo "✗ FAILED"
            ((failed++))
        fi
    done
    
    echo "─────────────────────────────────────"
    [[ $failed -eq 0 ]] && echo "All validations passed." || echo "Some validations failed."
}

# Export settings
export_settings() {
    local export_file="${HOME}/cursor_language_settings_${TIMESTAMP}.json"
    
    if cp "$MAIN_CONFIG" "$export_file" 2>/dev/null; then
        chmod 600 "$export_file"
        echo "Settings exported to: $export_file"
        log "INFO" "Settings exported to: $export_file"
    else
        echo "Error: Export failed"
        log "ERROR" "Export failed"
        return 1
    fi
}

# Import settings
import_settings() {
    local import_file="$1"
    
    if [[ ! -f "$import_file" ]]; then
        echo "Error: File not found: $import_file"
        return 1
    fi
    
    if ! jq -e '.' "$import_file" >/dev/null 2>&1; then
        echo "Error: Invalid JSON file"
        return 1
    fi
    
    backup_configuration "$MAIN_CONFIG"
    
    if cp "$import_file" "$MAIN_CONFIG" 2>/dev/null; then
        echo "Settings imported successfully"
        log "INFO" "Settings imported from: $import_file"
        
        # Install missing languages
        local langs=$(jq -r '.languages.installed[]' "$MAIN_CONFIG" 2>/dev/null)
        echo "$langs" | while read -r code; do
            [[ ! -d "${LANG_BASE_DIR}/${code}" ]] && install_language_pack "$code"
        done
    else
        echo "Error: Import failed"
        return 1
    fi
}

# === USER INTERFACE ===

# Show menu
show_menu() {
    local current=$(jq -r '.preferences.default_language' "$MAIN_CONFIG" 2>/dev/null || echo "en-US")
    
    echo "╔════════════════════════════════════════╗"
    echo "║   CURSOR LANGUAGE SELECTOR v${SCRIPT_VERSION}      ║"
    echo "╚════════════════════════════════════════╝"
    echo
    echo "Current Language: $current"
    echo
    echo "Commands:"
    echo "  install <code>   - Install language pack"
    echo "  remove <code>    - Remove language pack"
    echo "  set <code>       - Set default language"
    echo "  list             - List installed languages"
    echo "  info <code>      - Show language info"
    echo "  validate         - Validate installations"
    echo "  export           - Export settings"
    echo "  import <file>    - Import settings"
    echo "  help             - Show this help"
    echo "  quit             - Exit"
    echo
}

# Interactive mode
interactive_mode() {
    while true; do
        show_menu
        read -r -p "Enter command: " cmd args
        
        case "$cmd" in
            install) [[ -n "$args" ]] && install_language_pack "$args" || echo "Error: Specify language code" ;;
            remove) [[ -n "$args" ]] && remove_language_pack "$args" || echo "Error: Specify language code" ;;
            set) [[ -n "$args" ]] && set_default_language "$args" || echo "Error: Specify language code" ;;
            list) list_installed_languages ;;
            info) [[ -n "$args" ]] && show_language_info "$args" || echo "Error: Specify language code" ;;
            validate) validate_all_installations ;;
            export) export_settings ;;
            import) [[ -n "$args" ]] && import_settings "$args" || echo "Error: Specify file path" ;;
            help) ;; # Menu shown next iteration
            quit|exit) echo "Goodbye!"; break ;;
            *) echo "Unknown command: $cmd" ;;
        esac
        
        echo
        read -r -p "Press Enter to continue..."
        clear
    done
}

# Show usage
show_usage() {
    cat << EOF
Cursor IDE Language Selector v${SCRIPT_VERSION}

Usage: $SCRIPT_NAME [command] [arguments]

Commands:
  install <code>    Install language pack
  remove <code>     Remove language pack
  set <code>        Set default language
  list              List installed languages
  info <code>       Show language info
  validate          Validate installations
  export            Export settings
  import <file>     Import settings
  interactive       Interactive mode (default)
  help              Show this help

Examples:
  $SCRIPT_NAME install fr-FR
  $SCRIPT_NAME set ja-JP
  $SCRIPT_NAME list
EOF
}

# === MAIN ===

main() {
    # Initialize
    if ! initialize_directories; then
        echo "Error: Failed to initialize"
        exit 1
    fi
    
    if ! load_configuration "$MAIN_CONFIG"; then
        echo "Error: Failed to load configuration"
        exit 1
    fi
    
    # Parse command
    local cmd="${1:-interactive}"
    shift || true
    
    case "$cmd" in
        install) [[ $# -ge 1 ]] && install_language_pack "$1" || show_usage ;;
        remove) [[ $# -ge 1 ]] && remove_language_pack "$1" || show_usage ;;
        set) [[ $# -ge 1 ]] && set_default_language "$1" || show_usage ;;
        list) list_installed_languages ;;
        info) [[ $# -ge 1 ]] && show_language_info "$1" || show_usage ;;
        validate) validate_all_installations ;;
        export) export_settings ;;
        import) [[ $# -ge 1 ]] && import_settings "$1" || show_usage ;;
        interactive) interactive_mode ;;
        --help|-h|help) show_usage ;;
        --version|-v) echo "Version ${SCRIPT_VERSION}" ;;
        *) echo "Unknown command: $cmd"; show_usage; exit 1 ;;
    esac
}

main "$@"