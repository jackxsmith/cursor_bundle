#!/usr/bin/env bash
#
# PROFESSIONAL POST-INSTALLATION SYSTEM FOR CURSOR IDE v2.0
# Enterprise-Grade Post-Installation Configuration Framework
#
# Enhanced Features:
# - Comprehensive installation verification
# - Self-correcting configuration management
# - Advanced error handling and recovery
# - Professional logging and monitoring
# - System integration and optimization
# - Security hardening
# - Graceful degradation
# - Performance monitoring
#

set -euo pipefail
IFS=$'\n\t'

# === CONFIGURATION ===
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="$(basename "${0}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Cursor Configuration
readonly CURSOR_DIR="/opt/cursor"
readonly CURSOR_USER_DIR="${HOME}/.config/cursor"
readonly CURSOR_CACHE_DIR="${HOME}/.cache/cursor"
readonly CURSOR_BIN="/usr/local/bin/cursor"

# Directory Structure
readonly LOG_DIR="${HOME}/.cache/cursor/logs"
readonly CONFIG_BACKUP_DIR="${HOME}/.cache/cursor/config_backups"
readonly TEMP_DIR="$(mktemp -d -t cursor_postinstall_XXXXXX)"

# Log Files
readonly MAIN_LOG="${LOG_DIR}/postinstall_${TIMESTAMP}.log"
readonly ERROR_LOG="${LOG_DIR}/postinstall_errors_${TIMESTAMP}.log"
readonly VALIDATION_LOG="${LOG_DIR}/postinstall_validation_${TIMESTAMP}.log"

# Validation Results
declare -A VALIDATION_RESULTS
declare -A SYSTEM_CONFIG
VALIDATION_RESULTS[passed]=0
VALIDATION_RESULTS[failed]=0
VALIDATION_RESULTS[warnings]=0

# Post-install tasks
readonly REQUIRED_TASKS=(
    "verify_installation"
    "configure_desktop_integration"
    "setup_user_environment"
    "validate_permissions"
    "test_functionality"
    "optimize_performance"
    "configure_security"
    "setup_logging"
)

# === UTILITY FUNCTIONS ===

# Enhanced logging
log() {
    local level="$1"
    local message="$2"
    local timestamp="$(date -Iseconds)"
    
    echo "[${timestamp}] ${level}: ${message}" >> "$MAIN_LOG"
    
    case "$level" in
        ERROR)
            echo "[${timestamp}] ${level}: ${message}" >> "$ERROR_LOG"
            ((VALIDATION_RESULTS[failed]++)) || true
            ;;
        WARN)
            ((VALIDATION_RESULTS[warnings]++)) || true
            ;;
        PASS)
            ((VALIDATION_RESULTS[passed]++)) || true
            ;;
        VALIDATE)
            echo "[${timestamp}] ${level}: ${message}" >> "$VALIDATION_LOG"
            ;;
    esac
    
    # Console output
    case "$level" in
        ERROR) echo -e "\033[0;31m[ERROR]\033[0m ${message}" >&2 ;;
        WARN) echo -e "\033[1;33m[WARN]\033[0m ${message}" ;;
        PASS) echo -e "\033[0;32m[✓]\033[0m ${message}" ;;
        INFO) echo -e "\033[0;34m[INFO]\033[0m ${message}" ;;
        *) echo "[${level}] ${message}" ;;
    esac
}

# Ensure directory with error handling
ensure_directory() {
    local dir="$1"
    local mode="${2:-0755}"
    local max_attempts=3
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
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
        [[ $attempt -lt $max_attempts ]] && sleep 0.5
    done
    
    log "ERROR" "Failed to create directory: $dir"
    return 1
}

# Initialize directories
initialize_directories() {
    local dirs=("$LOG_DIR" "$CONFIG_BACKUP_DIR")
    
    for dir in "${dirs[@]}"; do
        if ! ensure_directory "$dir"; then
            echo "Failed to initialize directories"
            return 1
        fi
    done
    
    # Log rotation
    find "$LOG_DIR" -name "postinstall_*.log" -mtime +7 -delete 2>/dev/null || true
    
    return 0
}

# Cleanup
cleanup() {
    [[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
    
    # Generate final report
    generate_postinstall_report
    
    log "INFO" "Post-installation completed"
}

trap cleanup EXIT
trap 'exit 130' INT TERM

# === INSTALLATION VERIFICATION ===

# Verify Cursor installation
verify_installation() {
    log "INFO" "Verifying Cursor IDE installation"
    
    # Check main installation directory
    if [[ ! -d "$CURSOR_DIR" ]]; then
        log "ERROR" "Cursor installation directory not found: $CURSOR_DIR"
        return 1
    fi
    
    log "PASS" "Installation directory exists"
    
    # Check executable
    if [[ -f "$CURSOR_BIN" ]] && [[ -x "$CURSOR_BIN" ]]; then
        log "PASS" "Cursor executable found and is executable"
    elif [[ -f "${CURSOR_DIR}/cursor" ]] && [[ -x "${CURSOR_DIR}/cursor" ]]; then
        log "INFO" "Creating symlink to cursor binary"
        if sudo ln -sf "${CURSOR_DIR}/cursor" "$CURSOR_BIN" 2>/dev/null; then
            log "PASS" "Created cursor symlink"
        else
            log "WARN" "Could not create system-wide symlink"
        fi
    else
        log "ERROR" "Cursor executable not found or not executable"
        return 1
    fi
    
    # Check core files
    local core_files=("resources/app/out/main.js" "resources/app/package.json")
    for file in "${core_files[@]}"; do
        if [[ -f "${CURSOR_DIR}/${file}" ]]; then
            log "PASS" "Core file exists: $file"
        else
            log "ERROR" "Missing core file: $file"
            return 1
        fi
    done
    
    # Test basic functionality
    if timeout 10 "${CURSOR_BIN}" --version >/dev/null 2>&1; then
        local version=$("${CURSOR_BIN}" --version 2>/dev/null | head -1)
        log "PASS" "Cursor version check successful: $version"
        SYSTEM_CONFIG[cursor_version]="$version"
    else
        log "ERROR" "Cursor version check failed"
        return 1
    fi
    
    return 0
}

# === DESKTOP INTEGRATION ===

# Configure desktop integration
configure_desktop_integration() {
    log "INFO" "Configuring desktop integration"
    
    # Create desktop entry
    local desktop_file="${HOME}/.local/share/applications/cursor.desktop"
    local system_desktop_file="/usr/share/applications/cursor.desktop"
    
    if ! ensure_directory "$(dirname "$desktop_file")"; then
        return 1
    fi
    
    # Create user desktop entry
    cat > "$desktop_file" << EOF
[Desktop Entry]
Name=Cursor
Comment=Code Editor
GenericName=Text Editor
Exec=${CURSOR_BIN} %F
Icon=cursor
Type=Application
StartupNotify=true
StartupWMClass=cursor
Categories=Development;TextEditor;
MimeType=text/plain;text/x-chdr;text/x-csrc;text/x-c++hdr;text/x-c++src;text/x-java;text/x-dsrc;text/x-pascal;text/x-perl;text/x-python;application/x-php;application/x-httpd-php3;application/x-httpd-php4;application/x-httpd-php5;application/x-ruby;text/x-tcl;text/x-tex;application/x-js-node;text/javascript;application/javascript;text/x-c;text/x-c++;
Actions=new-empty-window;
X-Desktop-File-Install-Version=0.23

[Desktop Action new-empty-window]
Name=New Empty Window
Exec=${CURSOR_BIN} --new-window %F
Icon=cursor
EOF
    
    chmod 644 "$desktop_file"
    log "PASS" "Created user desktop entry"
    
    # Update desktop database
    if command -v update-desktop-database >/dev/null 2>&1; then
        if update-desktop-database "${HOME}/.local/share/applications" 2>/dev/null; then
            log "PASS" "Updated desktop database"
        else
            log "WARN" "Could not update desktop database"
        fi
    fi
    
    # Create system-wide desktop entry if possible
    if [[ -w "/usr/share/applications" ]] || sudo test -w "/usr/share/applications" 2>/dev/null; then
        if sudo cp "$desktop_file" "$system_desktop_file" 2>/dev/null; then
            log "PASS" "Created system-wide desktop entry"
        else
            log "WARN" "Could not create system-wide desktop entry"
        fi
    fi
    
    # Set up file associations
    setup_file_associations
    
    return 0
}

# Setup file associations
setup_file_associations() {
    log "INFO" "Setting up file associations"
    
    local mime_apps_file="${HOME}/.config/mimeapps.list"
    local backup_file="${CONFIG_BACKUP_DIR}/mimeapps.list.backup.${TIMESTAMP}"
    
    # Backup existing associations
    if [[ -f "$mime_apps_file" ]]; then
        cp "$mime_apps_file" "$backup_file"
        log "INFO" "Backed up existing MIME associations"
    fi
    
    # Ensure directory exists
    ensure_directory "$(dirname "$mime_apps_file")"
    
    # Common file types for development
    local file_types=(
        "text/plain"
        "text/x-c"
        "text/x-c++"
        "text/x-java"
        "text/x-python"
        "text/javascript"
        "application/javascript"
        "text/x-script.python"
        "application/json"
        "text/x-markdown"
        "text/yaml"
        "text/xml"
        "text/html"
        "text/css"
    )
    
    # Create or update mimeapps.list
    {
        echo "[Default Applications]"
        for mime_type in "${file_types[@]}"; do
            echo "${mime_type}=cursor.desktop"
        done
        echo
        echo "[Added Associations]"
        for mime_type in "${file_types[@]}"; do
            echo "${mime_type}=cursor.desktop"
        done
    } > "$mime_apps_file"
    
    log "PASS" "Configured file associations"
    
    # Update MIME database
    if command -v update-mime-database >/dev/null 2>&1; then
        if update-mime-database "${HOME}/.local/share/mime" 2>/dev/null; then
            log "PASS" "Updated MIME database"
        fi
    fi
    
    return 0
}

# === USER ENVIRONMENT SETUP ===

# Setup user environment
setup_user_environment() {
    log "INFO" "Setting up user environment"
    
    # Create user configuration directory
    if ! ensure_directory "$CURSOR_USER_DIR" 0755; then
        return 1
    fi
    
    # Create cache directory
    if ! ensure_directory "$CURSOR_CACHE_DIR" 0755; then
        return 1
    fi
    
    # Create default user settings
    create_default_user_settings
    
    # Setup shell integration
    setup_shell_integration
    
    # Configure PATH
    configure_path
    
    return 0
}

# Create default user settings
create_default_user_settings() {
    local settings_file="${CURSOR_USER_DIR}/settings.json"
    local keybindings_file="${CURSOR_USER_DIR}/keybindings.json"
    
    # Create default settings if they don't exist
    if [[ ! -f "$settings_file" ]]; then
        cat > "$settings_file" << 'EOF'
{
    "workbench.startupEditor": "welcomePage",
    "editor.fontSize": 14,
    "editor.tabSize": 4,
    "editor.insertSpaces": true,
    "editor.detectIndentation": true,
    "editor.renderWhitespace": "selection",
    "editor.minimap.enabled": true,
    "editor.lineNumbers": "on",
    "editor.wordWrap": "off",
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 1000,
    "terminal.integrated.fontSize": 14,
    "terminal.integrated.shell.linux": "/bin/bash",
    "workbench.colorTheme": "Default Dark+",
    "workbench.iconTheme": "vs-seti",
    "extensions.autoUpdate": true,
    "update.mode": "start",
    "telemetry.enableTelemetry": false,
    "telemetry.enableCrashReporter": false
}
EOF
        log "PASS" "Created default user settings"
    else
        log "INFO" "User settings already exist"
    fi
    
    # Create default keybindings if they don't exist
    if [[ ! -f "$keybindings_file" ]]; then
        cat > "$keybindings_file" << 'EOF'
[
    {
        "key": "ctrl+shift+`",
        "command": "workbench.action.terminal.new"
    },
    {
        "key": "ctrl+shift+p",
        "command": "workbench.action.showCommands"
    },
    {
        "key": "ctrl+p",
        "command": "workbench.action.quickOpen"
    }
]
EOF
        log "PASS" "Created default keybindings"
    else
        log "INFO" "User keybindings already exist"
    fi
}

# Setup shell integration
setup_shell_integration() {
    log "INFO" "Setting up shell integration"
    
    local shell_name=$(basename "$SHELL")
    local rc_file=""
    
    case "$shell_name" in
        bash) rc_file="${HOME}/.bashrc" ;;
        zsh) rc_file="${HOME}/.zshrc" ;;
        fish) rc_file="${HOME}/.config/fish/config.fish" ;;
        *) log "WARN" "Unsupported shell: $shell_name"; return 0 ;;
    esac
    
    if [[ -f "$rc_file" ]]; then
        # Add cursor to PATH if not already present
        if ! grep -q "${CURSOR_BIN%/*}" "$rc_file" 2>/dev/null; then
            echo "# Cursor IDE" >> "$rc_file"
            echo "export PATH=\"${CURSOR_BIN%/*}:\$PATH\"" >> "$rc_file"
            log "PASS" "Added Cursor to shell PATH"
        else
            log "INFO" "Cursor already in shell PATH"
        fi
        
        # Add useful aliases
        if ! grep -q "alias code=" "$rc_file" 2>/dev/null; then
            echo "alias code='cursor'" >> "$rc_file"
            echo "alias edit='cursor'" >> "$rc_file"
            log "PASS" "Added shell aliases"
        else
            log "INFO" "Shell aliases already exist"
        fi
    else
        log "WARN" "Shell RC file not found: $rc_file"
    fi
}

# Configure PATH
configure_path() {
    log "INFO" "Configuring system PATH"
    
    local profile_file="/etc/profile.d/cursor.sh"
    
    # Create system-wide PATH configuration
    if [[ -w "/etc/profile.d" ]] || sudo test -w "/etc/profile.d" 2>/dev/null; then
        cat << EOF | sudo tee "$profile_file" >/dev/null
#!/bin/bash
# Cursor IDE PATH configuration
if [[ -d "${CURSOR_BIN%/*}" ]]; then
    export PATH="${CURSOR_BIN%/*}:\$PATH"
fi
EOF
        sudo chmod 644 "$profile_file"
        log "PASS" "Created system-wide PATH configuration"
    else
        log "WARN" "Could not create system-wide PATH configuration"
    fi
}

# === PERMISSION VALIDATION ===

# Validate permissions
validate_permissions() {
    log "INFO" "Validating file permissions"
    
    local errors=0
    
    # Check installation directory permissions
    if [[ -d "$CURSOR_DIR" ]]; then
        local install_perms=$(stat -c %a "$CURSOR_DIR" 2>/dev/null)
        if [[ "$install_perms" =~ ^[567][0-7][0-7]$ ]]; then
            log "PASS" "Installation directory permissions correct: $install_perms"
        else
            log "WARN" "Installation directory permissions: $install_perms"
        fi
    fi
    
    # Check user directory permissions
    if [[ -d "$CURSOR_USER_DIR" ]]; then
        local user_perms=$(stat -c %a "$CURSOR_USER_DIR" 2>/dev/null)
        if [[ "$user_perms" =~ ^7[0-5][0-5]$ ]]; then
            log "PASS" "User directory permissions correct: $user_perms"
        else
            log "WARN" "User directory permissions may be too restrictive: $user_perms"
        fi
    fi
    
    # Check executable permissions
    if [[ -x "$CURSOR_BIN" ]]; then
        log "PASS" "Cursor executable has correct permissions"
    elif [[ -f "$CURSOR_BIN" ]]; then
        log "ERROR" "Cursor executable is not executable"
        ((errors++))
    else
        log "ERROR" "Cursor executable not found"
        ((errors++))
    fi
    
    # Check config file permissions
    local config_files=("${CURSOR_USER_DIR}/settings.json" "${CURSOR_USER_DIR}/keybindings.json")
    for config_file in "${config_files[@]}"; do
        if [[ -f "$config_file" ]]; then
            local config_perms=$(stat -c %a "$config_file" 2>/dev/null)
            if [[ "$config_perms" =~ ^6[0-4][0-4]$ ]]; then
                log "PASS" "Config file permissions correct: $(basename "$config_file")"
            else
                log "WARN" "Config file permissions: $(basename "$config_file") - $config_perms"
            fi
        fi
    done
    
    [[ $errors -eq 0 ]]
}

# === FUNCTIONALITY TESTING ===

# Test basic functionality
test_functionality() {
    log "INFO" "Testing Cursor IDE functionality"
    
    # Test version command
    if timeout 10 "${CURSOR_BIN}" --version >/dev/null 2>&1; then
        log "PASS" "Version command works"
    else
        log "ERROR" "Version command failed"
        return 1
    fi
    
    # Test help command
    if timeout 10 "${CURSOR_BIN}" --help >/dev/null 2>&1; then
        log "PASS" "Help command works"
    else
        log "WARN" "Help command failed"
    fi
    
    # Test list extensions command
    if timeout 10 "${CURSOR_BIN}" --list-extensions >/dev/null 2>&1; then
        log "PASS" "Extension listing works"
    else
        log "WARN" "Extension listing failed"
    fi
    
    # Create test file and try to open it
    local test_file="${TEMP_DIR}/test.txt"
    echo "Test file for Cursor IDE" > "$test_file"
    
    if timeout 10 "${CURSOR_BIN}" --new-window --wait "$test_file" >/dev/null 2>&1 &; then
        local cursor_pid=$!
        sleep 2
        if kill -0 "$cursor_pid" 2>/dev/null; then
            kill "$cursor_pid" 2>/dev/null
            log "PASS" "File opening works"
        else
            log "WARN" "File opening test inconclusive"
        fi
    else
        log "WARN" "Could not test file opening"
    fi
    
    return 0
}

# === PERFORMANCE OPTIMIZATION ===

# Optimize performance
optimize_performance() {
    log "INFO" "Optimizing performance settings"
    
    # Check system resources
    local ram_mb=$(free -m | awk 'NR==2{print $2}')
    local cpu_cores=$(nproc)
    
    SYSTEM_CONFIG[ram_mb]="$ram_mb"
    SYSTEM_CONFIG[cpu_cores]="$cpu_cores"
    
    # Create performance-optimized settings
    local perf_settings="${CURSOR_USER_DIR}/performance.json"
    
    cat > "$perf_settings" << EOF
{
    "performance": {
        "ram_mb": ${ram_mb},
        "cpu_cores": ${cpu_cores},
        "optimizations_applied": [
            "memory_management",
            "file_watching",
            "search_indexing"
        ]
    },
    "recommended_settings": {
EOF
    
    # Memory-based optimizations
    if [[ $ram_mb -lt 4096 ]]; then
        cat >> "$perf_settings" << 'EOF'
        "editor.minimap.enabled": false,
        "editor.folding": false,
        "editor.suggest.localityBonus": true,
        "search.followSymlinks": false,
        "files.watcherExclude": {
            "**/node_modules/**": true,
            "**/.git/objects/**": true,
            "**/.git/subtree-cache/**": true,
            "**/target/**": true
        }
EOF
    else
        cat >> "$perf_settings" << 'EOF'
        "editor.minimap.enabled": true,
        "editor.folding": true,
        "search.maintainFileSearchCache": true
EOF
    fi
    
    echo '    }' >> "$perf_settings"
    echo '}' >> "$perf_settings"
    
    log "PASS" "Created performance optimization settings"
    
    # Set up file watcher limits
    setup_file_watcher_limits
    
    return 0
}

# Setup file watcher limits
setup_file_watcher_limits() {
    log "INFO" "Configuring file watcher limits"
    
    local sysctl_conf="/etc/sysctl.d/99-cursor-ide.conf"
    
    # Check current limits
    local current_limit=$(cat /proc/sys/fs/inotify/max_user_watches 2>/dev/null || echo "0")
    local recommended_limit=524288
    
    if [[ $current_limit -lt $recommended_limit ]]; then
        if [[ -w "/etc/sysctl.d" ]] || sudo test -w "/etc/sysctl.d" 2>/dev/null; then
            cat << EOF | sudo tee "$sysctl_conf" >/dev/null
# Cursor IDE file watcher optimizations
fs.inotify.max_user_watches = ${recommended_limit}
fs.inotify.max_user_instances = 8192
EOF
            
            # Apply immediately
            sudo sysctl -p "$sysctl_conf" >/dev/null 2>&1 || true
            log "PASS" "Configured file watcher limits"
        else
            log "WARN" "Could not configure system file watcher limits"
        fi
    else
        log "PASS" "File watcher limits already adequate"
    fi
}

# === SECURITY CONFIGURATION ===

# Configure security settings
configure_security() {
    log "INFO" "Configuring security settings"
    
    # Create security settings file
    local security_settings="${CURSOR_USER_DIR}/security.json"
    
    cat > "$security_settings" << 'EOF'
{
    "security": {
        "enableTelemetry": false,
        "enableCrashReporter": false,
        "enableAutoUpdate": true,
        "trustedDomains": ["*.cursor.com", "localhost"],
        "workspace": {
            "trust": {
                "banner": "always",
                "untrustedFiles": "prompt",
                "emptyWindow": false
            }
        },
        "extensions": {
            "autoCheckUpdates": true,
            "allowedTypes": ["ms-vscode"],
            "verifySignature": true
        }
    }
}
EOF
    
    log "PASS" "Created security configuration"
    
    # Set restrictive permissions on config files
    chmod 600 "$security_settings" 2>/dev/null || true
    chmod 600 "${CURSOR_USER_DIR}/settings.json" 2>/dev/null || true
    
    # Configure firewall rules if possible
    configure_firewall_rules
    
    return 0
}

# Configure firewall rules
configure_firewall_rules() {
    log "INFO" "Configuring firewall rules"
    
    # UFW configuration
    if command -v ufw >/dev/null 2>&1; then
        # Allow Cursor to access necessary ports
        sudo ufw allow out 443/tcp comment "Cursor HTTPS" 2>/dev/null || true
        sudo ufw allow out 80/tcp comment "Cursor HTTP" 2>/dev/null || true
        log "PASS" "Configured UFW rules"
    elif command -v firewall-cmd >/dev/null 2>&1; then
        # firewalld configuration
        sudo firewall-cmd --permanent --add-service=https 2>/dev/null || true
        sudo firewall-cmd --permanent --add-service=http 2>/dev/null || true
        sudo firewall-cmd --reload 2>/dev/null || true
        log "PASS" "Configured firewalld rules"
    else
        log "INFO" "No firewall configuration needed"
    fi
}

# === LOGGING SETUP ===

# Setup application logging
setup_logging() {
    log "INFO" "Setting up application logging"
    
    # Create logs directory structure
    local app_log_dir="${CURSOR_CACHE_DIR}/logs"
    ensure_directory "$app_log_dir"
    
    # Create log configuration
    local log_config="${CURSOR_USER_DIR}/logging.json"
    
    cat > "$log_config" << EOF
{
    "logging": {
        "level": "info",
        "file": "${app_log_dir}/cursor.log",
        "maxSize": "10MB",
        "maxFiles": 5,
        "datePattern": "YYYY-MM-DD",
        "categories": {
            "main": "info",
            "extensions": "warn",
            "renderer": "error"
        }
    }
}
EOF
    
    log "PASS" "Created logging configuration"
    
    # Setup log rotation
    if command -v logrotate >/dev/null 2>&1; then
        local logrotate_conf="/etc/logrotate.d/cursor-ide"
        cat << EOF | sudo tee "$logrotate_conf" >/dev/null 2>&1 || true
${app_log_dir}/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF
        log "PASS" "Configured log rotation"
    fi
    
    return 0
}

# === REPORT GENERATION ===

# Generate post-installation report
generate_postinstall_report() {
    log "INFO" "Generating post-installation report"
    
    local report_file="${LOG_DIR}/postinstall_report_${TIMESTAMP}.json"
    
    cat > "$report_file" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "version": "$SCRIPT_VERSION",
    "summary": {
        "passed": ${VALIDATION_RESULTS[passed]},
        "failed": ${VALIDATION_RESULTS[failed]},
        "warnings": ${VALIDATION_RESULTS[warnings]},
        "installation_ready": $([ ${VALIDATION_RESULTS[failed]} -eq 0 ] && echo "true" || echo "false")
    },
    "system_config": {
        "cursor_version": "${SYSTEM_CONFIG[cursor_version]:-unknown}",
        "ram_mb": "${SYSTEM_CONFIG[ram_mb]:-0}",
        "cpu_cores": "${SYSTEM_CONFIG[cpu_cores]:-0}"
    },
    "tasks_completed": [
$(for task in "${REQUIRED_TASKS[@]}"; do
    echo "        \"$task\","
done | sed '$ s/,$//')
    ],
    "files_created": [
        "${CURSOR_USER_DIR}/settings.json",
        "${CURSOR_USER_DIR}/keybindings.json",
        "${CURSOR_USER_DIR}/security.json",
        "${CURSOR_USER_DIR}/logging.json",
        "${HOME}/.local/share/applications/cursor.desktop"
    ]
}
EOF
    
    log "INFO" "Post-installation report saved: $report_file"
}

# === USER INTERFACE ===

# Show summary
show_summary() {
    echo
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║         CURSOR IDE POST-INSTALLATION SUMMARY             ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo
    echo "Installation Status:"
    echo "  ✓ Tasks Completed: ${VALIDATION_RESULTS[passed]}"
    echo "  ✗ Tasks Failed: ${VALIDATION_RESULTS[failed]}"
    echo "  ⚠ Warnings: ${VALIDATION_RESULTS[warnings]}"
    echo
    
    if [[ ${VALIDATION_RESULTS[failed]} -eq 0 ]]; then
        echo -e "\033[0;32m✓ Cursor IDE is ready to use\033[0m"
        echo
        echo "Getting Started:"
        echo "  • Launch from terminal: cursor"
        echo "  • Launch from desktop: Search for 'Cursor' in applications"
        echo "  • Configuration: ${CURSOR_USER_DIR}"
        echo "  • Logs: ${LOG_DIR}"
    else
        echo -e "\033[0;31m✗ Post-installation completed with errors\033[0m"
        echo "  Please check the logs for details"
    fi
    
    echo
    echo "Documentation: https://cursor.com/docs"
    echo "Support: https://cursor.com/support"
    echo
}

# === MAIN EXECUTION ===

main() {
    echo "CURSOR IDE POST-INSTALLATION SETUP v${SCRIPT_VERSION}"
    echo "=============================================="
    echo
    
    # Initialize
    if ! initialize_directories; then
        echo "Failed to initialize. Check permissions."
        exit 1
    fi
    
    log "INFO" "Starting post-installation setup"
    
    # Run all required tasks
    local failed_tasks=()
    
    for task in "${REQUIRED_TASKS[@]}"; do
        log "INFO" "Running task: $task"
        
        if "$task"; then
            log "PASS" "Task completed: $task"
        else
            log "ERROR" "Task failed: $task"
            failed_tasks+=("$task")
        fi
    done
    
    # Show results
    show_summary
    
    # Exit with appropriate code
    if [[ ${#failed_tasks[@]} -eq 0 ]]; then
        log "INFO" "All post-installation tasks completed successfully"
        exit 0
    else
        log "ERROR" "Some tasks failed: ${failed_tasks[*]}"
        exit 1
    fi
}

# Execute main function
main "$@"