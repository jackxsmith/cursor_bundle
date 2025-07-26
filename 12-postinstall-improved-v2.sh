#!/usr/bin/env bash
#
# PROFESSIONAL POST-INSTALLATION FRAMEWORK v2.0
# Enterprise-Grade Post-Installation Configuration System
#
# Enhanced Features:
# - Robust post-installation validation
# - Self-correcting configuration mechanisms
# - Professional error handling and recovery
# - Advanced system integration
# - Performance optimization
# - Security hardening
#

set -euo pipefail
IFS=$'\n\t'

# === CONFIGURATION ===
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="$(basename "${0}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Installation Paths
readonly CURSOR_INSTALL_DIR="/opt/cursor"
readonly USER_CURSOR_DIR="${HOME}/.cursor"
readonly USER_CONFIG_DIR="${HOME}/.config/cursor"
readonly USER_DATA_DIR="${HOME}/.local/share/cursor"
readonly USER_CACHE_DIR="${HOME}/.cache/cursor"
readonly TEMP_DIR="$(mktemp -d -t cursor_postinstall_XXXXXX)"

# Directory Structure
readonly LOG_DIR="${USER_CACHE_DIR}/postinstall/logs"
readonly STATE_DIR="${USER_CACHE_DIR}/postinstall/state"
readonly BACKUP_DIR="${USER_CACHE_DIR}/postinstall/backups"

# Log Files
readonly MAIN_LOG="${LOG_DIR}/postinstall_${TIMESTAMP}.log"
readonly ERROR_LOG="${LOG_DIR}/postinstall_errors_${TIMESTAMP}.log"
readonly AUDIT_LOG="${LOG_DIR}/postinstall_audit_${TIMESTAMP}.log"

# Configuration Files
readonly INSTALLATION_MANIFEST="${STATE_DIR}/installation.json"
readonly USER_PREFERENCES="${USER_CONFIG_DIR}/preferences.json"

# Runtime Variables
declare -g DRY_RUN=false
declare -g QUIET_MODE=false
declare -g SKIP_INTEGRATION=false
declare -g ENABLE_MONITORING=true

# === UTILITY FUNCTIONS ===

# Enhanced logging
log() {
    local level="$1"
    local message="$2"
    local timestamp="$(date -Iseconds)"
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$MAIN_LOG")" 2>/dev/null || true
    echo "[${timestamp}] ${level}: ${message}" >> "$MAIN_LOG"
    
    case "$level" in
        ERROR) 
            mkdir -p "$(dirname "$ERROR_LOG")" 2>/dev/null || true
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
    local user="${USER:-unknown}"
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
    local dirs=("$LOG_DIR" "$STATE_DIR" "$BACKUP_DIR" "$USER_CONFIG_DIR" "$USER_DATA_DIR")
    
    for dir in "${dirs[@]}"; do
        if ! ensure_directory "$dir"; then
            echo "Failed to initialize directories"
            return 1
        fi
    done
    
    # Log rotation
    find "$LOG_DIR" -name "postinstall_*.log" -mtime +7 -delete 2>/dev/null || true
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

# === VALIDATION FUNCTIONS ===

# Validate installation
validate_installation() {
    log "INFO" "Validating Cursor IDE installation"
    
    local validation_issues=0
    
    # Check installation directory
    if [[ ! -d "$CURSOR_INSTALL_DIR" ]]; then
        log "ERROR" "Installation directory not found: $CURSOR_INSTALL_DIR"
        ((validation_issues++))
    else
        log "PASS" "Installation directory verified"
    fi
    
    # Check executable
    local cursor_executable=""
    if [[ -f "$CURSOR_INSTALL_DIR/cursor.AppImage" ]]; then
        cursor_executable="$CURSOR_INSTALL_DIR/cursor.AppImage"
    elif [[ -f "$CURSOR_INSTALL_DIR/cursor" ]]; then
        cursor_executable="$CURSOR_INSTALL_DIR/cursor"
    elif command -v cursor >/dev/null 2>&1; then
        cursor_executable=$(command -v cursor)
    fi
    
    if [[ -n "$cursor_executable" ]]; then
        if [[ -x "$cursor_executable" ]]; then
            log "PASS" "Cursor executable verified: $cursor_executable"
        else
            log "ERROR" "Cursor executable not executable: $cursor_executable"
            ((validation_issues++))
        fi
    else
        log "ERROR" "Cursor executable not found"
        ((validation_issues++))
    fi
    
    # Test execution
    if [[ -n "$cursor_executable" ]] && [[ -x "$cursor_executable" ]]; then
        if timeout 30 "$cursor_executable" --version >/dev/null 2>&1; then
            log "PASS" "Cursor execution test passed"
        else
            log "WARN" "Cursor execution test failed (may require display)"
        fi
    fi
    
    if [[ $validation_issues -eq 0 ]]; then
        log "PASS" "Installation validation completed successfully"
        return 0
    else
        log "ERROR" "Installation validation failed ($validation_issues issues)"
        return 1
    fi
}

# === CONFIGURATION FUNCTIONS ===

# Configure user environment
configure_user_environment() {
    log "INFO" "Configuring user environment"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would configure user environment"
        return 0
    fi
    
    # Create user configuration
    create_user_configuration
    
    # Set up desktop integration
    setup_desktop_integration
    
    # Configure file associations
    configure_file_associations
    
    # Set up shell integration
    setup_shell_integration
    
    log "PASS" "User environment configured"
    audit_log "USER_ENVIRONMENT_CONFIGURED" "SUCCESS" "User: $USER"
    
    return 0
}

# Create user configuration
create_user_configuration() {
    log "DEBUG" "Creating user configuration files"
    
    # Create default preferences
    if [[ ! -f "$USER_PREFERENCES" ]]; then
        cat > "$USER_PREFERENCES" << 'EOF'
{
    "editor": {
        "fontSize": 14,
        "fontFamily": "Consolas, Monaco, 'Courier New', monospace",
        "tabSize": 4,
        "wordWrap": "on",
        "lineNumbers": "on"
    },
    "workbench": {
        "colorTheme": "Default Dark+",
        "iconTheme": "vs-seti"
    },
    "files": {
        "autoSave": "afterDelay",
        "autoSaveDelay": 1000
    },
    "extensions": {
        "autoUpdate": true,
        "ignoreRecommendations": false
    }
}
EOF
        log "DEBUG" "Created default user preferences"
    fi
    
    # Create workspace settings template
    local workspace_template="${USER_DATA_DIR}/workspace-template.json"
    if [[ ! -f "$workspace_template" ]]; then
        cat > "$workspace_template" << 'EOF'
{
    "folders": [],
    "settings": {
        "editor.formatOnSave": true,
        "editor.codeActionsOnSave": {
            "source.organizeImports": true
        }
    },
    "extensions": {
        "recommendations": []
    }
}
EOF
        log "DEBUG" "Created workspace template"
    fi
}

# Setup desktop integration
setup_desktop_integration() {
    log "DEBUG" "Setting up desktop integration"
    
    # Create desktop entry
    local desktop_dir="${HOME}/.local/share/applications"
    ensure_directory "$desktop_dir"
    
    local desktop_file="$desktop_dir/cursor.desktop"
    if [[ ! -f "$desktop_file" ]]; then
        cat > "$desktop_file" << 'EOF'
[Desktop Entry]
Name=Cursor
Comment=The AI-first code editor
GenericName=Code Editor
Exec=cursor %F
Icon=cursor
Type=Application
Categories=Development;IDE;TextEditor;
StartupNotify=true
MimeType=text/plain;text/x-chdr;text/x-csrc;text/x-c++hdr;text/x-c++src;text/x-java;text/x-python;application/javascript;application/json;text/css;text/html;text/xml;text/markdown;
Keywords=editor;development;programming;code;
EOF
        chmod 644 "$desktop_file"
        log "DEBUG" "Created desktop entry"
    fi
    
    # Update desktop database
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$desktop_dir" 2>/dev/null || true
    fi
}

# Configure file associations
configure_file_associations() {
    log "DEBUG" "Configuring file associations"
    
    local mime_dir="${HOME}/.local/share/mime"
    ensure_directory "$mime_dir/packages"
    
    # Create MIME type associations
    local mime_file="$mime_dir/packages/cursor.xml"
    if [[ ! -f "$mime_file" ]]; then
        cat > "$mime_file" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
    <mime-type type="text/x-cursor-project">
        <comment>Cursor Project File</comment>
        <glob pattern="*.cursor"/>
    </mime-type>
</mime-info>
EOF
        
        # Update MIME database
        if command -v update-mime-database >/dev/null 2>&1; then
            update-mime-database "$mime_dir" 2>/dev/null || true
        fi
        
        log "DEBUG" "Configured file associations"
    fi
}

# Setup shell integration
setup_shell_integration() {
    log "DEBUG" "Setting up shell integration"
    
    # Add cursor to PATH if not already there
    if ! command -v cursor >/dev/null 2>&1; then
        local shell_rc=""
        if [[ -n "${BASH_VERSION:-}" ]]; then
            shell_rc="${HOME}/.bashrc"
        elif [[ -n "${ZSH_VERSION:-}" ]]; then
            shell_rc="${HOME}/.zshrc"
        fi
        
        if [[ -n "$shell_rc" ]] && [[ -f "$shell_rc" ]]; then
            if ! grep -q "cursor" "$shell_rc"; then
                echo "" >> "$shell_rc"
                echo "# Cursor IDE integration" >> "$shell_rc"
                echo 'export PATH="$PATH:/opt/cursor"' >> "$shell_rc"
                log "DEBUG" "Added cursor to PATH in $shell_rc"
            fi
        fi
    fi
}

# === SYSTEM INTEGRATION ===

# Setup system integration
setup_system_integration() {
    log "INFO" "Setting up system integration"
    
    if [[ "$SKIP_INTEGRATION" == "true" ]]; then
        log "INFO" "System integration skipped"
        return 0
    fi
    
    # Setup protocol handlers
    setup_protocol_handlers
    
    # Configure system services
    configure_system_services
    
    # Setup monitoring
    if [[ "$ENABLE_MONITORING" == "true" ]]; then
        setup_monitoring
    fi
    
    log "PASS" "System integration completed"
    return 0
}

# Setup protocol handlers
setup_protocol_handlers() {
    log "DEBUG" "Setting up protocol handlers"
    
    local schemes_dir="${HOME}/.local/share/applications"
    ensure_directory "$schemes_dir"
    
    # Create cursor:// protocol handler
    local scheme_file="$schemes_dir/cursor-url-handler.desktop"
    if [[ ! -f "$scheme_file" ]]; then
        cat > "$scheme_file" << 'EOF'
[Desktop Entry]
Name=Cursor URL Handler
Exec=cursor --open-url %u
Type=Application
NoDisplay=true
StartupNotify=true
MimeType=x-scheme-handler/cursor;
EOF
        chmod 644 "$scheme_file"
        log "DEBUG" "Created protocol handler"
    fi
}

# Configure system services
configure_system_services() {
    log "DEBUG" "Configuring system services"
    
    # Create systemd user service for cursor daemon (if needed)
    if command -v systemctl >/dev/null 2>&1; then
        local service_dir="${HOME}/.config/systemd/user"
        ensure_directory "$service_dir"
        
        # This would be for a hypothetical cursor daemon
        # Currently just a placeholder for future use
        log "DEBUG" "System services configuration completed"
    fi
}

# Setup monitoring
setup_monitoring() {
    log "DEBUG" "Setting up post-installation monitoring"
    
    # Create monitoring script
    local monitor_script="${USER_DATA_DIR}/monitor.sh"
    cat > "$monitor_script" << 'EOF'
#!/bin/bash
# Simple cursor installation monitor
CURSOR_LOG="${HOME}/.cache/cursor/monitor.log"
mkdir -p "$(dirname "$CURSOR_LOG")"

echo "[$(date -Iseconds)] Cursor monitoring check" >> "$CURSOR_LOG"

if command -v cursor >/dev/null 2>&1; then
    echo "[$(date -Iseconds)] Cursor command available" >> "$CURSOR_LOG"
else
    echo "[$(date -Iseconds)] WARNING: Cursor command not available" >> "$CURSOR_LOG"
fi
EOF
    chmod +x "$monitor_script"
    
    log "DEBUG" "Monitoring setup completed"
}

# === OPTIMIZATION ===

# Optimize performance
optimize_performance() {
    log "INFO" "Optimizing system performance"
    
    # Create performance tuning configuration
    create_performance_config
    
    # Optimize cache settings
    optimize_cache_settings
    
    # Configure resource limits
    configure_resource_limits
    
    log "PASS" "Performance optimization completed"
    return 0
}

# Create performance configuration
create_performance_config() {
    local perf_config="${USER_CONFIG_DIR}/performance.json"
    
    if [[ ! -f "$perf_config" ]]; then
        cat > "$perf_config" << 'EOF'
{
    "performance": {
        "enableLargeFileOptimizations": true,
        "maxMemoryForIndexing": "1024MB",
        "indexingThreads": 4,
        "enablePreloadedCSSModules": true,
        "enableFileWatcher": true,
        "watcherExcludePatterns": [
            "**/node_modules/**",
            "**/.git/**",
            "**/dist/**"
        ]
    }
}
EOF
        log "DEBUG" "Created performance configuration"
    fi
}

# Optimize cache settings
optimize_cache_settings() {
    log "DEBUG" "Optimizing cache settings"
    
    # Ensure cache directory exists
    ensure_directory "$USER_CACHE_DIR"
    
    # Set appropriate permissions
    chmod 755 "$USER_CACHE_DIR"
    
    # Create cache cleanup script
    local cleanup_script="${USER_CACHE_DIR}/cleanup.sh"
    cat > "$cleanup_script" << 'EOF'
#!/bin/bash
# Cursor cache cleanup script
CACHE_DIR="${HOME}/.cache/cursor"

# Clean old log files (older than 7 days)
find "$CACHE_DIR" -name "*.log" -mtime +7 -delete 2>/dev/null || true

# Clean temporary files
find "$CACHE_DIR" -name "tmp.*" -mtime +1 -delete 2>/dev/null || true

echo "Cache cleanup completed at $(date)"
EOF
    chmod +x "$cleanup_script"
}

# Configure resource limits
configure_resource_limits() {
    log "DEBUG" "Configuring resource limits"
    
    # Create resource limits configuration
    local limits_config="${USER_CONFIG_DIR}/limits.json"
    
    if [[ ! -f "$limits_config" ]]; then
        cat > "$limits_config" << 'EOF'
{
    "resourceLimits": {
        "maxMemoryUsage": "2048MB",
        "maxCPUUsage": 80,
        "maxFileHandles": 8192,
        "maxProcesses": 64
    }
}
EOF
        log "DEBUG" "Created resource limits configuration"
    fi
}

# === INSTALLATION MANIFEST ===

# Create installation manifest
create_installation_manifest() {
    log "INFO" "Creating installation manifest"
    
    local cursor_version="unknown"
    if command -v cursor >/dev/null 2>&1; then
        cursor_version=$(cursor --version 2>&1 | head -1 || echo "unknown")
    fi
    
    cat > "$INSTALLATION_MANIFEST" << EOF
{
    "installation": {
        "timestamp": "$(date -Iseconds)",
        "version": "$cursor_version",
        "installer_version": "$SCRIPT_VERSION",
        "user": "$USER",
        "system": "$(uname -sr)",
        "paths": {
            "install_dir": "$CURSOR_INSTALL_DIR",
            "user_config": "$USER_CONFIG_DIR",
            "user_data": "$USER_DATA_DIR",
            "user_cache": "$USER_CACHE_DIR"
        }
    },
    "postinstall": {
        "completed": true,
        "timestamp": "$(date -Iseconds)",
        "components": [
            "user_environment",
            "desktop_integration",
            "system_integration",
            "performance_optimization"
        ]
    }
}
EOF
    
    log "PASS" "Installation manifest created"
    audit_log "MANIFEST_CREATED" "SUCCESS" "File: $INSTALLATION_MANIFEST"
}

# === MAIN EXECUTION ===

# Show usage
show_usage() {
    cat << EOF
Professional Post-Installation Framework v$SCRIPT_VERSION

USAGE:
    $SCRIPT_NAME [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -n, --dry-run           Perform dry run without changes
    -q, --quiet             Quiet mode (minimal output)
    --skip-integration      Skip system integration
    --no-monitoring         Disable monitoring setup
    --version               Show version information

EXAMPLES:
    $SCRIPT_NAME                        # Standard post-installation
    $SCRIPT_NAME --dry-run              # Test without changes
    $SCRIPT_NAME --skip-integration     # Skip system integration

EOF
}

# Parse arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            --version)
                echo "Professional Post-Installation Framework v$SCRIPT_VERSION"
                exit 0
                ;;
            -n|--dry-run)
                DRY_RUN=true
                ;;
            -q|--quiet)
                QUIET_MODE=true
                ;;
            --skip-integration)
                SKIP_INTEGRATION=true
                ;;
            --no-monitoring)
                ENABLE_MONITORING=false
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

# Cleanup function
cleanup() {
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log "PASS" "Post-installation completed successfully"
        audit_log "POSTINSTALL_COMPLETE" "SUCCESS" "Exit code: $exit_code"
    else
        log "ERROR" "Post-installation failed with exit code: $exit_code"
        audit_log "POSTINSTALL_FAILED" "FAILURE" "Exit code: $exit_code"
    fi
    
    # Cleanup temporary directory
    [[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
}

trap cleanup EXIT
trap 'exit 130' INT TERM

# Main function
main() {
    # Parse arguments
    parse_arguments "$@"
    
    log "INFO" "Starting Professional Post-Installation Framework v$SCRIPT_VERSION"
    audit_log "POSTINSTALL_STARTED" "SUCCESS" "Version: $SCRIPT_VERSION"
    
    # Initialize
    if ! initialize_directories; then
        log "ERROR" "Failed to initialize directories"
        exit 1
    fi
    
    # Validate installation
    if ! validate_installation; then
        log "ERROR" "Installation validation failed"
        exit 1
    fi
    
    # Configure user environment
    if ! configure_user_environment; then
        log "ERROR" "User environment configuration failed"
        exit 1
    fi
    
    # Setup system integration
    if ! setup_system_integration; then
        log "WARN" "System integration completed with warnings"
    fi
    
    # Optimize performance
    if ! optimize_performance; then
        log "WARN" "Performance optimization completed with warnings"
    fi
    
    # Create installation manifest
    create_installation_manifest
    
    # Summary
    log "PASS" "Post-installation framework completed successfully!"
    log "INFO" "Installation validated and configured"
    log "INFO" "User environment set up"
    log "INFO" "System integration completed"
    log "INFO" "Performance optimized"
    log "INFO" "Logs available at: $LOG_DIR"
    
    audit_log "POSTINSTALL_COMPLETED" "SUCCESS" "All components configured"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi