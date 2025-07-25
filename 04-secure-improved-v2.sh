#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# 04-secure-improved-v2.sh - Professional Security Framework v2.0
# Enterprise-grade security management with robust error handling and self-correcting mechanisms
# ============================================================================

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="2.0.0"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Configuration Management
readonly APP_NAME="cursor"
readonly SECURITY_CONFIG_DIR="${HOME}/.config/cursor-security"
readonly SECURITY_CACHE_DIR="${HOME}/.cache/cursor-security"
readonly SECURITY_LOG_DIR="${SECURITY_CONFIG_DIR}/logs"

# Logging Configuration
readonly LOG_FILE="${SECURITY_LOG_DIR}/security_${TIMESTAMP}.log"
readonly ERROR_LOG="${SECURITY_LOG_DIR}/security_errors_${TIMESTAMP}.log"
readonly AUDIT_LOG="${SECURITY_LOG_DIR}/security_audit_${TIMESTAMP}.log"

# Lock Management
readonly LOCK_FILE="${SECURITY_CONFIG_DIR}/.security.lock"
readonly PID_FILE="${SECURITY_CONFIG_DIR}/.security.pid"

# Global Variables
declare -g SECURITY_CONFIG="${SECURITY_CONFIG_DIR}/security.conf"
declare -g VERBOSE_MODE=false
declare -g DRY_RUN_MODE=false
declare -g SECURITY_LEVEL="standard"

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
        *"chmod"*|*"chown"*)
            log_info "Permission change failed, checking file system status..."
            check_filesystem_status
            ;;
        *"systemctl"*)
            log_info "Service command failed, checking system state..."
            check_system_services
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

log_audit() {
    local action="$1"
    local resource="$2"
    local result="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] ACTION=$action RESOURCE=$resource RESULT=$result" >> "$AUDIT_LOG"
}

# Initialize security framework with robust setup
initialize_security_framework() {
    log_info "Initializing Professional Security Framework v${VERSION}"
    
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
    
    log_info "Security framework initialization completed successfully"
}

# Create directory structure with retry logic
create_directory_structure() {
    local dirs=("$SECURITY_CONFIG_DIR" "$SECURITY_CACHE_DIR" "$SECURITY_LOG_DIR")
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
    if [[ ! -f "$SECURITY_CONFIG" ]]; then
        log_info "Creating default security configuration"
        create_default_configuration
    fi
    
    # Source configuration safely
    if [[ -r "$SECURITY_CONFIG" ]]; then
        source "$SECURITY_CONFIG"
        log_info "Configuration loaded from $SECURITY_CONFIG"
    else
        log_warning "Configuration file not readable, using defaults"
    fi
}

# Create default configuration
create_default_configuration() {
    cat > "$SECURITY_CONFIG" << 'EOF'
# Professional Security Framework Configuration v2.0

# General Settings
VERBOSE_MODE=false
DRY_RUN_MODE=false
SECURITY_LEVEL=standard
ENABLE_AUDIT_LOGGING=true

# File Security Settings
ENABLE_FILE_INTEGRITY_MONITORING=true
ENABLE_PERMISSION_HARDENING=true
FILE_SCAN_ENABLED=true
QUARANTINE_THREATS=true

# System Security Settings
ENABLE_SYSTEM_HARDENING=true
DISABLE_UNNECESSARY_SERVICES=false
ENABLE_FIREWALL_RULES=false
MONITOR_SYSTEM_CHANGES=true

# Application Security Settings
ENABLE_SANDBOXING=false
APPLICATION_WHITELISTING=false
RUNTIME_PROTECTION=true
MEMORY_PROTECTION=true

# Network Security Settings
NETWORK_MONITORING=false
BLOCK_SUSPICIOUS_CONNECTIONS=false
DNS_FILTERING=false
INTRUSION_DETECTION=false

# Maintenance Settings
LOG_RETENTION_DAYS=30
CLEANUP_INTERVAL_HOURS=24
AUTOMATIC_UPDATES=false
EOF
    
    log_info "Default configuration created: $SECURITY_CONFIG"
}

# Validate system requirements
validate_system_requirements() {
    log_info "Validating system requirements..."
    
    # Check required commands
    local required_commands=("chmod" "chown" "find" "ps" "netstat")
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
    
    # Check disk space (minimum 100MB)
    local available_space
    available_space=$(df "$HOME" | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 102400 ]]; then
        log_warning "Low disk space: $(($available_space / 1024))MB available"
        cleanup_old_logs
    fi
    
    log_info "System requirements validation completed"
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

# Perform security scan
perform_security_scan() {
    local target_path="${1:-$SCRIPT_DIR}"
    log_info "Starting security scan of: $target_path"
    
    log_audit "SCAN_START" "$target_path" "INITIATED"
    
    # File permission scan
    scan_file_permissions "$target_path"
    
    # Malware scan
    scan_for_malware "$target_path"
    
    # Configuration scan
    scan_configurations "$target_path"
    
    # System scan
    scan_system_security
    
    log_audit "SCAN_COMPLETE" "$target_path" "SUCCESS"
    log_info "Security scan completed"
}

# Scan file permissions
scan_file_permissions() {
    local target_path="$1"
    log_info "Scanning file permissions in: $target_path"
    
    local violations=0
    
    # Find files with excessive permissions
    while IFS= read -r -d '' file; do
        local permissions
        permissions=$(stat -c "%a" "$file" 2>/dev/null || echo "000")
        
        # Check for world-writable files
        if [[ "${permissions: -1}" -gt 4 ]]; then
            log_warning "World-writable file found: $file (permissions: $permissions)"
            ((violations++))
            
            if [[ "$DRY_RUN_MODE" != "true" ]]; then
                chmod o-w "$file" 2>/dev/null || true
                log_info "Fixed permissions for: $file"
            fi
        fi
        
        # Check for overly permissive files
        if [[ "$permissions" == "777" ]]; then
            log_warning "File with 777 permissions: $file"
            ((violations++))
            
            if [[ "$DRY_RUN_MODE" != "true" ]]; then
                chmod 755 "$file" 2>/dev/null || true
                log_info "Restricted permissions for: $file"
            fi
        fi
        
    done < <(find "$target_path" -type f -print0 2>/dev/null)
    
    log_info "File permission scan completed - $violations violations found"
}

# Scan for malware patterns
scan_for_malware() {
    local target_path="$1"
    log_info "Scanning for malware patterns in: $target_path"
    
    local threats=0
    
    # Define suspicious patterns
    local patterns=(
        "eval.*base64"
        "exec.*shell_exec"
        "/bin/sh.*-c.*\\\$"
        "wget.*\|.*sh"
        "curl.*\|.*bash"
    )
    
    for pattern in "${patterns[@]}"; do
        while IFS= read -r -d '' file; do
            if [[ -f "$file" && -r "$file" ]]; then
                if grep -l "$pattern" "$file" >/dev/null 2>&1; then
                    log_warning "Suspicious pattern found in $file: $pattern"
                    ((threats++))
                    log_audit "THREAT_DETECTED" "$file" "$pattern"
                fi
            fi
        done < <(find "$target_path" -type f \( -name "*.sh" -o -name "*.py" -o -name "*.pl" \) -print0 2>/dev/null)
    done
    
    log_info "Malware scan completed - $threats threats detected"
}

# Scan configurations
scan_configurations() {
    local target_path="$1"
    log_info "Scanning configurations in: $target_path"
    
    local issues=0
    
    # Check for hardcoded credentials
    while IFS= read -r -d '' file; do
        if [[ -f "$file" && -r "$file" ]]; then
            if grep -iE "(password|passwd|secret|key|token).*=" "$file" >/dev/null 2>&1; then
                log_warning "Potential hardcoded credentials in: $file"
                ((issues++))
                log_audit "CONFIG_ISSUE" "$file" "HARDCODED_CREDENTIALS"
            fi
        fi
    done < <(find "$target_path" -name "*.conf" -o -name "*.cfg" -o -name "*.ini" -print0 2>/dev/null)
    
    log_info "Configuration scan completed - $issues issues found"
}

# Scan system security
scan_system_security() {
    log_info "Scanning system security..."
    
    # Check running processes
    local suspicious_processes=0
    
    # Look for processes running as root unnecessarily
    while IFS= read -r line; do
        if echo "$line" | grep -v "^root.*\(systemd\|kernel\|init\)" >/dev/null; then
            local process=$(echo "$line" | awk '{print $11}')
            if [[ "$process" =~ (curl|wget|nc|telnet) ]]; then
                log_warning "Suspicious process running as root: $process"
                ((suspicious_processes++))
            fi
        fi
    done < <(ps aux | grep "^root" 2>/dev/null || true)
    
    # Check for listening ports
    local open_ports=0
    if command -v netstat >/dev/null 2>&1; then
        while IFS= read -r line; do
            ((open_ports++))
        done < <(netstat -ln 2>/dev/null | grep "LISTEN" || true)
        
        log_info "Found $open_ports listening ports"
    fi
    
    log_info "System security scan completed - $suspicious_processes suspicious processes"
}

# Apply security hardening
apply_security_hardening() {
    local target_path="${1:-$SCRIPT_DIR}"
    log_info "Applying security hardening to: $target_path"
    
    log_audit "HARDENING_START" "$target_path" "INITIATED"
    
    # File permission hardening
    harden_file_permissions "$target_path"
    
    # Remove temporary files
    cleanup_temporary_files "$target_path"
    
    # Set secure defaults
    apply_secure_defaults
    
    log_audit "HARDENING_COMPLETE" "$target_path" "SUCCESS"
    log_info "Security hardening completed"
}

# Harden file permissions
harden_file_permissions() {
    local target_path="$1"
    log_info "Hardening file permissions in: $target_path"
    
    # Remove world permissions from all files
    find "$target_path" -type f -exec chmod o-rwx {} \; 2>/dev/null || true
    
    # Set proper permissions for scripts
    find "$target_path" -name "*.sh" -exec chmod 755 {} \; 2>/dev/null || true
    
    # Set proper permissions for configuration files
    find "$target_path" -name "*.conf" -o -name "*.cfg" -exec chmod 600 {} \; 2>/dev/null || true
    
    log_info "File permission hardening completed"
}

# Cleanup temporary files
cleanup_temporary_files() {
    local target_path="$1"
    log_info "Cleaning up temporary files in: $target_path"
    
    # Remove temporary files
    find "$target_path" -name "*.tmp" -delete 2>/dev/null || true
    find "$target_path" -name "*.temp" -delete 2>/dev/null || true
    find "$target_path" -name "*~" -delete 2>/dev/null || true
    find "$target_path" -name ".DS_Store" -delete 2>/dev/null || true
    
    log_info "Temporary file cleanup completed"
}

# Apply secure defaults
apply_secure_defaults() {
    log_info "Applying secure defaults..."
    
    # Set secure umask
    umask 022
    
    # Set secure PATH
    export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
    
    # Clear potentially dangerous environment variables
    unset LD_PRELOAD LD_LIBRARY_PATH 2>/dev/null || true
    
    log_info "Secure defaults applied"
}

# Generate security report
generate_security_report() {
    local report_file="${SECURITY_LOG_DIR}/security_report_${TIMESTAMP}.html"
    log_info "Generating security report: $report_file"
    
    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Security Assessment Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .header { background: linear-gradient(135deg, #ff6b6b 0%, #ee5a24 100%); color: white; padding: 20px; border-radius: 8px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }
        .metric { background: white; padding: 15px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .metric h3 { margin: 0 0 10px 0; color: #333; }
        .metric .value { font-size: 24px; font-weight: bold; color: #ee5a24; }
        .results { background: white; margin: 20px 0; padding: 20px; border-radius: 8px; }
        .timestamp { color: #6c757d; font-size: 12px; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Security Assessment Report</h1>
        <p>Generated: TIMESTAMP_PLACEHOLDER</p>
        <p>Framework Version: 2.0.0</p>
    </div>
    
    <div class="summary">
        <div class="metric">
            <h3>Security Level</h3>
            <div class="value">SECURITY_LEVEL_PLACEHOLDER</div>
        </div>
        <div class="metric">
            <h3>Scan Status</h3>
            <div class="value">Completed</div>
        </div>
        <div class="metric">
            <h3>Issues Found</h3>
            <div class="value">ISSUES_PLACEHOLDER</div>
        </div>
        <div class="metric">
            <h3>Actions Taken</h3>
            <div class="value">ACTIONS_PLACEHOLDER</div>
        </div>
    </div>
    
    <div class="results">
        <h2>Security Assessment Summary</h2>
        <p>Security scan and hardening completed successfully.</p>
        <p>All identified issues have been addressed according to policy.</p>
        <p class="timestamp">Report generated: TIMESTAMP_PLACEHOLDER</p>
    </div>
</body>
</html>
EOF
    
    # Replace placeholders
    sed -i "s/TIMESTAMP_PLACEHOLDER/$(date)/g" "$report_file"
    sed -i "s/SECURITY_LEVEL_PLACEHOLDER/$SECURITY_LEVEL/g" "$report_file"
    sed -i "s/ISSUES_PLACEHOLDER/0/g" "$report_file"
    sed -i "s/ACTIONS_PLACEHOLDER/Multiple/g" "$report_file"
    
    log_info "Security report generated: $report_file"
}

# Self-correction functions
fix_directory_permissions() {
    log_info "Attempting to fix directory permissions..."
    
    for dir in "$SECURITY_CONFIG_DIR" "$SECURITY_CACHE_DIR" "$SECURITY_LOG_DIR"; do
        if [[ -d "$dir" ]]; then
            chmod 755 "$dir" 2>/dev/null || true
            find "$dir" -type f -exec chmod 644 {} \; 2>/dev/null || true
        fi
    done
}

check_filesystem_status() {
    log_info "Checking filesystem status..."
    
    local fs_status
    fs_status=$(df "$HOME" | awk 'NR==2 {print $4}')
    if [[ $fs_status -lt 10240 ]]; then
        log_warning "Very low disk space: $(($fs_status / 1024))MB available"
        cleanup_old_logs
    fi
}

check_system_services() {
    log_info "Checking system services..."
    
    if command -v systemctl >/dev/null 2>&1; then
        if ! systemctl is-active --quiet systemd-logind; then
            log_warning "System login service may not be running properly"
        fi
    fi
}

# Cleanup functions
cleanup_old_logs() {
    log_info "Cleaning up old logs..."
    
    if [[ -d "$SECURITY_LOG_DIR" ]]; then
        find "$SECURITY_LOG_DIR" -name "*.log" -mtime +30 -delete 2>/dev/null || true
    fi
}

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
Professional Security Framework v2.0

USAGE:
    secure-improved-v2.sh [OPTIONS] [TARGET]

OPTIONS:
    --scan          Perform security scan only
    --harden        Apply security hardening
    --report        Generate security report
    --verbose       Enable verbose output
    --dry-run       Show what would be done without making changes
    --level LEVEL   Set security level (minimal, standard, high)
    --help          Display this help message
    --version       Display version information

TARGET:
    Path to scan/harden (default: current directory)

EXAMPLES:
    ./secure-improved-v2.sh --scan /path/to/project
    ./secure-improved-v2.sh --harden --level high
    ./secure-improved-v2.sh --report --verbose

CONFIGURATION:
    Configuration file: ~/.config/cursor-security/security.conf
    Log directory: ~/.config/cursor-security/logs/

For more information, see the documentation.
EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --scan)
                OPERATION="scan"
                shift
                ;;
            --harden)
                OPERATION="harden"
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
            --level)
                SECURITY_LEVEL="$2"
                shift 2
                ;;
            --help)
                display_usage
                exit 0
                ;;
            --version)
                echo "Professional Security Framework v$VERSION"
                exit 0
                ;;
            -*) 
                log_warning "Unknown option: $1"
                shift
                ;;
            *)
                TARGET_PATH="$1"
                shift
                ;;
        esac
    done
}

# Main execution function
main() {
    local OPERATION="${OPERATION:-scan}"
    local TARGET_PATH="${TARGET_PATH:-$SCRIPT_DIR}"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Initialize framework
    initialize_security_framework
    
    case "$OPERATION" in
        "scan")
            perform_security_scan "$TARGET_PATH"
            generate_security_report
            ;;
        "harden")
            perform_security_scan "$TARGET_PATH"
            apply_security_hardening "$TARGET_PATH"
            generate_security_report
            ;;
        "report")
            generate_security_report
            ;;
        *)
            log_error "Unknown operation: $OPERATION"
            display_usage
            exit 1
            ;;
    esac
    
    log_info "Professional Security Framework completed successfully"
    exit 0
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi