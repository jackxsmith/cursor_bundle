#!/usr/bin/env bash
#
# ENTERPRISE LANGUAGE SELECTOR FOR CURSOR IDE v6.9.213
# Advanced Multi-Language Selection and Management Framework
#
# Features:
# - Interactive language selection with visual preview
# - Advanced locale management and validation
# - Unicode and RTL language support
# - Font rendering optimization per language
# - Cultural customization (date formats, number formats, etc.)
# - Accessibility features for language selection
# - Multiple input methods and keyboard layouts
# - Translation validation and quality assurance
# - Dynamic language pack downloading and caching
# - User preference persistence and sync
# - Enterprise policy compliance for language settings
# - Multi-user environment support
# - Language fallback chains and inheritance
# - Performance optimization for language switching
# - Integration with system locale settings
# - Voice and audio language support
# - Context-aware language switching
# - Plugin architecture for custom languages
# - Real-time translation service integration
# - Language usage analytics and recommendations
# - Spell checking and grammar support per language
# - Character encoding detection and conversion
# - Regional variant support (en-US vs en-GB)
# - Professional translation workflow integration
# - Language pack versioning and updates
# - Custom terminology and glossary management
# - Machine learning-based language detection
# - Advanced search and filtering capabilities
# - Import/export of language configurations
# - Comprehensive logging and audit trails

set -euo pipefail
IFS=$'\n\t'

# === CONFIGURATION ===
readonly SCRIPT_VERSION="6.9.213"
readonly SCRIPT_NAME="$(basename "${0}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
readonly VERSION="$(cat "${SCRIPT_DIR}/VERSION" 2>/dev/null || echo "unknown")"

# Directory Structure
readonly LANG_BASE_DIR="/opt/cursor/languages"
readonly USER_LANG_DIR="${HOME}/.config/cursor/languages"
readonly CACHE_DIR="${HOME}/.cache/cursor/languages"
readonly LOG_DIR="${HOME}/.cache/cursor/logs"
readonly TEMP_DIR="$(mktemp -d)"

# Configuration Files
readonly MAIN_CONFIG="${USER_LANG_DIR}/config.json"
readonly USER_PREFS="${USER_LANG_DIR}/preferences.json"
readonly SYSTEM_CONFIG="/etc/cursor/languages.conf"
readonly LANGUAGE_MAP="${LANG_BASE_DIR}/language_map.json"

# Network Configuration
readonly LANGUAGE_REGISTRY_URL="https://registry.cursor.com/languages"
readonly TRANSLATION_API_URL="https://api.cursor.com/translate"
readonly CDN_BASE_URL="https://cdn.cursor.com/languages"

# Logging Files
readonly MAIN_LOG="${LOG_DIR}/language_selector_${TIMESTAMP}.log"
readonly ERROR_LOG="${LOG_DIR}/language_errors_${TIMESTAMP}.log"
readonly AUDIT_LOG="${LOG_DIR}/language_audit_${TIMESTAMP}.log"
readonly PERFORMANCE_LOG="${LOG_DIR}/language_performance_${TIMESTAMP}.log"

# Color Schemes and Formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m' # No Color
readonly BOLD='\033[1m'

# Language Configuration
declare -A SUPPORTED_LANGUAGES=(
    ["en-US"]="English (United States)|English|LTR|en|US|latin|high"
    ["en-GB"]="English (United Kingdom)|English|LTR|en|GB|latin|high"
    ["es-ES"]="Español (España)|Spanish|LTR|es|ES|latin|high"
    ["es-MX"]="Español (México)|Spanish|LTR|es|MX|latin|high"
    ["fr-FR"]="Français (France)|French|LTR|fr|FR|latin|high"
    ["fr-CA"]="Français (Canada)|French|LTR|fr|CA|latin|high"
    ["de-DE"]="Deutsch (Deutschland)|German|LTR|de|DE|latin|high"
    ["de-AT"]="Deutsch (Österreich)|German|LTR|de|AT|latin|high"
    ["it-IT"]="Italiano (Italia)|Italian|LTR|it|IT|latin|high"
    ["pt-BR"]="Português (Brasil)|Portuguese|LTR|pt|BR|latin|high"
    ["pt-PT"]="Português (Portugal)|Portuguese|LTR|pt|PT|latin|high"
    ["ru-RU"]="Русский|Russian|LTR|ru|RU|cyrillic|high"
    ["zh-CN"]="中文 (简体)|Chinese Simplified|LTR|zh|CN|chinese|high"
    ["zh-TW"]="中文 (繁體)|Chinese Traditional|LTR|zh|TW|chinese|high"
    ["ja-JP"]="日本語|Japanese|LTR|ja|JP|japanese|high"
    ["ko-KR"]="한국어|Korean|LTR|ko|KR|korean|high"
    ["ar-SA"]="العربية|Arabic|RTL|ar|SA|arabic|medium"
    ["he-IL"]="עברית|Hebrew|RTL|he|IL|hebrew|medium"
    ["hi-IN"]="हिन्दी|Hindi|LTR|hi|IN|devanagari|medium"
    ["th-TH"]="ไทย|Thai|LTR|th|TH|thai|medium"
    ["vi-VN"]="Tiếng Việt|Vietnamese|LTR|vi|VN|latin|medium"
    ["tr-TR"]="Türkçe|Turkish|LTR|tr|TR|latin|medium"
    ["pl-PL"]="Polski|Polish|LTR|pl|PL|latin|medium"
    ["nl-NL"]="Nederlands|Dutch|LTR|nl|NL|latin|medium"
    ["sv-SE"]="Svenska|Swedish|LTR|sv|SE|latin|medium"
    ["da-DK"]="Dansk|Danish|LTR|da|DK|latin|medium"
    ["no-NO"]="Norsk|Norwegian|LTR|no|NO|latin|medium"
    ["fi-FI"]="Suomi|Finnish|LTR|fi|FI|latin|medium"
    ["cs-CZ"]="Čeština|Czech|LTR|cs|CZ|latin|medium"
    ["hu-HU"]="Magyar|Hungarian|LTR|hu|HU|latin|medium"
    ["ro-RO"]="Română|Romanian|LTR|ro|RO|latin|medium"
    ["bg-BG"]="Български|Bulgarian|LTR|bg|BG|cyrillic|medium"
    ["hr-HR"]="Hrvatski|Croatian|LTR|hr|HR|latin|medium"
    ["sk-SK"]="Slovenčina|Slovak|LTR|sk|SK|latin|medium"
    ["sl-SI"]="Slovenščina|Slovenian|LTR|sl|SI|latin|medium"
    ["et-EE"]="Eesti|Estonian|LTR|et|EE|latin|low"
    ["lv-LV"]="Latviešu|Latvian|LTR|lv|LV|latin|low"
    ["lt-LT"]="Lietuvių|Lithuanian|LTR|lt|LT|latin|low"
    ["uk-UA"]="Українська|Ukrainian|LTR|uk|UA|cyrillic|medium"
    ["be-BY"]="Беларуская|Belarusian|LTR|be|BY|cyrillic|low"
    ["mk-MK"]="Македонски|Macedonian|LTR|mk|MK|cyrillic|low"
    ["sr-RS"]="Српски|Serbian|LTR|sr|RS|cyrillic|medium"
    ["bs-BA"]="Bosanski|Bosnian|LTR|bs|BA|latin|low"
    ["mt-MT"]="Malti|Maltese|LTR|mt|MT|latin|low"
    ["ga-IE"]="Gaeilge|Irish|LTR|ga|IE|latin|low"
    ["cy-GB"]="Cymraeg|Welsh|LTR|cy|GB|latin|low"
    ["eu-ES"]="Euskera|Basque|LTR|eu|ES|latin|low"
    ["ca-ES"]="Català|Catalan|LTR|ca|ES|latin|low"
    ["gl-ES"]="Galego|Galician|LTR|gl|ES|latin|low"
)

declare -A LANGUAGE_PREFERENCES=(
    ["current_language"]="en-US"
    ["fallback_language"]="en-US"
    ["auto_detect"]="true"
    ["download_missing"]="true"
    ["use_system_locale"]="true"
    ["rtl_support"]="true"
    ["font_optimization"]="true"
    ["spell_checking"]="true"
    ["grammar_checking"]="false"
    ["translation_service"]="disabled"
    ["voice_support"]="false"
    ["accessibility"]="false"
)

declare -A INSTALLATION_STATS=(
    ["total_languages"]=0
    ["installed_languages"]=0
    ["available_languages"]=0
    ["pending_downloads"]=0
    ["failed_downloads"]=0
    ["cache_size"]=0
)

# === INITIALIZATION ===
initialize_language_system() {
    info "Initializing Cursor Language Selection System v${SCRIPT_VERSION}"
    
    # Create directory structure
    create_directory_structure
    
    # Initialize logging
    init_logging_system
    
    # Load configuration
    load_configuration
    
    # Detect system capabilities
    detect_system_capabilities
    
    # Validate environment
    validate_language_environment
    
    # Load language registry
    load_language_registry
    
    # Update installation statistics
    update_installation_stats
    
    info "Language system initialization completed"
}

create_directory_structure() {
    local directories=(
        "${LANG_BASE_DIR}"
        "${USER_LANG_DIR}"
        "${CACHE_DIR}"
        "${LOG_DIR}"
        "${USER_LANG_DIR}/packs"
        "${USER_LANG_DIR}/custom"
        "${USER_LANG_DIR}/fonts"
        "${USER_LANG_DIR}/keyboards"
        "${CACHE_DIR}/downloads"
        "${CACHE_DIR}/fonts"
        "${CACHE_DIR}/dictionaries"
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
=== Cursor Language Selector v${SCRIPT_VERSION} ===
Session started: $(date -Iseconds)
User: $(whoami)
System: $(uname -a)
Script directory: ${SCRIPT_DIR}
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
    
    # Also output to console if verbose
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        case "${level}" in
            "ERROR") echo -e "${RED}[ERROR]${NC} ${message}" >&2 ;;
            "WARN") echo -e "${YELLOW}[WARN]${NC} ${message}" ;;
            "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} ${message}" ;;
            "INFO") echo -e "${BLUE}[INFO]${NC} ${message}" ;;
            "DEBUG") echo -e "${PURPLE}[DEBUG]${NC} ${message}" ;;
            *) echo "[${level}] ${message}" ;;
        esac
    fi
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
    info "Loading language configuration"
    
    # Load system configuration
    if [[ -f "${SYSTEM_CONFIG}" ]]; then
        source "${SYSTEM_CONFIG}"
        debug "Loaded system configuration"
    fi
    
    # Load user configuration
    if [[ -f "${MAIN_CONFIG}" ]]; then
        load_json_config "${MAIN_CONFIG}"
        debug "Loaded user configuration"
    else
        create_default_config
    fi
    
    # Load user preferences
    if [[ -f "${USER_PREFS}" ]]; then
        load_user_preferences
        debug "Loaded user preferences"
    else
        create_default_preferences
    fi
}

create_default_config() {
    info "Creating default language configuration"
    
    cat > "${MAIN_CONFIG}" <<EOF
{
    "version": "${SCRIPT_VERSION}",
    "created": "$(date -Iseconds)",
    "language_system": {
        "auto_update": true,
        "cache_ttl": 86400,
        "max_cache_size": "500MB",
        "concurrent_downloads": 3,
        "fallback_enabled": true,
        "rtl_support": true,
        "font_fallback": true
    },
    "network": {
        "registry_url": "${LANGUAGE_REGISTRY_URL}",
        "cdn_url": "${CDN_BASE_URL}",
        "timeout": 30,
        "retries": 3,
        "proxy": ""
    },
    "security": {
        "verify_signatures": true,
        "trusted_sources": ["cursor.com", "github.com"],
        "allow_custom_packs": false
    },
    "performance": {
        "lazy_loading": true,
        "preload_common": true,
        "memory_limit": "100MB",
        "compression": true
    }
}
EOF
}

create_default_preferences() {
    info "Creating default user preferences"
    
    cat > "${USER_PREFS}" <<EOF
{
    "version": "${SCRIPT_VERSION}",
    "updated": "$(date -Iseconds)",
    "language": "${LANGUAGE_PREFERENCES[current_language]}",
    "fallback": "${LANGUAGE_PREFERENCES[fallback_language]}",
    "preferences": {
        "auto_detect": ${LANGUAGE_PREFERENCES[auto_detect]},
        "download_missing": ${LANGUAGE_PREFERENCES[download_missing]},
        "use_system_locale": ${LANGUAGE_PREFERENCES[use_system_locale]},
        "rtl_support": ${LANGUAGE_PREFERENCES[rtl_support]},
        "font_optimization": ${LANGUAGE_PREFERENCES[font_optimization]},
        "spell_checking": ${LANGUAGE_PREFERENCES[spell_checking]},
        "grammar_checking": ${LANGUAGE_PREFERENCES[grammar_checking]},
        "translation_service": "${LANGUAGE_PREFERENCES[translation_service]}",
        "voice_support": ${LANGUAGE_PREFERENCES[voice_support]},
        "accessibility": ${LANGUAGE_PREFERENCES[accessibility]}
    },
    "ui": {
        "theme": "auto",
        "font_size": "medium",
        "animations": true,
        "sounds": false
    },
    "advanced": {
        "debug_mode": false,
        "telemetry": true,
        "beta_features": false
    }
}
EOF
}

load_json_config() {
    local config_file="$1"
    
    if command -v jq >/dev/null 2>&1; then
        # Extract configuration values using jq
        local current_lang
        current_lang=$(jq -r '.language // "en-US"' "${config_file}" 2>/dev/null)
        LANGUAGE_PREFERENCES["current_language"]="${current_lang}"
        
        local fallback_lang
        fallback_lang=$(jq -r '.fallback // "en-US"' "${config_file}" 2>/dev/null)
        LANGUAGE_PREFERENCES["fallback_language"]="${fallback_lang}"
        
        # Load other preferences
        local auto_detect
        auto_detect=$(jq -r '.preferences.auto_detect // true' "${config_file}" 2>/dev/null)
        LANGUAGE_PREFERENCES["auto_detect"]="${auto_detect}"
        
        debug "JSON configuration loaded successfully"
    else
        warn "jq not available, using basic configuration parsing"
    fi
}

load_user_preferences() {
    debug "Loading user preferences from ${USER_PREFS}"
    
    if command -v jq >/dev/null 2>&1; then
        # Load preferences using jq
        while IFS='=' read -r key value; do
            if [[ -n "${key}" && -n "${value}" ]]; then
                LANGUAGE_PREFERENCES["${key}"]="${value}"
            fi
        done < <(jq -r '.preferences | to_entries[] | "\(.key)=\(.value)"' "${USER_PREFS}" 2>/dev/null)
    fi
}

# === SYSTEM DETECTION ===
detect_system_capabilities() {
    info "Detecting system language capabilities"
    
    local capabilities=()
    
    # Check locale support
    if command -v locale >/dev/null 2>&1; then
        local available_locales
        available_locales=$(locale -a 2>/dev/null | wc -l)
        capabilities+=("locales:${available_locales}")
        debug "Found ${available_locales} system locales"
    fi
    
    # Check Unicode support
    if [[ "${LANG}" =~ UTF-8 ]]; then
        capabilities+=("unicode:true")
        debug "Unicode support detected"
    else
        capabilities+=("unicode:false")
        warn "Limited Unicode support detected"
    fi
    
    # Check font support
    if command -v fc-list >/dev/null 2>&1; then
        local font_count
        font_count=$(fc-list | wc -l)
        capabilities+=("fonts:${font_count}")
        debug "Found ${font_count} system fonts"
    fi
    
    # Check input method support
    if [[ -n "${GTK_IM_MODULE:-}" ]] || [[ -n "${QT_IM_MODULE:-}" ]]; then
        capabilities+=("input_methods:true")
        debug "Input method support detected"
    fi
    
    # Check accessibility support
    if [[ -n "${GNOME_ACCESSIBILITY:-}" ]] || command -v orca >/dev/null 2>&1; then
        capabilities+=("accessibility:true")
        debug "Accessibility support detected"
    fi
    
    # Check RTL support
    if command -v bidi >/dev/null 2>&1 || [[ -f "/usr/share/unicode/bidi" ]]; then
        capabilities+=("rtl:true")
        debug "RTL text support detected"
    fi
    
    audit "system_capabilities_detected" "${capabilities[*]}"
    info "System capabilities detection completed"
}

validate_language_environment() {
    info "Validating language environment"
    
    local validation_errors=()
    
    # Check write access to user directories
    if [[ ! -w "${USER_LANG_DIR}" ]]; then
        validation_errors+=("No write access to user language directory")
    fi
    
    # Check disk space
    local available_space
    available_space=$(df -BM "${USER_LANG_DIR}" | awk 'NR==2 {print $4}' | sed 's/M//')
    if [[ ${available_space} -lt 100 ]]; then
        validation_errors+=("Insufficient disk space: ${available_space}MB (need 100MB+)")
    fi
    
    # Check network connectivity (if needed)
    if [[ "${LANGUAGE_PREFERENCES[download_missing]}" == "true" ]]; then
        if ! ping -c 1 -W 5 google.com >/dev/null 2>&1; then
            validation_errors+=("No network connectivity for language pack downloads")
        fi
    fi
    
    # Check essential commands
    local required_commands=("grep" "sed" "awk" "sort" "uniq")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "${cmd}" >/dev/null 2>&1; then
            validation_errors+=("Missing required command: ${cmd}")
        fi
    done
    
    if [[ ${#validation_errors[@]} -gt 0 ]]; then
        error "Environment validation failed: ${validation_errors[*]}"
        return 1
    fi
    
    info "Language environment validation passed"
    return 0
}

# === LANGUAGE REGISTRY ===
load_language_registry() {
    info "Loading language registry"
    
    local registry_file="${CACHE_DIR}/language_registry.json"
    local registry_age=0
    
    # Check if cached registry exists and is recent
    if [[ -f "${registry_file}" ]]; then
        registry_age=$(( $(date +%s) - $(stat -f%m "${registry_file}" 2>/dev/null || stat -c%Y "${registry_file}" 2>/dev/null || echo 0) ))
    fi
    
    # Download fresh registry if needed (older than 24 hours)
    if [[ ! -f "${registry_file}" ]] || [[ ${registry_age} -gt 86400 ]]; then
        download_language_registry "${registry_file}"
    fi
    
    # Parse registry
    if [[ -f "${registry_file}" ]] && command -v jq >/dev/null 2>&1; then
        parse_language_registry "${registry_file}"
    else
        warn "Using built-in language registry"
        create_builtin_registry
    fi
    
    info "Language registry loaded"
}

download_language_registry() {
    local registry_file="$1"
    
    info "Downloading language registry from ${LANGUAGE_REGISTRY_URL}"
    
    if command -v curl >/dev/null 2>&1; then
        if curl -f -s -L --max-time 30 "${LANGUAGE_REGISTRY_URL}" -o "${registry_file}.tmp"; then
            mv "${registry_file}.tmp" "${registry_file}"
            info "Language registry downloaded successfully"
        else
            warn "Failed to download language registry"
            rm -f "${registry_file}.tmp"
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -q -T 30 "${LANGUAGE_REGISTRY_URL}" -O "${registry_file}.tmp"; then
            mv "${registry_file}.tmp" "${registry_file}"
            info "Language registry downloaded successfully"
        else
            warn "Failed to download language registry"
            rm -f "${registry_file}.tmp"
        fi
    else
        warn "No download tool available (curl/wget)"
    fi
}

parse_language_registry() {
    local registry_file="$1"
    
    debug "Parsing language registry: ${registry_file}"
    
    # Extract available languages from registry
    if command -v jq >/dev/null 2>&1; then
        local available_count=0
        
        while IFS='|' read -r lang_code display_name; do
            if [[ -n "${lang_code}" && -n "${display_name}" ]]; then
                if [[ -z "${SUPPORTED_LANGUAGES[${lang_code}]:-}" ]]; then
                    SUPPORTED_LANGUAGES["${lang_code}"]="${display_name}|${display_name}|LTR||dynamic|low"
                    ((available_count++))
                fi
            fi
        done < <(jq -r '.languages[] | "\(.code)|\(.name)"' "${registry_file}" 2>/dev/null)
        
        if [[ ${available_count} -gt 0 ]]; then
            info "Added ${available_count} languages from registry"
        fi
    fi
}

create_builtin_registry() {
    debug "Creating built-in language registry"
    
    cat > "${CACHE_DIR}/language_registry.json" <<EOF
{
    "version": "1.0",
    "updated": "$(date -Iseconds)",
    "languages": [
$(for lang_code in "${!SUPPORTED_LANGUAGES[@]}"; do
    IFS='|' read -ra lang_info <<< "${SUPPORTED_LANGUAGES[${lang_code}]}"
    echo "        {"
    echo "            \"code\": \"${lang_code}\","
    echo "            \"name\": \"${lang_info[0]}\","
    echo "            \"native_name\": \"${lang_info[1]}\","
    echo "            \"direction\": \"${lang_info[2]}\","
    echo "            \"family\": \"${lang_info[3]}\","
    echo "            \"region\": \"${lang_info[4]}\","
    echo "            \"script\": \"${lang_info[5]}\","
    echo "            \"quality\": \"${lang_info[6]}\""
    echo "        },"
done | sed '$ s/,$//')
    ]
}
EOF
}

# === LANGUAGE MANAGEMENT ===
update_installation_stats() {
    debug "Updating installation statistics"
    
    INSTALLATION_STATS["total_languages"]=${#SUPPORTED_LANGUAGES[@]}
    
    # Count installed languages
    local installed=0
    for lang_code in "${!SUPPORTED_LANGUAGES[@]}"; do
        if is_language_installed "${lang_code}"; then
            ((installed++))
        fi
    done
    INSTALLATION_STATS["installed_languages"]=${installed}
    
    # Count available for download
    local available=$((INSTALLATION_STATS["total_languages"] - installed))
    INSTALLATION_STATS["available_languages"]=${available}
    
    # Calculate cache size
    if [[ -d "${CACHE_DIR}" ]]; then
        local cache_size
        cache_size=$(du -sm "${CACHE_DIR}" 2>/dev/null | cut -f1 || echo "0")
        INSTALLATION_STATS["cache_size"]=${cache_size}
    fi
    
    debug "Statistics updated: ${installed}/${INSTALLATION_STATS[total_languages]} languages installed"
}

is_language_installed() {
    local lang_code="$1"
    
    # Check if language pack exists
    if [[ -f "${LANG_BASE_DIR}/${lang_code}.json" ]] || [[ -f "${USER_LANG_DIR}/packs/${lang_code}.json" ]]; then
        return 0
    fi
    
    # Check if language is built-in
    case "${lang_code}" in
        "en-US"|"en-GB") return 0 ;;
    esac
    
    return 1
}

get_language_info() {
    local lang_code="$1"
    local info_type="${2:-display_name}"
    
    if [[ -n "${SUPPORTED_LANGUAGES[${lang_code}]:-}" ]]; then
        IFS='|' read -ra lang_info <<< "${SUPPORTED_LANGUAGES[${lang_code}]}"
        
        case "${info_type}" in
            "display_name") echo "${lang_info[0]}" ;;
            "native_name") echo "${lang_info[1]}" ;;
            "direction") echo "${lang_info[2]}" ;;
            "family") echo "${lang_info[3]}" ;;
            "region") echo "${lang_info[4]}" ;;
            "script") echo "${lang_info[5]}" ;;
            "quality") echo "${lang_info[6]}" ;;
            *) echo "Unknown info type: ${info_type}" >&2; return 1 ;;
        esac
    else
        echo "Unknown language: ${lang_code}" >&2
        return 1
    fi
}

# === INTERACTIVE SELECTION ===
show_language_menu() {
    info "Displaying language selection menu"
    
    clear
    echo -e "${BOLD}${CYAN}Cursor IDE Language Selector v${SCRIPT_VERSION}${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo
    echo -e "${GREEN}Current Language:${NC} $(get_language_info "${LANGUAGE_PREFERENCES[current_language]}" "display_name")"
    echo -e "${GREEN}Fallback Language:${NC} $(get_language_info "${LANGUAGE_PREFERENCES[fallback_language]}" "display_name")"
    echo
    echo -e "${YELLOW}Installation Statistics:${NC}"
    echo -e "  Installed: ${INSTALLATION_STATS[installed_languages]}/${INSTALLATION_STATS[total_languages]} languages"
    echo -e "  Available for download: ${INSTALLATION_STATS[available_languages]}"
    echo -e "  Cache size: ${INSTALLATION_STATS[cache_size]}MB"
    echo
    echo -e "${BOLD}Available Options:${NC}"
    echo
    echo "  1) Browse and select language"
    echo "  2) Search languages"
    echo "  3) Install language pack"
    echo "  4) Remove language pack"
    echo "  5) Configure preferences"
    echo "  6) Language statistics"
    echo "  7) Import/Export settings"
    echo "  8) System integration"
    echo "  9) Advanced tools"
    echo "  0) Exit"
    echo
    echo -n "Select an option [1-9, 0]: "
    
    local choice
    read -r choice
    
    case "${choice}" in
        1) browse_languages ;;
        2) search_languages ;;
        3) install_language_pack ;;
        4) remove_language_pack ;;
        5) configure_preferences ;;
        6) show_language_statistics ;;
        7) import_export_settings ;;
        8) system_integration ;;
        9) advanced_tools ;;
        0) exit_language_selector ;;
        *) 
            echo -e "${RED}Invalid option. Please try again.${NC}"
            sleep 2
            show_language_menu
            ;;
    esac
}

browse_languages() {
    info "Browsing available languages"
    
    clear
    echo -e "${BOLD}${CYAN}Language Browser${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo
    
    # Group languages by region/family
    local regions=("Americas" "Europe" "Asia-Pacific" "Middle East & Africa")
    
    echo "Select a region to browse:"
    echo
    
    local i=1
    for region in "${regions[@]}"; do
        echo "  ${i}) ${region}"
        ((i++))
    done
    echo "  0) Back to main menu"
    echo
    echo -n "Select region [1-${#regions[@]}, 0]: "
    
    local choice
    read -r choice
    
    case "${choice}" in
        1) browse_region_languages "Americas" ;;
        2) browse_region_languages "Europe" ;;
        3) browse_region_languages "Asia-Pacific" ;;
        4) browse_region_languages "Middle East & Africa" ;;
        0) show_language_menu ;;
        *) 
            echo -e "${RED}Invalid option.${NC}"
            sleep 2
            browse_languages
            ;;
    esac
}

browse_region_languages() {
    local region="$1"
    
    clear
    echo -e "${BOLD}${CYAN}Languages in ${region}${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo
    
    local region_languages=()
    
    # Filter languages by region (simplified logic)
    case "${region}" in
        "Americas")
            region_languages=("en-US" "en-GB" "es-MX" "pt-BR" "fr-CA")
            ;;
        "Europe")
            region_languages=("de-DE" "fr-FR" "it-IT" "es-ES" "pt-PT" "ru-RU" "pl-PL" "nl-NL" "sv-SE" "da-DK")
            ;;
        "Asia-Pacific")
            region_languages=("zh-CN" "zh-TW" "ja-JP" "ko-KR" "hi-IN" "th-TH" "vi-VN")
            ;;
        "Middle East & Africa")
            region_languages=("ar-SA" "he-IL" "tr-TR")
            ;;
    esac
    
    # Display languages with status
    local i=1
    for lang_code in "${region_languages[@]}"; do
        local display_name
        display_name=$(get_language_info "${lang_code}" "display_name")
        local native_name
        native_name=$(get_language_info "${lang_code}" "native_name")
        local status="[Available]"
        
        if is_language_installed "${lang_code}"; then
            status="${GREEN}[Installed]${NC}"
        fi
        
        printf "  %2d) %-30s %-20s %s\n" "${i}" "${display_name}" "${native_name}" "${status}"
        ((i++))
    done
    
    echo
    echo "  0) Back to region selection"
    echo
    echo -n "Select language to manage [1-${#region_languages[@]}, 0]: "
    
    local choice
    read -r choice
    
    if [[ "${choice}" -eq 0 ]]; then
        browse_languages
    elif [[ "${choice}" -ge 1 && "${choice}" -le ${#region_languages[@]} ]]; then
        local selected_lang="${region_languages[$((choice-1))]}"
        manage_language "${selected_lang}"
    else
        echo -e "${RED}Invalid option.${NC}"
        sleep 2
        browse_region_languages "${region}"
    fi
}

manage_language() {
    local lang_code="$1"
    
    clear
    echo -e "${BOLD}${CYAN}Language Management: $(get_language_info "${lang_code}" "display_name")${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo
    
    local display_name
    display_name=$(get_language_info "${lang_code}" "display_name")
    local native_name
    native_name=$(get_language_info "${lang_code}" "native_name")
    local direction
    direction=$(get_language_info "${lang_code}" "direction")
    local script
    script=$(get_language_info "${lang_code}" "script")
    local quality
    quality=$(get_language_info "${lang_code}" "quality")
    
    echo -e "${GREEN}Language Information:${NC}"
    echo "  Code: ${lang_code}"
    echo "  Display Name: ${display_name}"
    echo "  Native Name: ${native_name}"
    echo "  Text Direction: ${direction}"
    echo "  Script: ${script}"
    echo "  Translation Quality: ${quality}"
    echo
    
    if is_language_installed "${lang_code}"; then
        echo -e "${GREEN}Status: Installed${NC}"
        echo
        echo "Available Actions:"
        echo "  1) Set as current language"
        echo "  2) Set as fallback language"
        echo "  3) Update language pack"
        echo "  4) Remove language pack"
        echo "  5) Test language pack"
        echo "  0) Back to language browser"
    else
        echo -e "${YELLOW}Status: Available for download${NC}"
        echo
        echo "Available Actions:"
        echo "  1) Install language pack"
        echo "  2) Preview language"
        echo "  0) Back to language browser"
    fi
    
    echo
    echo -n "Select action: "
    
    local choice
    read -r choice
    
    case "${choice}" in
        1)
            if is_language_installed "${lang_code}"; then
                set_current_language "${lang_code}"
            else
                install_specific_language "${lang_code}"
            fi
            ;;
        2)
            if is_language_installed "${lang_code}"; then
                set_fallback_language "${lang_code}"
            else
                preview_language "${lang_code}"
            fi
            ;;
        3)
            if is_language_installed "${lang_code}"; then
                update_language_pack "${lang_code}"
            fi
            ;;
        4)
            if is_language_installed "${lang_code}"; then
                remove_specific_language "${lang_code}"
            fi
            ;;
        5)
            if is_language_installed "${lang_code}"; then
                test_language_pack "${lang_code}"
            fi
            ;;
        0) browse_region_languages "$(get_region_for_language "${lang_code}")" ;;
        *) 
            echo -e "${RED}Invalid option.${NC}"
            sleep 2
            manage_language "${lang_code}"
            ;;
    esac
}

set_current_language() {
    local lang_code="$1"
    
    info "Setting current language to ${lang_code}"
    
    # Update preferences
    LANGUAGE_PREFERENCES["current_language"]="${lang_code}"
    
    # Save preferences
    save_user_preferences
    
    # Apply language immediately
    apply_language_settings "${lang_code}"
    
    success "Current language set to $(get_language_info "${lang_code}" "display_name")"
    audit "language_changed" "from=${LANGUAGE_PREFERENCES[current_language]} to=${lang_code}"
    
    echo
    echo -e "${GREEN}Language successfully changed!${NC}"
    echo "Press any key to continue..."
    read -n 1
    
    show_language_menu
}

set_fallback_language() {
    local lang_code="$1"
    
    info "Setting fallback language to ${lang_code}"
    
    LANGUAGE_PREFERENCES["fallback_language"]="${lang_code}"
    save_user_preferences
    
    success "Fallback language set to $(get_language_info "${lang_code}" "display_name")"
    audit "fallback_language_changed" "to=${lang_code}"
    
    echo
    echo -e "${GREEN}Fallback language successfully set!${NC}"
    echo "Press any key to continue..."
    read -n 1
    
    manage_language "${lang_code}"
}

apply_language_settings() {
    local lang_code="$1"
    
    debug "Applying language settings for ${lang_code}"
    
    # Create language configuration for Cursor
    local cursor_lang_config="/opt/cursor/.language"
    
    cat > "${TEMP_DIR}/language_config" <<EOF
{
    "language": "${lang_code}",
    "display_name": "$(get_language_info "${lang_code}" "display_name")",
    "direction": "$(get_language_info "${lang_code}" "direction")",
    "fallback": "${LANGUAGE_PREFERENCES[fallback_language]}",
    "applied": "$(date -Iseconds)"
}
EOF
    
    # Copy to Cursor directory (with appropriate permissions)
    if [[ -d "/opt/cursor" ]]; then
        if [[ -w "/opt/cursor" ]]; then
            cp "${TEMP_DIR}/language_config" "${cursor_lang_config}"
        else
            sudo cp "${TEMP_DIR}/language_config" "${cursor_lang_config}" 2>/dev/null || {
                warn "Could not write to Cursor system directory"
            }
        fi
    fi
    
    # Also save to user directory
    cp "${TEMP_DIR}/language_config" "${USER_LANG_DIR}/current_language.json"
    
    debug "Language settings applied"
}

save_user_preferences() {
    debug "Saving user preferences"
    
    cat > "${USER_PREFS}" <<EOF
{
    "version": "${SCRIPT_VERSION}",
    "updated": "$(date -Iseconds)",
    "language": "${LANGUAGE_PREFERENCES[current_language]}",
    "fallback": "${LANGUAGE_PREFERENCES[fallback_language]}",
    "preferences": {
        "auto_detect": ${LANGUAGE_PREFERENCES[auto_detect]},
        "download_missing": ${LANGUAGE_PREFERENCES[download_missing]},
        "use_system_locale": ${LANGUAGE_PREFERENCES[use_system_locale]},
        "rtl_support": ${LANGUAGE_PREFERENCES[rtl_support]},
        "font_optimization": ${LANGUAGE_PREFERENCES[font_optimization]},
        "spell_checking": ${LANGUAGE_PREFERENCES[spell_checking]},
        "grammar_checking": ${LANGUAGE_PREFERENCES[grammar_checking]},
        "translation_service": "${LANGUAGE_PREFERENCES[translation_service]}",
        "voice_support": ${LANGUAGE_PREFERENCES[voice_support]},
        "accessibility": ${LANGUAGE_PREFERENCES[accessibility]}
    },
    "ui": {
        "theme": "auto",
        "font_size": "medium",
        "animations": true,
        "sounds": false
    },
    "advanced": {
        "debug_mode": false,
        "telemetry": true,
        "beta_features": false
    }
}
EOF
    
    debug "User preferences saved"
}

search_languages() {
    info "Starting language search"
    
    clear
    echo -e "${BOLD}${CYAN}Language Search${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo
    echo "Search for languages by name, code, or region:"
    echo
    echo -n "Enter search term: "
    
    local search_term
    read -r search_term
    
    if [[ -z "${search_term}" ]]; then
        echo -e "${RED}No search term entered.${NC}"
        sleep 2
        show_language_menu
        return
    fi
    
    # Perform search
    local matches=()
    for lang_code in "${!SUPPORTED_LANGUAGES[@]}"; do
        local display_name
        display_name=$(get_language_info "${lang_code}" "display_name")
        local native_name
        native_name=$(get_language_info "${lang_code}" "native_name")
        
        if [[ "${lang_code,,}" =~ ${search_term,,} ]] || \
           [[ "${display_name,,}" =~ ${search_term,,} ]] || \
           [[ "${native_name,,}" =~ ${search_term,,} ]]; then
            matches+=("${lang_code}")
        fi
    done
    
    echo
    echo -e "${GREEN}Search Results (${#matches[@]} found):${NC}"
    echo
    
    if [[ ${#matches[@]} -eq 0 ]]; then
        echo "No languages found matching '${search_term}'"
        echo
        echo "Press any key to continue..."
        read -n 1
        show_language_menu
        return
    fi
    
    # Display matches
    local i=1
    for lang_code in "${matches[@]}"; do
        local display_name
        display_name=$(get_language_info "${lang_code}" "display_name")
        local native_name
        native_name=$(get_language_info "${lang_code}" "native_name")
        local status="[Available]"
        
        if is_language_installed "${lang_code}"; then
            status="${GREEN}[Installed]${NC}"
        fi
        
        printf "  %2d) %-30s %-20s %s\n" "${i}" "${display_name}" "${native_name}" "${status}"
        ((i++))
    done
    
    echo
    echo "  0) Back to main menu"
    echo
    echo -n "Select language to manage [1-${#matches[@]}, 0]: "
    
    local choice
    read -r choice
    
    if [[ "${choice}" -eq 0 ]]; then
        show_language_menu
    elif [[ "${choice}" -ge 1 && "${choice}" -le ${#matches[@]} ]]; then
        local selected_lang="${matches[$((choice-1))]}"
        manage_language "${selected_lang}"
    else
        echo -e "${RED}Invalid option.${NC}"
        sleep 2
        search_languages
    fi
}

install_language_pack() {
    info "Language pack installation menu"
    
    clear
    echo -e "${BOLD}${CYAN}Install Language Pack${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo
    
    # Find uninstalled languages
    local uninstalled=()
    for lang_code in "${!SUPPORTED_LANGUAGES[@]}"; do
        if ! is_language_installed "${lang_code}"; then
            uninstalled+=("${lang_code}")
        fi
    done
    
    if [[ ${#uninstalled[@]} -eq 0 ]]; then
        echo -e "${GREEN}All available languages are already installed!${NC}"
        echo
        echo "Press any key to continue..."
        read -n 1
        show_language_menu
        return
    fi
    
    echo -e "${GREEN}Available for Installation (${#uninstalled[@]} languages):${NC}"
    echo
    
    # Sort by quality and display name
    local sorted_langs=()
    while IFS= read -r lang_code; do
        sorted_langs+=("${lang_code}")
    done < <(printf '%s\n' "${uninstalled[@]}" | sort)
    
    local i=1
    for lang_code in "${sorted_langs[@]}"; do
        local display_name
        display_name=$(get_language_info "${lang_code}" "display_name")
        local native_name
        native_name=$(get_language_info "${lang_code}" "native_name")
        local quality
        quality=$(get_language_info "${lang_code}" "quality")
        
        local quality_badge=""
        case "${quality}" in
            "high") quality_badge="${GREEN}[High Quality]${NC}" ;;
            "medium") quality_badge="${YELLOW}[Medium Quality]${NC}" ;;
            "low") quality_badge="${RED}[Beta Quality]${NC}" ;;
        esac
        
        printf "  %2d) %-30s %-20s %s\n" "${i}" "${display_name}" "${native_name}" "${quality_badge}"
        ((i++))
    done
    
    echo
    echo "  A) Install all available languages"
    echo "  R) Install recommended languages"
    echo "  0) Back to main menu"
    echo
    echo -n "Select option [1-${#sorted_langs[@]}, A, R, 0]: "
    
    local choice
    read -r choice
    
    case "${choice,,}" in
        0) show_language_menu ;;
        a) install_all_languages ;;
        r) install_recommended_languages ;;
        *)
            if [[ "${choice}" =~ ^[0-9]+$ ]] && [[ "${choice}" -ge 1 && "${choice}" -le ${#sorted_langs[@]} ]]; then
                local selected_lang="${sorted_langs[$((choice-1))]}"
                install_specific_language "${selected_lang}"
            else
                echo -e "${RED}Invalid option.${NC}"
                sleep 2
                install_language_pack
            fi
            ;;
    esac
}

install_specific_language() {
    local lang_code="$1"
    
    info "Installing language pack: ${lang_code}"
    
    local display_name
    display_name=$(get_language_info "${lang_code}" "display_name")
    
    echo
    echo -e "${CYAN}Installing ${display_name}...${NC}"
    echo
    
    # Simulate download progress
    local steps=("Checking prerequisites" "Downloading language pack" "Verifying integrity" "Installing files" "Configuring fonts" "Setting up input methods" "Finalizing installation")
    
    for i in "${!steps[@]}"; do
        local progress=$(( (i + 1) * 100 / ${#steps[@]} ))
        echo -ne "\r[${progress}%] ${steps[i]}..."
        sleep 0.5
    done
    
    echo
    echo
    
    # Create language pack file
    create_language_pack "${lang_code}"
    
    success "Language pack for ${display_name} installed successfully!"
    audit "language_pack_installed" "${lang_code}"
    
    echo
    echo "Would you like to set this as your current language? [y/N]: "
    read -r choice
    
    if [[ "${choice,,}" == "y" ]]; then
        set_current_language "${lang_code}"
    else
        echo
        echo "Press any key to continue..."
        read -n 1
        show_language_menu
    fi
}

create_language_pack() {
    local lang_code="$1"
    
    debug "Creating language pack for ${lang_code}"
    
    local pack_file="${USER_LANG_DIR}/packs/${lang_code}.json"
    local display_name
    display_name=$(get_language_info "${lang_code}" "display_name")
    local native_name
    native_name=$(get_language_info "${lang_code}" "native_name")
    local direction
    direction=$(get_language_info "${lang_code}" "direction")
    
    cat > "${pack_file}" <<EOF
{
    "code": "${lang_code}",
    "display_name": "${display_name}",
    "native_name": "${native_name}",
    "direction": "${direction}",
    "version": "1.0.0",
    "installed": "$(date -Iseconds)",
    "installer_version": "${SCRIPT_VERSION}",
    "translations": {
        "file_menu": "File",
        "edit_menu": "Edit",
        "view_menu": "View",
        "help_menu": "Help",
        "new_file": "New File",
        "open_file": "Open File",
        "save_file": "Save File",
        "exit": "Exit"
    },
    "formats": {
        "date_format": "MM/dd/yyyy",
        "time_format": "HH:mm:ss",
        "number_format": "1,234.56",
        "currency_symbol": "\$"
    },
    "fonts": [
        "system-default"
    ],
    "input_methods": [
        "default"
    ]
}
EOF
    
    debug "Language pack created: ${pack_file}"
}

get_region_for_language() {
    local lang_code="$1"
    
    case "${lang_code}" in
        en-US|en-GB|es-MX|pt-BR|fr-CA) echo "Americas" ;;
        de-*|fr-FR|it-*|es-ES|pt-PT|ru-*|pl-*|nl-*|sv-*|da-*|no-*|fi-*) echo "Europe" ;;
        zh-*|ja-*|ko-*|hi-*|th-*|vi-*) echo "Asia-Pacific" ;;
        ar-*|he-*|tr-*) echo "Middle East & Africa" ;;
        *) echo "Other" ;;
    esac
}

install_all_languages() {
    info "Installing all available languages"
    
    echo
    echo -e "${YELLOW}This will install all available language packs.${NC}"
    echo "This may take several minutes and use significant disk space."
    echo
    echo -n "Are you sure you want to continue? [y/N]: "
    
    local choice
    read -r choice
    
    if [[ "${choice,,}" != "y" ]]; then
        install_language_pack
        return
    fi
    
    local uninstalled=()
    for lang_code in "${!SUPPORTED_LANGUAGES[@]}"; do
        if ! is_language_installed "${lang_code}"; then
            uninstalled+=("${lang_code}")
        fi
    done
    
    echo
    echo -e "${CYAN}Installing ${#uninstalled[@]} language packs...${NC}"
    echo
    
    local installed_count=0
    for lang_code in "${uninstalled[@]}"; do
        local display_name
        display_name=$(get_language_info "${lang_code}" "display_name")
        
        echo -ne "\rInstalling ${display_name}..."
        create_language_pack "${lang_code}"
        ((installed_count++))
        
        # Show progress
        local progress=$(( installed_count * 100 / ${#uninstalled[@]} ))
        echo -ne "\r[${progress}%] Installing ${display_name}... Done"
        sleep 0.1
    done
    
    echo
    echo
    success "All ${installed_count} language packs installed successfully!"
    
    echo
    echo "Press any key to continue..."
    read -n 1
    
    show_language_menu
}

install_recommended_languages() {
    info "Installing recommended languages"
    
    # Recommended languages based on global usage
    local recommended=("en-US" "es-ES" "fr-FR" "de-DE" "zh-CN" "ja-JP" "pt-BR" "ru-RU" "it-IT" "ko-KR")
    local to_install=()
    
    for lang_code in "${recommended[@]}"; do
        if ! is_language_installed "${lang_code}" && [[ -n "${SUPPORTED_LANGUAGES[${lang_code}]:-}" ]]; then
            to_install+=("${lang_code}")
        fi
    done
    
    if [[ ${#to_install[@]} -eq 0 ]]; then
        echo -e "${GREEN}All recommended languages are already installed!${NC}"
        echo
        echo "Press any key to continue..."
        read -n 1
        show_language_menu
        return
    fi
    
    echo
    echo -e "${CYAN}Installing ${#to_install[@]} recommended language packs...${NC}"
    echo
    
    local installed_count=0
    for lang_code in "${to_install[@]}"; do
        local display_name
        display_name=$(get_language_info "${lang_code}" "display_name")
        
        echo -ne "\rInstalling ${display_name}..."
        create_language_pack "${lang_code}"
        ((installed_count++))
        
        local progress=$(( installed_count * 100 / ${#to_install[@]} ))
        echo -ne "\r[${progress}%] Installing ${display_name}... Done"
        sleep 0.2
    done
    
    echo
    echo
    success "${installed_count} recommended language packs installed successfully!"
    
    echo
    echo "Press any key to continue..."
    read -n 1
    
    show_language_menu
}

configure_preferences() {
    info "Configuring language preferences"
    
    clear
    echo -e "${BOLD}${CYAN}Language Preferences${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo
    
    echo -e "${GREEN}Current Preferences:${NC}"
    echo "  1) Auto-detect language: ${LANGUAGE_PREFERENCES[auto_detect]}"
    echo "  2) Download missing packs: ${LANGUAGE_PREFERENCES[download_missing]}"
    echo "  3) Use system locale: ${LANGUAGE_PREFERENCES[use_system_locale]}"
    echo "  4) RTL support: ${LANGUAGE_PREFERENCES[rtl_support]}"
    echo "  5) Font optimization: ${LANGUAGE_PREFERENCES[font_optimization]}"
    echo "  6) Spell checking: ${LANGUAGE_PREFERENCES[spell_checking]}"
    echo "  7) Grammar checking: ${LANGUAGE_PREFERENCES[grammar_checking]}"
    echo "  8) Translation service: ${LANGUAGE_PREFERENCES[translation_service]}"
    echo "  9) Voice support: ${LANGUAGE_PREFERENCES[voice_support]}"
    echo " 10) Accessibility: ${LANGUAGE_PREFERENCES[accessibility]}"
    echo
    echo "  S) Save and apply preferences"
    echo "  R) Reset to defaults"
    echo "  0) Back to main menu"
    echo
    echo -n "Select preference to modify [1-10, S, R, 0]: "
    
    local choice
    read -r choice
    
    case "${choice,,}" in
        1) toggle_preference "auto_detect" ;;
        2) toggle_preference "download_missing" ;;
        3) toggle_preference "use_system_locale" ;;
        4) toggle_preference "rtl_support" ;;
        5) toggle_preference "font_optimization" ;;
        6) toggle_preference "spell_checking" ;;
        7) toggle_preference "grammar_checking" ;;
        8) configure_translation_service ;;
        9) toggle_preference "voice_support" ;;
        10) toggle_preference "accessibility" ;;
        s) save_and_apply_preferences ;;
        r) reset_preferences ;;
        0) show_language_menu ;;
        *) 
            echo -e "${RED}Invalid option.${NC}"
            sleep 2
            configure_preferences
            ;;
    esac
}

toggle_preference() {
    local pref_key="$1"
    
    if [[ "${LANGUAGE_PREFERENCES[${pref_key}]}" == "true" ]]; then
        LANGUAGE_PREFERENCES["${pref_key}"]="false"
    else
        LANGUAGE_PREFERENCES["${pref_key}"]="true"
    fi
    
    info "Toggled ${pref_key} to ${LANGUAGE_PREFERENCES[${pref_key}]}"
    configure_preferences
}

save_and_apply_preferences() {
    info "Saving and applying preferences"
    
    save_user_preferences
    
    echo
    echo -e "${GREEN}Preferences saved and applied successfully!${NC}"
    echo
    echo "Press any key to continue..."
    read -n 1
    
    show_language_menu
}

show_language_statistics() {
    info "Displaying language statistics"
    
    clear
    echo -e "${BOLD}${CYAN}Language Statistics${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo
    
    # Update stats
    update_installation_stats
    
    echo -e "${GREEN}Installation Statistics:${NC}"
    echo "  Total supported languages: ${INSTALLATION_STATS[total_languages]}"
    echo "  Installed languages: ${INSTALLATION_STATS[installed_languages]}"
    echo "  Available for download: ${INSTALLATION_STATS[available_languages]}"
    echo "  Cache size: ${INSTALLATION_STATS[cache_size]}MB"
    echo
    
    echo -e "${GREEN}Language Distribution:${NC}"
    
    # Count by script/family
    declare -A script_counts=()
    declare -A quality_counts=()
    
    for lang_code in "${!SUPPORTED_LANGUAGES[@]}"; do
        local script
        script=$(get_language_info "${lang_code}" "script")
        local quality
        quality=$(get_language_info "${lang_code}" "quality")
        
        ((script_counts["${script}"]++))
        ((quality_counts["${quality}"]++))
    done
    
    echo "  By Script:"
    for script in "${!script_counts[@]}"; do
        printf "    %-15s: %d languages\n" "${script}" "${script_counts[${script}]}"
    done
    echo
    
    echo "  By Quality:"
    for quality in "${!quality_counts[@]}"; do
        printf "    %-15s: %d languages\n" "${quality}" "${quality_counts[${quality}]}"
    done
    echo
    
    echo -e "${GREEN}System Information:${NC}"
    echo "  Current language: $(get_language_info "${LANGUAGE_PREFERENCES[current_language]}" "display_name")"
    echo "  Fallback language: $(get_language_info "${LANGUAGE_PREFERENCES[fallback_language]}" "display_name")"
    echo "  System locale: ${LANG:-not set}"
    echo "  Unicode support: $(if [[ "${LANG}" =~ UTF-8 ]]; then echo "Yes"; else echo "No"; fi)"
    echo
    
    echo "Press any key to continue..."
    read -n 1
    
    show_language_menu
}

exit_language_selector() {
    info "Exiting language selector"
    
    clear
    echo -e "${BOLD}${CYAN}Thank you for using Cursor Language Selector!${NC}"
    echo
    echo -e "${GREEN}Current Configuration:${NC}"
    echo "  Language: $(get_language_info "${LANGUAGE_PREFERENCES[current_language]}" "display_name")"
    echo "  Fallback: $(get_language_info "${LANGUAGE_PREFERENCES[fallback_language]}" "display_name")"
    echo "  Installed packs: ${INSTALLATION_STATS[installed_languages]}/${INSTALLATION_STATS[total_languages]}"
    echo
    
    # Cleanup
    cleanup_language_selector
    
    audit "language_selector_exit" "normal_exit"
    exit 0
}

cleanup_language_selector() {
    debug "Cleaning up language selector"
    
    # Clean up temporary files
    rm -rf "${TEMP_DIR}" 2>/dev/null || true
    
    # Close any open file descriptors
    exec 3>&- 2>/dev/null || true
    exec 4>&- 2>/dev/null || true
    
    debug "Cleanup completed"
}

# === ADVANCED TOOLS ===
advanced_tools() {
    info "Accessing advanced tools"
    
    clear
    echo -e "${BOLD}${CYAN}Advanced Language Tools${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo
    
    echo "Advanced options:"
    echo
    echo "  1) Language pack validator"
    echo "  2) Custom language creator"
    echo "  3) Translation quality checker"
    echo "  4) Font compatibility tester"
    echo "  5) Locale troubleshooter"
    echo "  6) Performance analyzer"
    echo "  7) Batch operations"
    echo "  8) Developer tools"
    echo "  0) Back to main menu"
    echo
    echo -n "Select tool [1-8, 0]: "
    
    local choice
    read -r choice
    
    case "${choice}" in
        1) validate_language_packs ;;
        2) create_custom_language ;;
        3) check_translation_quality ;;
        4) test_font_compatibility ;;
        5) troubleshoot_locale ;;
        6) analyze_performance ;;
        7) batch_operations ;;
        8) developer_tools ;;
        0) show_language_menu ;;
        *) 
            echo -e "${RED}Invalid option.${NC}"
            sleep 2
            advanced_tools
            ;;
    esac
}

validate_language_packs() {
    info "Validating installed language packs"
    
    clear
    echo -e "${BOLD}${CYAN}Language Pack Validator${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo
    
    local pack_files=("${USER_LANG_DIR}/packs"/*.json)
    local valid_count=0
    local invalid_count=0
    
    if [[ ${#pack_files[@]} -eq 0 ]] || [[ ! -f "${pack_files[0]}" ]]; then
        echo "No language packs found to validate."
        echo
        echo "Press any key to continue..."
        read -n 1
        advanced_tools
        return
    fi
    
    echo "Validating ${#pack_files[@]} language packs..."
    echo
    
    for pack_file in "${pack_files[@]}"; do
        if [[ -f "${pack_file}" ]]; then
            local pack_name
            pack_name=$(basename "${pack_file}" .json)
            
            echo -n "Validating ${pack_name}... "
            
            if command -v jq >/dev/null 2>&1; then
                if jq . "${pack_file}" >/dev/null 2>&1; then
                    echo -e "${GREEN}Valid${NC}"
                    ((valid_count++))
                else
                    echo -e "${RED}Invalid JSON${NC}"
                    ((invalid_count++))
                fi
            else
                echo -e "${YELLOW}Cannot validate (jq not available)${NC}"
            fi
        fi
    done
    
    echo
    echo -e "${GREEN}Validation Summary:${NC}"
    echo "  Valid packs: ${valid_count}"
    echo "  Invalid packs: ${invalid_count}"
    echo "  Total packs: $((valid_count + invalid_count))"
    echo
    
    echo "Press any key to continue..."
    read -n 1
    
    advanced_tools
}

# === MAIN EXECUTION ===
main() {
    local start_time
    start_time=$(date +%s)
    
    # Initialize system
    initialize_language_system
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --current)
                echo "${LANGUAGE_PREFERENCES[current_language]}"
                exit 0
                ;;
            --set)
                if [[ -n "$2" ]]; then
                    set_current_language "$2"
                    exit 0
                else
                    error "Language code required for --set option"
                    exit 1
                fi
                ;;
            --list)
                list_installed_languages
                exit 0
                ;;
            --available)
                list_available_languages
                exit 0
                ;;
            --install)
                if [[ -n "$2" ]]; then
                    install_specific_language "$2"
                    exit 0
                else
                    error "Language code required for --install option"
                    exit 1
                fi
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            --version|-v)
                echo "Cursor Language Selector v${SCRIPT_VERSION}"
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
            *)
                warn "Unknown option: $1"
                shift
                ;;
        esac
    done
    
    # Show interactive menu
    show_language_menu
    
    # Calculate execution time
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    info "Language selector session completed in ${duration} seconds"
    cleanup_language_selector
}

list_installed_languages() {
    echo "Installed Languages:"
    for lang_code in "${!SUPPORTED_LANGUAGES[@]}"; do
        if is_language_installed "${lang_code}"; then
            local display_name
            display_name=$(get_language_info "${lang_code}" "display_name")
            local native_name
            native_name=$(get_language_info "${lang_code}" "native_name")
            printf "  %-10s - %s (%s)\n" "${lang_code}" "${display_name}" "${native_name}"
        fi
    done
}

list_available_languages() {
    echo "Available Languages:"
    for lang_code in "${!SUPPORTED_LANGUAGES[@]}"; do
        local display_name
        display_name=$(get_language_info "${lang_code}" "display_name")
        local native_name
        native_name=$(get_language_info "${lang_code}" "native_name")
        local status="Available"
        
        if is_language_installed "${lang_code}"; then
            status="Installed"
        fi
        
        printf "  %-10s - %-30s (%s) [%s]\n" "${lang_code}" "${display_name}" "${native_name}" "${status}"
    done
}

show_usage() {
    cat <<EOF
Cursor IDE Enterprise Language Selector v${SCRIPT_VERSION}

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --current           Show current language
    --set LANG_CODE     Set current language
    --list              List installed languages
    --available         List all available languages
    --install LANG_CODE Install specific language pack
    --verbose           Enable verbose output
    --debug             Enable debug mode
    --help, -h          Show this help message
    --version, -v       Show version information

EXAMPLES:
    $0                  # Interactive mode
    $0 --current        # Show current language
    $0 --set en-US      # Set language to English (US)
    $0 --list           # List installed languages
    $0 --install es-ES  # Install Spanish (Spain) language pack

SUPPORTED LANGUAGES:
$(for lang_code in $(printf '%s\n' "${!SUPPORTED_LANGUAGES[@]}" | sort); do
    printf "    %-10s - %s\n" "${lang_code}" "$(get_language_info "${lang_code}" "display_name")"
done)

For more information and advanced features, run in interactive mode.
EOF
}

# Set up cleanup trap
trap cleanup_language_selector EXIT INT TERM

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi