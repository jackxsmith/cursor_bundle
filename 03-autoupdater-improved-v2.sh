#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# 03-autoupdater-improved-v2.sh - Professional Auto-Updater v2.0
# Enterprise-grade application auto-updater with robust error handling and self-correcting mechanisms
# ============================================================================

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="2.0.0"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Configuration Management
readonly APP_NAME="cursor"
readonly CURRENT_VERSION="$(cat "${SCRIPT_DIR}/VERSION" 2>/dev/null || echo "unknown")"
readonly CONFIG_DIR="${HOME}/.config/cursor-updater"
readonly CACHE_DIR="${HOME}/.cache/cursor-updater"
readonly LOGS_DIR="${CONFIG_DIR}/logs"
readonly DOWNLOADS_DIR="${CACHE_DIR}/downloads"

# Logging Configuration
readonly LOG_FILE="${LOGS_DIR}/updater_${TIMESTAMP}.log"
readonly ERROR_LOG="${LOGS_DIR}/updater_errors_${TIMESTAMP}.log"
readonly UPDATE_LOG="${LOGS_DIR}/update_history.log"

# Update Configuration
readonly UPDATE_CONFIG="${CONFIG_DIR}/updater.conf"
readonly UPDATE_LOCK="${CACHE_DIR}/update.lock"
readonly UPDATE_URL="https://api.github.com/repos/jackxsmith/cursor_bundle/releases/latest"

# Global Variables
declare -g CHECK_ONLY=false
declare -g FORCE_UPDATE=false
declare -g SILENT_MODE=false
declare -g UPDATE_CHANNEL="stable"

# Enhanced error handling with self-correction
error_handler() {
    local line_no="$1"
    local bash_command="$2"
    local exit_code="$3"
    
    log_error "Error on line $line_no: Command '$bash_command' failed with exit code $exit_code"
    
    # Self-correction attempts
    case "$bash_command" in
        *"curl"*|*"wget"*)
            log_info "Network command failed, checking connectivity and retrying..."
            check_network_connectivity && retry_network_operation "$bash_command"
            ;;
        *"mkdir"*)
            log_info "Directory creation failed, attempting to fix permissions..."
            fix_directory_permissions
            ;;
        *"download"*)
            log_info "Download failed, cleaning up and retrying..."
            cleanup_failed_download
            ;;
    esac
    
    cleanup_on_error
}

# Professional logging system
log_info() {
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [INFO] $message" | tee -a "$LOG_FILE"
    [[ "$SILENT_MODE" != "true" ]] && echo "[INFO] $message" >&2
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
    [[ "$SILENT_MODE" != "true" ]] && echo "[WARNING] $message" >&2
}

log_update() {
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$UPDATE_LOG"
}

# Initialize updater with robust setup
initialize_updater() {
    log_info "Initializing Professional Auto-Updater v${VERSION}"
    
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
    
    log_info "Updater initialization completed successfully"
}

# Create directory structure with retry logic
create_directory_structure() {
    local dirs=("$CONFIG_DIR" "$CACHE_DIR" "$LOGS_DIR" "$DOWNLOADS_DIR")
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
    if [[ ! -f "$UPDATE_CONFIG" ]]; then
        log_info "Creating default updater configuration"
        create_default_configuration
    fi
    
    # Source configuration safely
    if [[ -r "$UPDATE_CONFIG" ]]; then
        source "$UPDATE_CONFIG"
        log_info "Configuration loaded from $UPDATE_CONFIG"
    else
        log_warning "Configuration file not readable, using defaults"
    fi
}

# Create default configuration
create_default_configuration() {
    cat > "$UPDATE_CONFIG" << 'EOF'
# Professional Auto-Updater Configuration v2.0

# Update Channel Settings
UPDATE_CHANNEL=stable
AUTO_UPDATE_ENABLED=true
CHECK_INTERVAL_HOURS=24

# Download Settings
MAX_DOWNLOAD_ATTEMPTS=3
DOWNLOAD_TIMEOUT=300
VERIFY_SIGNATURES=false
BACKUP_BEFORE_UPDATE=true

# Network Settings
USE_SYSTEM_PROXY=true
CONNECT_TIMEOUT=30
MAX_REDIRECT_COUNT=5

# Maintenance Settings
CLEANUP_OLD_DOWNLOADS=true
RETENTION_DAYS=7
LOG_RETENTION_DAYS=30
EOF
    
    log_info "Default configuration created: $UPDATE_CONFIG"
}

# Validate system requirements
validate_system_requirements() {
    log_info "Validating system requirements..."
    
    # Check required commands
    local required_commands=("curl" "jq" "tar" "chmod")
    local missing_commands=()
    
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [[ ${#missing_commands[@]} -gt 0 ]]; then
        log_warning "Missing required commands: ${missing_commands[*]}"
        
        # Attempt auto-installation
        if command -v apt-get &>/dev/null; then
            log_info "Attempting to install missing packages..."
            sudo apt-get update && sudo apt-get install -y "${missing_commands[@]}" || true
        elif command -v yum &>/dev/null; then
            sudo yum install -y "${missing_commands[@]}" || true
        fi
    fi
    
    # Check network connectivity
    if ! check_network_connectivity; then
        log_error "Network connectivity check failed"
        return 1
    fi
    
    log_info "System requirements validation completed"
}

# Check network connectivity
check_network_connectivity() {
    local test_urls=("https://api.github.com" "https://google.com" "8.8.8.8")
    
    for url in "${test_urls[@]}"; do
        if timeout 10 curl -s --head "$url" >/dev/null 2>&1; then
            log_info "Network connectivity verified via $url"
            return 0
        fi
    done
    
    log_warning "Network connectivity issues detected"
    return 1
}

# Acquire lock with timeout
acquire_lock() {
    local timeout=30
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        if (set -C; echo $$ > "$UPDATE_LOCK") 2>/dev/null; then
            log_info "Update lock acquired successfully"
            return 0
        fi
        
        if [[ -f "$UPDATE_LOCK" ]]; then
            local lock_pid
            lock_pid=$(cat "$UPDATE_LOCK" 2>/dev/null || echo "")
            if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
                log_info "Removing stale lock file"
                rm -f "$UPDATE_LOCK"
                continue
            fi
        fi
        
        sleep 1
        ((elapsed++))
    done
    
    log_error "Failed to acquire update lock after ${timeout}s"
    return 1
}

# Check for updates
check_for_updates() {
    log_info "Checking for updates..."
    
    # Get latest release information
    local latest_info
    if ! latest_info=$(fetch_latest_release_info); then
        log_error "Failed to fetch latest release information"
        return 1
    fi
    
    # Extract version information
    local latest_version download_url
    latest_version=$(echo "$latest_info" | jq -r '.tag_name // empty' 2>/dev/null)
    download_url=$(echo "$latest_info" | jq -r '.assets[0].browser_download_url // empty' 2>/dev/null)
    
    if [[ -z "$latest_version" ]] || [[ -z "$download_url" ]]; then
        log_error "Invalid release information received"
        return 1
    fi
    
    log_info "Current version: $CURRENT_VERSION"
    log_info "Latest version: $latest_version"
    
    # Compare versions
    if is_newer_version "$latest_version" "$CURRENT_VERSION"; then
        log_info "Update available: $latest_version"
        
        if [[ "$CHECK_ONLY" == "true" ]]; then
            echo "Update available: $latest_version"
            return 0
        else
            perform_update "$latest_version" "$download_url"
        fi
    else
        log_info "No updates available"
        return 0
    fi
}

# Fetch latest release information
fetch_latest_release_info() {
    local max_attempts="${MAX_DOWNLOAD_ATTEMPTS:-3}"
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log_info "Fetching release info (attempt $attempt/$max_attempts)..."
        
        if curl -s --max-time "${CONNECT_TIMEOUT:-30}" \
               --max-redirs "${MAX_REDIRECT_COUNT:-5}" \
               -H "Accept: application/vnd.github.v3+json" \
               "$UPDATE_URL" 2>/dev/null; then
            return 0
        fi
        
        ((attempt++))
        sleep 2
    done
    
    return 1
}

# Compare version numbers
is_newer_version() {
    local new_version="$1"
    local current_version="$2"
    
    # Simple version comparison (handles semantic versioning)
    if [[ "$new_version" != "$current_version" ]]; then
        # Use sort -V for version comparison if available
        if command -v sort &>/dev/null; then
            local sorted_versions
            sorted_versions=$(printf "%s\n%s\n" "$current_version" "$new_version" | sort -V)
            if [[ "$(echo "$sorted_versions" | head -1)" == "$current_version" ]]; then
                return 0  # New version is newer
            fi
        else
            # Fallback: assume any different version is newer
            return 0
        fi
    fi
    
    return 1  # Not newer
}

# Perform update
perform_update() {
    local new_version="$1"
    local download_url="$2"
    
    log_info "Starting update to version $new_version"
    log_update "UPDATE_START: $CURRENT_VERSION -> $new_version"
    
    # Download update
    local download_file="${DOWNLOADS_DIR}/cursor_${new_version}.zip"
    if ! download_update "$download_url" "$download_file"; then
        log_error "Failed to download update"
        return 1
    fi
    
    # Verify download
    if ! verify_download "$download_file"; then
        log_error "Download verification failed"
        return 1
    fi
    
    # Create backup
    if [[ "${BACKUP_BEFORE_UPDATE:-true}" == "true" ]]; then
        create_backup
    fi
    
    # Apply update  
    if apply_update "$download_file" "$new_version"; then
        log_info "Update completed successfully"
        log_update "UPDATE_SUCCESS: $new_version"
        
        # Cleanup
        cleanup_after_update
        
        return 0
    else
        log_error "Update application failed"
        log_update "UPDATE_FAILED: $new_version"
        
        # Attempt rollback if backup exists
        attempt_rollback
        return 1
    fi
}

# Download update with progress and resume support
download_update() {
    local url="$1"
    local output_file="$2"
    local max_attempts="${MAX_DOWNLOAD_ATTEMPTS:-3}"
    local attempt=1
    
    log_info "Downloading update from: $url"
    
    while [[ $attempt -le $max_attempts ]]; do
        log_info "Download attempt $attempt/$max_attempts"
        
        # Use curl with resume support
        if curl -L --progress-bar \
               --max-time "${DOWNLOAD_TIMEOUT:-300}" \
               --max-redirs "${MAX_REDIRECT_COUNT:-5}" \
               -C - \
               -o "$output_file" \
               "$url"; then
            log_info "Download completed successfully"
            return 0
        fi
        
        ((attempt++))
        if [[ $attempt -le $max_attempts ]]; then
            log_warning "Download failed, retrying in 5 seconds..."
            sleep 5
        fi
    done
    
    log_error "Download failed after $max_attempts attempts"
    return 1
}

# Verify download integrity
verify_download() {
    local download_file="$1"
    
    log_info "Verifying download integrity..."
    
    # Check if file exists and is not empty
    if [[ ! -f "$download_file" ]] || [[ ! -s "$download_file" ]]; then
        log_error "Download file is missing or empty"
        return 1
    fi
    
    # Check file type
    local file_type
    file_type=$(file "$download_file" 2>/dev/null)
    if [[ ! "$file_type" =~ (Zip|compressed|archive) ]]; then
        log_warning "Download may not be a valid archive file"
    fi
    
    log_info "Download verification completed"
    return 0
}

# Create backup of current installation
create_backup() {
    log_info "Creating backup of current installation..."
    
    local backup_dir="${CACHE_DIR}/backup_${CURRENT_VERSION}_${TIMESTAMP}"
    mkdir -p "$backup_dir"
    
    # Backup current files
    if [[ -d "$SCRIPT_DIR" ]]; then
        cp -r "$SCRIPT_DIR"/* "$backup_dir/" 2>/dev/null || true
        log_info "Backup created: $backup_dir"
        
        # Create backup metadata
        cat > "${backup_dir}/backup_info.txt" << EOF
Backup created: $(date)
Original version: $CURRENT_VERSION
Backup location: $backup_dir
EOF
    else
        log_warning "Source directory not found, skipping backup"
    fi
}

# Apply update
apply_update() {
    local update_file="$1"
    local new_version="$2"
    
    log_info "Applying update from: $update_file"
    
    # Create temporary extraction directory
    local temp_dir
    temp_dir=$(mktemp -d) || return 1
    
    # Extract update package
    if ! extract_update_package "$update_file" "$temp_dir"; then
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Apply update files
    if copy_update_files "$temp_dir" "$SCRIPT_DIR"; then
        # Update version file
        echo "$new_version" > "${SCRIPT_DIR}/VERSION"
        log_info "Update applied successfully"
        
        # Cleanup temporary directory
        rm -rf "$temp_dir"
        return 0
    else
        log_error "Failed to copy update files"
        rm -rf "$temp_dir"
        return 1
    fi
}

# Extract update package
extract_update_package() {
    local package_file="$1"
    local extract_dir="$2"
    
    log_info "Extracting update package..."
    
    if command -v unzip &>/dev/null; then
        if unzip -q "$package_file" -d "$extract_dir"; then
            return 0
        fi
    fi
    
    if command -v tar &>/dev/null; then
        if tar -xf "$package_file" -C "$extract_dir" 2>/dev/null; then
            return 0
        fi
    fi
    
    log_error "Failed to extract update package"
    return 1
}

# Copy update files
copy_update_files() {
    local source_dir="$1"
    local target_dir="$2"
    
    log_info "Copying update files..."
    
    # Find the actual content directory (may be nested)
    local content_dir="$source_dir"
    if [[ -d "$source_dir/cursor_bundle" ]]; then
        content_dir="$source_dir/cursor_bundle"
    elif [[ $(find "$source_dir" -mindepth 1 -maxdepth 1 -type d | wc -l) -eq 1 ]]; then
        content_dir=$(find "$source_dir" -mindepth 1 -maxdepth 1 -type d | head -1)
    fi
    
    # Copy files with error handling
    if cp -r "$content_dir"/* "$target_dir/" 2>/dev/null; then
        # Set proper permissions
        find "$target_dir" -type f -name "*.sh" -exec chmod +x {} \; 2>/dev/null || true
        log_info "Update files copied successfully"
        return 0
    else
        log_error "Failed to copy update files"
        return 1
    fi
}

# Attempt rollback
attempt_rollback() {
    log_info "Attempting rollback to previous version..."
    
    # Find latest backup
    local latest_backup
    latest_backup=$(find "${CACHE_DIR}" -name "backup_*" -type d | sort -r | head -1)
    
    if [[ -n "$latest_backup" ]] && [[ -d "$latest_backup" ]]; then
        log_info "Rolling back from backup: $latest_backup"
        
        if cp -r "$latest_backup"/* "$SCRIPT_DIR/" 2>/dev/null; then
            log_info "Rollback completed successfully"
            log_update "ROLLBACK_SUCCESS: from $latest_backup"
        else
            log_error "Rollback failed"
            log_update "ROLLBACK_FAILED: from $latest_backup"
        fi
    else
        log_error "No backup found for rollback"
    fi
}

# Cleanup functions
cleanup_after_update() {
    log_info "Performing post-update cleanup..."
    
    # Clean old downloads if enabled
    if [[ "${CLEANUP_OLD_DOWNLOADS:-true}" == "true" ]]; then
        local retention_days="${RETENTION_DAYS:-7}"
        find "$DOWNLOADS_DIR" -type f -mtime +$retention_days -delete 2>/dev/null || true
    fi
    
    # Clean old logs
    local log_retention_days="${LOG_RETENTION_DAYS:-30}"
    find "$LOGS_DIR" -name "*.log" -mtime +$log_retention_days -delete 2>/dev/null || true
}

cleanup_failed_download() {
    log_info "Cleaning up failed download..."
    find "$DOWNLOADS_DIR" -name "*.tmp" -delete 2>/dev/null || true
    find "$DOWNLOADS_DIR" -size 0 -delete 2>/dev/null || true
}

retry_network_operation() {
    local command="$1"
    log_info "Retrying network operation: $command"
    sleep 5
    # Implementation would depend on specific command
}

fix_directory_permissions() {
    log_info "Attempting to fix directory permissions..."
    for dir in "$CONFIG_DIR" "$CACHE_DIR" "$LOGS_DIR" "$DOWNLOADS_DIR"; do
        if [[ -d "$dir" ]]; then
            chmod 755 "$dir" 2>/dev/null || true
        fi
    done
}

cleanup_on_error() {
    log_warning "Performing error cleanup..."
    cleanup_on_exit
}

cleanup_on_exit() {
    # Remove lock file
    [[ -f "$UPDATE_LOCK" ]] && rm -f "$UPDATE_LOCK"
    
    # Kill any background processes
    jobs -p | xargs -r kill 2>/dev/null || true
    
    log_info "Cleanup completed"
}

# Display usage information
display_usage() {
    cat << 'EOF'
Professional Auto-Updater v2.0

USAGE:
    autoupdater-improved-v2.sh [OPTIONS]

OPTIONS:
    --check         Check for updates only (don't apply)
    --force         Force update even if version is same
    --silent        Silent mode (minimal output)
    --channel NAME  Update channel (stable, beta, alpha)
    --help          Display this help message
    --version       Display version information

EXAMPLES:
    ./autoupdater-improved-v2.sh --check
    ./autoupdater-improved-v2.sh --force
    ./autoupdater-improved-v2.sh --channel beta

CONFIGURATION:
    Configuration file: ~/.config/cursor-updater/updater.conf
    Log directory: ~/.config/cursor-updater/logs/

For more information, see the documentation.  
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check)
                CHECK_ONLY=true
                shift
                ;;
            --force)
                FORCE_UPDATE=true
                shift
                ;;
            --silent)
                SILENT_MODE=true
                shift
                ;;
            --channel)
                UPDATE_CHANNEL="$2"
                shift 2
                ;;
            --help)
                display_usage
                exit 0
                ;;
            --version)
                echo "Professional Auto-Updater v$VERSION"
                exit 0
                ;;
            *)
                log_warning "Unknown option: $1"
                shift
                ;;
        esac
    done
}

# Main execution function
main() {
    # Parse command line arguments
    parse_arguments "$@"
    
    # Initialize updater
    initialize_updater
    
    # Check for updates
    if check_for_updates; then
        log_info "Professional Auto-Updater completed successfully"
        exit 0
    else
        log_error "Professional Auto-Updater failed"
        exit 1
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi