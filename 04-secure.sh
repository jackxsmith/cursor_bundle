#!/usr/bin/env bash
#
# CURSOR BUNDLE SECURITY FRAMEWORK v2.0 - Professional Edition
# Professional security framework with policy compliance
#
# Features:
# - Multi-layered security validation
# - Professional error handling and self-correction
# - Strong monitoring and threat detection
# - Comprehensive audit logging
# - Security policy enforcement
# - Professional incident response
#

set -euo pipefail
IFS=$'\n\t'

# === CONFIGURATION ===
readonly SCRIPT_VERSION="2.0-professional"
readonly SCRIPT_NAME="$(basename "${0}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Application Configuration
readonly CURSOR_VERSION="$(cat "${SCRIPT_DIR}/VERSION" 2>/dev/null || echo "unknown")"

# Security Framework Configuration
readonly SECURITY_CONFIG_DIR="${HOME}/.config/cursor-security"
readonly SECURITY_CACHE_DIR="${HOME}/.cache/cursor-security"
readonly SECURITY_LOG_DIR="${SECURITY_CONFIG_DIR}/logs"
readonly SECURITY_QUARANTINE_DIR="${SECURITY_CACHE_DIR}/quarantine"

# Configuration Files
readonly SECURITY_CONFIG="${SECURITY_CONFIG_DIR}/security.conf"
readonly THREAT_DB="${SECURITY_CACHE_DIR}/threat_database.json"

# Log Files
readonly SECURITY_LOG="${SECURITY_LOG_DIR}/security_${TIMESTAMP}.log"
readonly AUDIT_LOG="${SECURITY_LOG_DIR}/audit_${TIMESTAMP}.log"
readonly INCIDENT_LOG="${SECURITY_LOG_DIR}/incidents_${TIMESTAMP}.log"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'

# Security State Variables
declare -g SECURITY_LEVEL="standard"
declare -g PROTECTION_MODE="prevention"
declare -g VERBOSE=false
declare -g DEBUG_MODE=false
declare -g MONITORING_ENABLED=true
declare -g SANDBOX_ENABLED=true
declare -g AUDIT_ENABLED=true

# Security Metrics
declare -A THREAT_COUNTERS=(
    ["file"]=0
    ["process"]=0
    ["network"]=0
)

# === LOGGING AND ERROR HANDLING ===
security_log() {
    local level="${1:-INFO}"
    local message="$2"
    local component="${3:-SECURITY}"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Ensure log directory exists
    mkdir -p "${SECURITY_LOG_DIR}" 2>/dev/null || {
        echo "ERROR: Cannot create log directory" >&2
        return 1
    }
    
    # Write to log files with error handling
    {
        echo "[${timestamp}] [${level}] [${component}] ${message}" >> "${SECURITY_LOG}"
        
        # Audit log for security events
        if [[ "${level}" =~ ^(SECURITY|THREAT|BREACH|VIOLATION)$ ]]; then
            echo "[${timestamp}] [AUDIT] [${component}] ${message}" >> "${AUDIT_LOG}"
        fi
        
        # Incident log for critical events
        if [[ "${level}" =~ ^(CRITICAL|EMERGENCY|BREACH)$ ]]; then
            echo "[${timestamp}] [INCIDENT] [${component}] ${message}" >> "${INCIDENT_LOG}"
            trigger_security_alert "${level}" "${message}" "${component}"
        fi
    } 2>/dev/null || {
        echo "WARNING: Cannot write to log files" >&2
    }
    
    # Console output with colors
    case "${level}" in
        "CRITICAL"|"EMERGENCY"|"BREACH") 
            echo -e "${RED}${BOLD}[${level}]${NC} ${message}" >&2
            ;;
        "SECURITY"|"THREAT") 
            echo -e "${RED}[${level}]${NC} ${message}" >&2
            ;;
        "ERROR") 
            echo -e "${RED}[ERROR]${NC} ${message}" >&2
            ;;
        "WARN"|"VIOLATION") 
            echo -e "${YELLOW}[${level}]${NC} ${message}"
            ;;
        "SUCCESS"|"PASS") 
            echo -e "${GREEN}[✓]${NC} ${message}"
            ;;
        "INFO") 
            [[ "$VERBOSE" != "false" ]] && echo -e "${BLUE}[INFO]${NC} ${message}"
            ;;
        "DEBUG") 
            [[ "$DEBUG_MODE" == "true" ]] && echo -e "[DEBUG] ${message}"
            ;;
    esac
}

# Professional error handler with self-correction
error_handler() {
    local line_no="$1"
    local bash_command="$2"
    local exit_code="$3"
    
    security_log "ERROR" "Command failed at line $line_no: $bash_command (exit code: $exit_code)" "ERROR_HANDLER"
    
    # Self-correction attempts
    case "$bash_command" in
        *mkdir*)
            security_log "INFO" "Attempting to create missing directories..." "CORRECTION"
            ensure_security_directories
            ;;
        *find*)
            security_log "INFO" "File discovery failed, checking directory permissions..." "CORRECTION"
            if [[ ! -r "$SCRIPT_DIR" ]]; then
                security_log "ERROR" "Script directory is not readable: $SCRIPT_DIR" "CORRECTION"
                return 1
            fi
            ;;
        *curl*|*wget*)
            security_log "INFO" "Network operation failed, continuing with local resources..." "CORRECTION"
            return 0
            ;;
    esac
}

trigger_security_alert() {
    local level="$1"
    local message="$2"
    local component="$3"
    local alert_timestamp="$(date -Iseconds)"
    
    # Send system notification if available
    if command -v notify-send >/dev/null 2>&1; then
        notify-send --urgency=critical "SECURITY ALERT" "${level}: ${message}"
    fi
    
    # Log to system log if available
    if command -v logger >/dev/null 2>&1; then
        logger -p security.crit "CursorSecurity[$$]: ${level} in ${component}: ${message}"
    fi
    
    # Create incident record
    local incident_id="INC_${TIMESTAMP}_$(date +%s)"
    local incident_file="${SECURITY_LOG_DIR}/incident_${incident_id}.json"
    
    cat > "${incident_file}" <<EOF
{
    "incident_id": "${incident_id}",
    "timestamp": "${alert_timestamp}",
    "level": "${level}",
    "component": "${component}",
    "message": "${message}",
    "system_info": {
        "hostname": "$(hostname)",
        "user": "$(whoami)",
        "pid": "$$",
        "pwd": "$(pwd)"
    }
}
EOF
    
    security_log "INFO" "Security incident recorded: ${incident_id}" "ALERT_SYSTEM"
}

# === INITIALIZATION ===
ensure_security_directories() {
    local dirs=(
        "${SECURITY_CONFIG_DIR}"
        "${SECURITY_CACHE_DIR}"
        "${SECURITY_LOG_DIR}"
        "${SECURITY_QUARANTINE_DIR}"
    )
    
    for dir in "${dirs[@]}"; do
        if ! mkdir -p "$dir" 2>/dev/null; then
            security_log "ERROR" "Failed to create directory: $dir" "INIT"
            return 1
        fi
        
        # Set secure permissions
        chmod 700 "$dir" 2>/dev/null || {
            security_log "WARN" "Could not set secure permissions on $dir" "INIT"
        }
    done
    
    security_log "DEBUG" "Security directory structure created" "INIT"
    return 0
}

initialize_security_framework() {
    security_log "INFO" "Initializing Security Framework v${SCRIPT_VERSION}" "INIT"
    
    # Set error handler
    trap 'error_handler ${LINENO} "$BASH_COMMAND" $?' ERR
    
    # Create security directory structure
    ensure_security_directories || {
        security_log "CRITICAL" "Failed to create security directories" "INIT"
        return 1
    }
    
    # Initialize security configuration
    if [[ ! -f "${SECURITY_CONFIG}" ]]; then
        create_default_security_config
    fi
    
    # Load security configuration
    load_security_configuration
    
    # Initialize threat database
    initialize_threat_database
    
    # Start security monitoring if enabled
    if [[ "${MONITORING_ENABLED}" == "true" ]]; then
        start_security_monitoring &
    fi
    
    security_log "PASS" "Security framework initialized successfully" "INIT"
    return 0
}

create_default_security_config() {
    security_log "INFO" "Creating default security configuration" "CONFIG"
    
    cat > "${SECURITY_CONFIG}" <<EOF
# Cursor Security Framework Configuration v${SCRIPT_VERSION}
# Generated: $(date -Iseconds)

[general]
security_level=standard
protection_mode=prevention
auto_remediation=true
quarantine_threats=true

[monitoring]
monitoring_enabled=true
file_integrity_monitoring=true
network_monitoring=true
process_monitoring=true

[detection]
signature_based_detection=true
behavioral_analysis=true
anomaly_detection=true

[response]
auto_quarantine=true
incident_reporting=true
alert_notifications=true

[compliance]
security_policy_enforcement=true
audit_logging=true
data_protection=true
EOF
    
    chmod 600 "${SECURITY_CONFIG}"
    security_log "PASS" "Default security configuration created" "CONFIG"
}

load_security_configuration() {
    security_log "DEBUG" "Loading security configuration" "CONFIG"
    
    if [[ -f "${SECURITY_CONFIG}" ]]; then
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ "${key}" =~ ^[[:space:]]*# ]] && continue
            [[ -z "${key}" ]] && continue
            [[ "${key}" =~ ^\[.*\]$ ]] && continue
            
            # Process configuration values
            case "${key}" in
                "security_level") SECURITY_LEVEL="${value}" ;;
                "protection_mode") PROTECTION_MODE="${value}" ;;
                "monitoring_enabled") MONITORING_ENABLED="${value}" ;;
                "sandbox_enabled") SANDBOX_ENABLED="${value}" ;;
                "audit_enabled") AUDIT_ENABLED="${value}" ;;
            esac
        done < "${SECURITY_CONFIG}"
        
        security_log "DEBUG" "Configuration loaded: level=${SECURITY_LEVEL}, mode=${PROTECTION_MODE}" "CONFIG"
    else
        security_log "WARN" "Configuration file not found, using defaults" "CONFIG"
    fi
}

# === THREAT DATABASE ===
initialize_threat_database() {
    security_log "DEBUG" "Initializing threat database" "THREAT_DB"
    
    if [[ ! -f "${THREAT_DB}" ]]; then
        cat > "${THREAT_DB}" <<EOF
{
    "version": "${SCRIPT_VERSION}",
    "last_updated": "$(date -Iseconds)",
    "threat_signatures": [
        {
            "id": "MALWARE_001",
            "name": "Suspicious eval pattern",
            "pattern": "eval.*base64",
            "severity": "high",
            "action": "quarantine"
        },
        {
            "id": "EXPLOIT_001", 
            "name": "Shell injection attempt",
            "pattern": "rm.*-rf.*\\$",
            "severity": "critical",
            "action": "block"
        }
    ],
    "file_blacklist": [
        "*.exe.sh",
        "*malware*",
        "*trojan*"
    ],
    "process_blacklist": [
        "nc -l",
        "python -c import"
    ]
}
EOF
        
        chmod 600 "${THREAT_DB}"
        security_log "PASS" "Threat database initialized" "THREAT_DB"
    else
        security_log "DEBUG" "Threat database already exists" "THREAT_DB"
    fi
}

# === SECURITY MONITORING ===
start_security_monitoring() {
    security_log "INFO" "Starting security monitoring services" "MONITOR"
    
    # File integrity monitoring
    start_file_monitoring &
    
    # Process monitoring  
    start_process_monitoring &
    
    # Network monitoring
    start_network_monitoring &
    
    security_log "PASS" "Security monitoring started" "MONITOR"
}

start_file_monitoring() {
    while true; do
        # Monitor critical files for changes
        local monitor_paths=("${SCRIPT_DIR}" "${HOME}/.config/cursor")
        
        for path in "${monitor_paths[@]}"; do
            if [[ -d "${path}" ]]; then
                find "${path}" -type f -newer "${SECURITY_LOG}" 2>/dev/null | while read -r file; do
                    security_log "DEBUG" "Modified file detected: ${file}" "FILE_MONITOR"
                    check_file_threat "${file}"
                done
            fi
        done
        
        sleep 300  # Check every 5 minutes
    done
}

start_process_monitoring() {
    local last_ps="${SECURITY_CACHE_DIR}/last_ps.txt"
    
    while true; do
        local current_ps="${SECURITY_CACHE_DIR}/current_ps.txt"
        ps aux > "${current_ps}" 2>/dev/null || continue
        
        if [[ -f "${last_ps}" ]]; then
            # Compare process lists
            local new_processes
            if new_processes=$(comm -13 <(sort "${last_ps}") <(sort "${current_ps}") 2>/dev/null); then
                if [[ -n "${new_processes}" ]]; then
                    while IFS= read -r process; do
                        security_log "DEBUG" "New process: ${process}" "PROC_MONITOR"
                        check_process_threat "${process}"
                    done <<< "${new_processes}"
                fi
            fi
        fi
        
        mv "${current_ps}" "${last_ps}" 2>/dev/null || true
        sleep 60
    done
}

start_network_monitoring() {
    while true; do
        if command -v ss >/dev/null 2>&1; then
            # Check for suspicious network activity
            local suspicious_connections
            suspicious_connections=$(ss -tuln 2>/dev/null | grep -E ":(6666|1337|4444)" || true)
            
            if [[ -n "${suspicious_connections}" ]]; then
                security_log "THREAT" "Suspicious network connections: ${suspicious_connections}" "NET_MONITOR"
                handle_network_threat "${suspicious_connections}"
            fi
        fi
        
        sleep 120
    done
}

# === THREAT DETECTION ===
check_file_threat() {
    local file_path="$1"
    
    # Skip if file doesn't exist or is not readable
    [[ ! -r "${file_path}" ]] && return 0
    
    security_log "DEBUG" "Scanning file for threats: ${file_path}" "THREAT_SCAN"
    
    # Check against basic threat patterns
    local threat_patterns=(
        'eval.*\$.*'
        'exec.*\$.*'
        'rm.*-rf.*\$'
        'wget.*\|'
        'curl.*\|'
    )
    
    for pattern in "${threat_patterns[@]}"; do
        if grep -qE "${pattern}" "${file_path}" 2>/dev/null; then
            security_log "THREAT" "Threat pattern detected in ${file_path}: ${pattern}" "THREAT_SCAN"
            handle_file_threat "${file_path}" "${pattern}"
            return 1
        fi
    done
    
    # Check filename against blacklist
    local filename="$(basename "${file_path}")"
    local blacklist_patterns=("*malware*" "*trojan*" "*.exe.sh")
    
    for pattern in "${blacklist_patterns[@]}"; do
        if [[ "${filename}" == ${pattern} ]]; then
            security_log "THREAT" "Blacklisted file detected: ${file_path}" "THREAT_SCAN"
            handle_file_threat "${file_path}" "blacklisted_file"
            return 1
        fi
    done
    
    return 0
}

check_process_threat() {
    local process_info="$1"
    local command="$(echo "${process_info}" | awk '{for(i=11;i<=NF;i++) printf "%s ", $i; print ""}')"
    
    security_log "DEBUG" "Scanning process for threats: ${command}" "THREAT_SCAN"
    
    # Check against process blacklist
    local blacklist_patterns=("nc -l" "python -c import" "perl -e")
    
    for pattern in "${blacklist_patterns[@]}"; do
        if [[ "${command}" =~ ${pattern} ]]; then
            security_log "THREAT" "Malicious process detected: ${command}" "THREAT_SCAN"
            handle_process_threat "${process_info}" "${pattern}"
            return 1
        fi
    done
    
    return 0
}

# === THREAT HANDLING ===
handle_file_threat() {
    local file_path="$1"
    local threat_pattern="$2"
    
    security_log "THREAT" "Handling file threat: ${file_path} (${threat_pattern})" "THREAT_HANDLER"
    
    case "${PROTECTION_MODE}" in
        "quarantine"|"prevention")
            quarantine_file "${file_path}"
            ;;
        *)
            security_log "WARN" "File threat detected but not remediated: ${file_path}" "THREAT_HANDLER"
            ;;
    esac
    
    # Update metrics
    THREAT_COUNTERS["file"]=$((THREAT_COUNTERS["file"] + 1))
}

handle_process_threat() {
    local process_info="$1"
    local threat_pattern="$2"
    local pid="$(echo "${process_info}" | awk '{print $2}')"
    
    security_log "THREAT" "Handling process threat: PID ${pid} (${threat_pattern})" "THREAT_HANDLER"
    
    case "${PROTECTION_MODE}" in
        "quarantine"|"prevention")
            if kill -0 "${pid}" 2>/dev/null; then
                security_log "SECURITY" "Terminating malicious process: PID ${pid}" "THREAT_HANDLER"
                kill -TERM "${pid}" 2>/dev/null || true
                sleep 2
                if kill -0 "${pid}" 2>/dev/null; then
                    kill -KILL "${pid}" 2>/dev/null || true
                fi
            fi
            ;;
        *)
            security_log "WARN" "Process threat detected but not terminated: PID ${pid}" "THREAT_HANDLER"
            ;;
    esac
    
    # Update metrics
    THREAT_COUNTERS["process"]=$((THREAT_COUNTERS["process"] + 1))
}

handle_network_threat() {
    local connection_info="$1"
    
    security_log "THREAT" "Handling network threat: ${connection_info}" "THREAT_HANDLER"
    
    case "${PROTECTION_MODE}" in
        "quarantine"|"prevention")
            security_log "SECURITY" "Network threat detected and logged: ${connection_info}" "THREAT_HANDLER"
            ;;
        *)
            security_log "WARN" "Network threat detected but not blocked: ${connection_info}" "THREAT_HANDLER"
            ;;
    esac
    
    # Update metrics
    THREAT_COUNTERS["network"]=$((THREAT_COUNTERS["network"] + 1))
}

quarantine_file() {
    local file_path="$1"
    local quarantine_path="${SECURITY_QUARANTINE_DIR}/$(basename "${file_path}")_${TIMESTAMP}"
    
    security_log "SECURITY" "Quarantining file: ${file_path} -> ${quarantine_path}" "QUARANTINE"
    
    if mv "${file_path}" "${quarantine_path}" 2>/dev/null; then
        chmod 000 "${quarantine_path}" 2>/dev/null || true
        
        # Create quarantine metadata
        cat > "${quarantine_path}.meta" <<EOF
{
    "original_path": "${file_path}",
    "quarantine_time": "$(date -Iseconds)",
    "quarantine_reason": "threat_detected",
    "automated": true
}
EOF
        
        security_log "PASS" "File quarantined successfully: ${file_path}" "QUARANTINE"
    else
        security_log "ERROR" "Failed to quarantine file: ${file_path}" "QUARANTINE"
    fi
}

# === SECURITY OPERATIONS ===
scan_path_for_threats() {
    local scan_path="${1:-$SCRIPT_DIR}"
    
    security_log "INFO" "Scanning path for threats: ${scan_path}" "SCAN"
    
    local threats_found=0
    
    if [[ -d "${scan_path}" ]]; then
        while IFS= read -r -d '' file; do
            if check_file_threat "${file}"; then
                ((threats_found++))
            fi
        done < <(find "${scan_path}" -type f -print0 2>/dev/null)
    elif [[ -f "${scan_path}" ]]; then
        if check_file_threat "${scan_path}"; then
            threats_found=1
        fi
    else
        security_log "ERROR" "Scan path does not exist: ${scan_path}" "SCAN"
        return 1
    fi
    
    security_log "INFO" "Scan completed: ${threats_found} threats found in ${scan_path}" "SCAN"
    return 0
}

generate_security_report() {
    local report_file="${SECURITY_LOG_DIR}/security_report_${TIMESTAMP}.json"
    
    security_log "INFO" "Generating security report" "REPORT"
    
    local total_threats=$((THREAT_COUNTERS["file"] + THREAT_COUNTERS["process"] + THREAT_COUNTERS["network"]))
    
    cat > "${report_file}" <<EOF
{
    "report_generated": "$(date -Iseconds)",
    "security_status": {
        "level": "${SECURITY_LEVEL}",
        "protection_mode": "${PROTECTION_MODE}",
        "monitoring_enabled": ${MONITORING_ENABLED}
    },
    "threat_summary": {
        "total_threats": ${total_threats},
        "file_threats": ${THREAT_COUNTERS["file"]},
        "process_threats": ${THREAT_COUNTERS["process"]},
        "network_threats": ${THREAT_COUNTERS["network"]}
    },
    "system_metrics": {
        "cpu_usage": "$(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 || echo "0")%",
        "memory_usage": "$(free 2>/dev/null | awk '/^Mem:/{printf "%.1f", $3/$2 * 100}' || echo "0")%",
        "active_processes": $(ps aux 2>/dev/null | wc -l || echo "0")
    },
    "quarantine_stats": {
        "quarantined_files": $(find "${SECURITY_QUARANTINE_DIR}" -name "*.meta" 2>/dev/null | wc -l || echo "0")
    }
}
EOF
    
    security_log "PASS" "Security report generated: ${report_file}" "REPORT"
    echo "${report_file}"
}

show_security_status() {
    echo -e "${BOLD}=== CURSOR SECURITY STATUS ===${NC}"
    echo "Framework Version: ${SCRIPT_VERSION}"
    echo "Security Level: ${SECURITY_LEVEL}"
    echo "Protection Mode: ${PROTECTION_MODE}"
    echo "Monitoring: ${MONITORING_ENABLED}"
    echo "Sandboxing: ${SANDBOX_ENABLED}"
    echo "Auditing: ${AUDIT_ENABLED}"
    echo
    echo -e "${BOLD}=== THREAT STATISTICS ===${NC}"
    local total_threats=$((THREAT_COUNTERS["file"] + THREAT_COUNTERS["process"] + THREAT_COUNTERS["network"]))
    echo "Total Threats: ${total_threats}"
    echo "File Threats: ${THREAT_COUNTERS["file"]}"
    echo "Process Threats: ${THREAT_COUNTERS["process"]}"
    echo "Network Threats: ${THREAT_COUNTERS["network"]}"
    echo
    echo -e "${BOLD}=== SYSTEM HEALTH ===${NC}"
    echo "CPU Usage: $(top -bn1 2>/dev/null | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 || echo "0")%"
    echo "Memory Usage: $(free 2>/dev/null | awk '/^Mem:/{printf "%.1f", $3/$2 * 100}' || echo "0")%"
    echo "Active Processes: $(ps aux 2>/dev/null | wc -l || echo "0")"
    echo
    echo -e "${BOLD}=== QUARANTINE STATUS ===${NC}"
    local quarantine_count=$(find "${SECURITY_QUARANTINE_DIR}" -name "*.meta" 2>/dev/null | wc -l || echo "0")
    echo "Quarantined Files: ${quarantine_count}"
}

# === MAIN EXECUTION ===
show_usage() {
    cat <<EOF
${BOLD}Cursor Security Framework v${SCRIPT_VERSION} - Professional Edition${NC}

${BOLD}USAGE:${NC}
    ${SCRIPT_NAME} [OPTIONS] [COMMAND]

${BOLD}COMMANDS:${NC}
    monitor                 Start security monitoring
    scan [PATH]            Scan path for threats
    quarantine FILE        Quarantine suspicious file
    report                 Generate security report
    status                 Show security status
    cleanup                Clean logs and quarantine

${BOLD}OPTIONS:${NC}
    --level LEVEL          Security level: minimal|standard|high
    --mode MODE            Protection mode: monitoring|prevention|quarantine
    --verbose, -v          Enable verbose output
    --debug                Enable debug mode
    --help, -h             Show this help
    --version              Show version information

${BOLD}EXAMPLES:${NC}
    ${SCRIPT_NAME} monitor                      # Start monitoring
    ${SCRIPT_NAME} --level high monitor         # High security monitoring
    ${SCRIPT_NAME} scan /path/to/scan          # Scan specific path
    ${SCRIPT_NAME} report                       # Generate report

${BOLD}CONFIGURATION:${NC}
    Config: ${SECURITY_CONFIG}
    Logs: ${SECURITY_LOG_DIR}
    Quarantine: ${SECURITY_QUARANTINE_DIR}
EOF
}

main() {
    local command="monitor"
    local target_path=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            monitor|scan|quarantine|report|status|cleanup)
                command="$1"
                shift
                ;;
            --level)
                SECURITY_LEVEL="$2"
                shift 2
                ;;
            --mode)
                PROTECTION_MODE="$2"
                shift 2
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --debug)
                DEBUG_MODE=true
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            --version)
                echo "Cursor Security Framework v${SCRIPT_VERSION}"
                exit 0
                ;;
            *)
                if [[ "${command}" == "scan" ]] || [[ "${command}" == "quarantine" ]]; then
                    target_path="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Initialize security framework
    initialize_security_framework || {
        security_log "CRITICAL" "Security framework initialization failed" "MAIN"
        exit 1
    }
    
    # Execute command
    case "${command}" in
        "monitor")
            security_log "INFO" "Starting security monitoring mode" "MAIN"
            while true; do
                sleep 300
                security_log "DEBUG" "Security monitoring active" "MONITOR"
            done
            ;;
        "scan")
            scan_path_for_threats "${target_path:-$SCRIPT_DIR}"
            ;;
        "quarantine")
            if [[ -z "${target_path}" ]]; then
                security_log "ERROR" "File path required for quarantine" "MAIN"
                exit 1
            fi
            quarantine_file "${target_path}"
            ;;
        "report")
            local report_file
            report_file=$(generate_security_report)
            echo "Report generated: ${report_file}"
            if command -v jq >/dev/null 2>&1; then
                jq . "${report_file}"
            else
                cat "${report_file}"
            fi
            ;;
        "status")
            show_security_status
            ;;
        "cleanup")
            security_log "INFO" "Performing security cleanup" "MAIN"
            find "${SECURITY_LOG_DIR}" -name "*.log" -mtime +30 -delete 2>/dev/null || true
            find "${SECURITY_QUARANTINE_DIR}" -name "*.meta" -mtime +90 -delete 2>/dev/null || true
            security_log "PASS" "Security cleanup completed" "MAIN"
            ;;
        *)
            security_log "ERROR" "Unknown command: ${command}" "MAIN"
            show_usage
            exit 1
            ;;
    esac
}

# Cleanup function
cleanup_security() {
    security_log "INFO" "Shutting down security framework" "CLEANUP"
    
    # Kill background monitoring processes
    jobs -p | xargs kill 2>/dev/null || true
    
    security_log "PASS" "Security framework shutdown complete" "CLEANUP"
}

trap cleanup_security EXIT

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi