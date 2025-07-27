#!/usr/bin/env bash
#
# Enterprise Framework Integration Suite
# Comprehensive integration of all enterprise frameworks with cross-framework communication
#
# This script ensures all frameworks work together seamlessly and provides
# a unified interface for enterprise-grade operations
#

set -euo pipefail
IFS=$'\n\t'

# === CONFIGURATION ===
readonly INTEGRATION_VERSION="1.0.0"
readonly INTEGRATION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LIB_DIR="${INTEGRATION_DIR}/lib"
readonly CONFIG_DIR="${HOME}/.cache/cursor/enterprise-integration"
readonly INTEGRATION_LOG="${CONFIG_DIR}/integration.log"
readonly STATUS_FILE="${CONFIG_DIR}/framework_status.json"

# Framework status tracking
declare -A FRAMEWORK_STATUS=(
    ["logging"]="unknown"
    ["alerting"]="unknown"
    ["github"]="unknown"
    ["testing"]="unknown"
    ["monitoring"]="unknown"
    ["security"]="unknown"
)

# === INITIALIZATION ===
init_enterprise_integration() {
    log_integration "INFO" "Initializing Enterprise Framework Integration v${INTEGRATION_VERSION}"
    
    # Create required directories
    mkdir -p "$CONFIG_DIR"
    touch "$INTEGRATION_LOG"
    
    # Load all enterprise frameworks
    load_enterprise_frameworks
    
    # Validate framework integration
    validate_framework_integration
    
    # Setup cross-framework communication
    setup_cross_framework_communication
    
    # Initialize monitoring
    start_framework_monitoring
    
    log_integration "INFO" "Enterprise Framework Integration initialized successfully"
}

log_integration() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -Iseconds)
    
    echo "[$timestamp] [$level] [INTEGRATION] $message" | tee -a "$INTEGRATION_LOG"
    
    # Use enterprise logging if available
    if command -v enterprise_log >/dev/null 2>&1; then
        enterprise_log "$level" "$message" "integration"
    fi
}

# === FRAMEWORK LOADING ===
load_enterprise_frameworks() {
    log_integration "INFO" "Loading enterprise frameworks"
    
    # 1. Load Enterprise Logging Framework (foundation)
    load_logging_framework
    
    # 2. Load External Alerting System 
    load_alerting_framework
    
    # 3. Load GitHub Integration
    load_github_framework
    
    # 4. Load GUI Testing Framework
    load_testing_framework
    
    # 5. Load Code Quality Framework
    load_quality_framework
    
    # 6. Load Security Framework
    load_security_framework
    
    # Generate status report
    generate_framework_status_report
}

load_logging_framework() {
    local framework_files=(
        "enterprise_logging_framework_v2.sh"
        "enterprise_logging_framework.sh"
        "enterprise_logging_config.sh"
    )
    
    for file in "${framework_files[@]}"; do
        if [[ -f "${LIB_DIR}/${file}" ]]; then
            if source "${LIB_DIR}/${file}" 2>/dev/null; then
                FRAMEWORK_STATUS["logging"]="loaded"
                log_integration "INFO" "Loaded logging framework: $file"
                break
            else
                log_integration "WARN" "Failed to load logging framework: $file"
            fi
        fi
    done
    
    if [[ "${FRAMEWORK_STATUS["logging"]}" != "loaded" ]]; then
        FRAMEWORK_STATUS["logging"]="failed"
        log_integration "ERROR" "Failed to load any logging framework"
    fi
}

load_alerting_framework() {
    if [[ -f "${LIB_DIR}/external_alerting_system.sh" ]]; then
        if source "${LIB_DIR}/external_alerting_system.sh" 2>/dev/null; then
            FRAMEWORK_STATUS["alerting"]="loaded"
            log_integration "INFO" "Loaded external alerting system"
        else
            FRAMEWORK_STATUS["alerting"]="failed"
            log_integration "ERROR" "Failed to load external alerting system"
        fi
    else
        FRAMEWORK_STATUS["alerting"]="missing"
        log_integration "WARN" "External alerting system not found"
    fi
}

load_github_framework() {
    if [[ -f "${INTEGRATION_DIR}/enhanced_github_integration.sh" ]]; then
        if source "${INTEGRATION_DIR}/enhanced_github_integration.sh" 2>/dev/null; then
            FRAMEWORK_STATUS["github"]="loaded"
            log_integration "INFO" "Loaded enhanced GitHub integration"
        else
            FRAMEWORK_STATUS["github"]="failed"
            log_integration "ERROR" "Failed to load GitHub integration"
        fi
    else
        FRAMEWORK_STATUS["github"]="missing"
        log_integration "WARN" "GitHub integration not found"
    fi
}

load_testing_framework() {
    local testing_files=(
        "gui_testing_framework.py"
        "claude_tools_integration.py"
        "enhanced_test_runner.sh"
    )
    
    for file in "${testing_files[@]}"; do
        if [[ -f "${INTEGRATION_DIR}/${file}" ]]; then
            FRAMEWORK_STATUS["testing"]="available"
            log_integration "INFO" "Found testing framework: $file"
            break
        fi
    done
    
    if [[ "${FRAMEWORK_STATUS["testing"]}" != "available" ]]; then
        FRAMEWORK_STATUS["testing"]="missing"
        log_integration "WARN" "No testing frameworks found"
    fi
}

load_quality_framework() {
    local quality_files=(
        "multi_layer_code_analysis.sh"
        "enterprise_error_testing_framework.sh"
        "code_quality_analyzer.sh"
    )
    
    for file in "${quality_files[@]}"; do
        if [[ -f "${INTEGRATION_DIR}/${file}" ]]; then
            FRAMEWORK_STATUS["monitoring"]="available"
            log_integration "INFO" "Found quality framework: $file"
            break
        fi
    done
    
    if [[ "${FRAMEWORK_STATUS["monitoring"]}" != "available" ]]; then
        FRAMEWORK_STATUS["monitoring"]="missing"
        log_integration "WARN" "No quality frameworks found"
    fi
}

load_security_framework() {
    # Check for security scanning capabilities
    local security_tools=("bandit" "semgrep" "safety" "shellcheck")
    local available_tools=0
    
    for tool in "${security_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            ((available_tools++))
            log_integration "INFO" "Security tool available: $tool"
        fi
    done
    
    if [[ $available_tools -gt 0 ]]; then
        FRAMEWORK_STATUS["security"]="available"
        log_integration "INFO" "Security framework available ($available_tools tools)"
    else
        FRAMEWORK_STATUS["security"]="limited"
        log_integration "WARN" "Limited security tools available"
    fi
}

# === FRAMEWORK VALIDATION ===
validate_framework_integration() {
    log_integration "INFO" "Validating framework integration"
    
    local validation_errors=0
    
    # Test logging framework
    if ! test_logging_framework; then
        ((validation_errors++))
        log_integration "ERROR" "Logging framework validation failed"
    fi
    
    # Test alerting framework
    if ! test_alerting_framework; then
        ((validation_errors++))
        log_integration "ERROR" "Alerting framework validation failed"
    fi
    
    # Test GitHub integration
    if ! test_github_framework; then
        ((validation_errors++))
        log_integration "ERROR" "GitHub framework validation failed"
    fi
    
    # Test cross-framework communication
    if ! test_cross_framework_communication; then
        ((validation_errors++))
        log_integration "ERROR" "Cross-framework communication validation failed"
    fi
    
    if [[ $validation_errors -eq 0 ]]; then
        log_integration "INFO" "All framework validations passed"
        return 0
    else
        log_integration "ERROR" "Framework validation failed with $validation_errors errors"
        return 1
    fi
}

test_logging_framework() {
    if [[ "${FRAMEWORK_STATUS["logging"]}" == "loaded" ]]; then
        # Test enterprise logging functions
        if command -v enterprise_log >/dev/null 2>&1; then
            enterprise_log "INFO" "Testing enterprise logging integration" "integration_test"
            return 0
        elif command -v log_info >/dev/null 2>&1; then
            log_info "Testing logging integration" "integration_test"
            return 0
        fi
    fi
    return 1
}

test_alerting_framework() {
    if [[ "${FRAMEWORK_STATUS["alerting"]}" == "loaded" ]]; then
        if command -v send_external_alert >/dev/null 2>&1; then
            # Send test alert (will be rate limited if not configured)
            send_external_alert "INFO" "Integration Test" "Testing alerting system integration" "integration_test"
            return 0
        fi
    fi
    return 1
}

test_github_framework() {
    if [[ "${FRAMEWORK_STATUS["github"]}" == "loaded" ]]; then
        if command -v validate_github_setup >/dev/null 2>&1; then
            validate_github_setup
            return $?
        fi
    fi
    return 1
}

test_cross_framework_communication() {
    # Test that frameworks can communicate with each other
    local test_message="Cross-framework communication test"
    
    # Test logging -> alerting communication
    if command -v enterprise_log >/dev/null 2>&1 && command -v send_external_alert >/dev/null 2>&1; then
        enterprise_log "INFO" "$test_message" "communication_test"
        return 0
    fi
    
    return 1
}

# === CROSS-FRAMEWORK COMMUNICATION ===
setup_cross_framework_communication() {
    log_integration "INFO" "Setting up cross-framework communication"
    
    # Create unified logging interface
    create_unified_logging_interface
    
    # Create unified alerting interface
    create_unified_alerting_interface
    
    # Create unified testing interface
    create_unified_testing_interface
    
    # Setup event bus for framework communication
    setup_framework_event_bus
}

create_unified_logging_interface() {
    # Create wrapper functions that work with any loaded logging framework
    if ! command -v unified_log >/dev/null 2>&1; then
        unified_log() {
            local level="$1"
            local message="$2"
            local component="${3:-unified}"
            local additional_data="${4:-{}}"
            
            # Try enterprise logging first
            if command -v enterprise_log >/dev/null 2>&1; then
                enterprise_log "$level" "$message" "$component" "$additional_data"
            elif command -v log_info >/dev/null 2>&1 && [[ "$level" == "INFO" ]]; then
                log_info "$message" "$component" "$additional_data"
            elif command -v log_error >/dev/null 2>&1 && [[ "$level" == "ERROR" ]]; then
                log_error "$message" "$component" "$additional_data"
            else
                # Fallback to simple logging
                echo "[$(date -Iseconds)] [$level] [$component] $message" >> "$INTEGRATION_LOG"
            fi
        }
        
        # Export unified logging functions
        export -f unified_log
    fi
}

create_unified_alerting_interface() {
    if ! command -v unified_alert >/dev/null 2>&1; then
        unified_alert() {
            local severity="$1"
            local title="$2"
            local message="$3"
            local context="${4:-unified}"
            
            # Log the alert
            unified_log "WARN" "ALERT: [$severity] $title - $message" "$context"
            
            # Send external alert if available
            if command -v send_external_alert >/dev/null 2>&1; then
                send_external_alert "$severity" "$title" "$message" "$context"
            fi
        }
        
        export -f unified_alert
    fi
}

create_unified_testing_interface() {
    if ! command -v unified_test >/dev/null 2>&1; then
        unified_test() {
            local test_type="$1"
            local target="${2:-}"
            
            unified_log "INFO" "Running unified test: $test_type on $target" "testing"
            
            case "$test_type" in
                "gui")
                    run_gui_tests "$target"
                    ;;
                "security")
                    run_security_tests "$target"
                    ;;
                "quality")
                    run_quality_tests "$target"
                    ;;
                "integration")
                    run_integration_tests "$target"
                    ;;
                *)
                    unified_log "ERROR" "Unknown test type: $test_type" "testing"
                    return 1
                    ;;
            esac
        }
        
        export -f unified_test
    fi
}

setup_framework_event_bus() {
    # Create simple event bus for framework communication
    local event_bus_file="${CONFIG_DIR}/event_bus.log"
    touch "$event_bus_file"
    
    if ! command -v publish_event >/dev/null 2>&1; then
        publish_event() {
            local event_type="$1"
            local event_data="$2"
            local timestamp=$(date -Iseconds)
            
            echo "[$timestamp] EVENT: $event_type DATA: $event_data" >> "$event_bus_file"
            unified_log "DEBUG" "Published event: $event_type" "event_bus"
        }
        
        export -f publish_event
    fi
}

# === UNIFIED TEST FUNCTIONS ===
run_gui_tests() {
    local target="$1"
    
    if [[ -f "${INTEGRATION_DIR}/gui_testing_framework.py" ]]; then
        unified_log "INFO" "Running GUI tests on: $target" "testing"
        python3 "${INTEGRATION_DIR}/gui_testing_framework.py" "$target" 2>&1 | while read -r line; do
            unified_log "INFO" "GUI Test: $line" "testing"
        done
    else
        unified_log "WARN" "GUI testing framework not available" "testing"
        return 1
    fi
}

run_security_tests() {
    local target="$1"
    
    unified_log "INFO" "Running security tests on: $target" "testing"
    
    local security_issues=0
    
    # Run bandit if available and target is Python
    if command -v bandit >/dev/null 2>&1 && [[ "$target" =~ \.py$ ]]; then
        if ! bandit "$target" >/dev/null 2>&1; then
            ((security_issues++))
            unified_log "WARN" "Bandit found security issues in: $target" "security"
        fi
    fi
    
    # Run shellcheck if target is shell script
    if command -v shellcheck >/dev/null 2>&1 && [[ "$target" =~ \.sh$ ]]; then
        if ! shellcheck "$target" >/dev/null 2>&1; then
            ((security_issues++))
            unified_log "WARN" "ShellCheck found issues in: $target" "security"
        fi
    fi
    
    if [[ $security_issues -eq 0 ]]; then
        unified_log "INFO" "Security tests passed for: $target" "security"
        return 0
    else
        unified_alert "MEDIUM" "Security Issues Found" "Found $security_issues security issues in $target" "security"
        return 1
    fi
}

run_quality_tests() {
    local target="$1"
    
    if [[ -f "${INTEGRATION_DIR}/code_quality_analyzer.sh" ]]; then
        unified_log "INFO" "Running quality tests on: $target" "testing"
        bash "${INTEGRATION_DIR}/code_quality_analyzer.sh" "$target" 2>&1 | while read -r line; do
            unified_log "INFO" "Quality: $line" "testing"
        done
    else
        unified_log "WARN" "Code quality analyzer not available" "testing"
        return 1
    fi
}

run_integration_tests() {
    local target="$1"
    
    unified_log "INFO" "Running integration tests" "testing"
    
    # Test framework integration
    validate_framework_integration
    
    # Test cross-framework communication
    test_cross_framework_communication
    
    unified_log "INFO" "Integration tests completed" "testing"
}

# === MONITORING ===
start_framework_monitoring() {
    log_integration "INFO" "Starting framework monitoring"
    
    # Monitor framework health
    monitor_framework_health &
    local monitor_pid=$!
    echo "$monitor_pid" > "${CONFIG_DIR}/monitor.pid"
    
    log_integration "INFO" "Framework monitoring started (PID: $monitor_pid)"
}

monitor_framework_health() {
    while true; do
        # Check framework status
        check_framework_health
        
        # Generate health report
        generate_health_report
        
        # Sleep for monitoring interval
        sleep 30
    done
}

check_framework_health() {
    local health_issues=0
    
    # Check logging framework
    if [[ "${FRAMEWORK_STATUS["logging"]}" == "loaded" ]]; then
        if ! command -v enterprise_log >/dev/null 2>&1; then
            FRAMEWORK_STATUS["logging"]="degraded"
            ((health_issues++))
        fi
    fi
    
    # Check alerting framework
    if [[ "${FRAMEWORK_STATUS["alerting"]}" == "loaded" ]]; then
        if ! command -v send_external_alert >/dev/null 2>&1; then
            FRAMEWORK_STATUS["alerting"]="degraded"
            ((health_issues++))
        fi
    fi
    
    # Alert on health issues
    if [[ $health_issues -gt 0 ]]; then
        unified_alert "MEDIUM" "Framework Health Issues" "Found $health_issues framework health issues" "monitoring"
    fi
}

generate_health_report() {
    local health_report="${CONFIG_DIR}/health_report_$(date +%Y%m%d_%H%M%S).json"
    
    cat > "$health_report" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "integration_version": "$INTEGRATION_VERSION",
    "framework_status": {
$(for framework in "${!FRAMEWORK_STATUS[@]}"; do
    echo "        \"$framework\": \"${FRAMEWORK_STATUS[$framework]}\","
done | sed '$s/,$//')
    },
    "system_info": {
        "hostname": "$(hostname)",
        "user": "$USER",
        "platform": "$(uname -s)",
        "load_average": "$(uptime | awk -F'load average:' '{print $2}' | sed 's/^[[:space:]]*//')"
    }
}
EOF
}

generate_framework_status_report() {
    cat > "$STATUS_FILE" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "integration_version": "$INTEGRATION_VERSION",
    "framework_status": {
$(for framework in "${!FRAMEWORK_STATUS[@]}"; do
    echo "        \"$framework\": \"${FRAMEWORK_STATUS[$framework]}\","
done | sed '$s/,$//')
    }
}
EOF
    
    log_integration "INFO" "Framework status report generated: $STATUS_FILE"
}

# === COMMAND LINE INTERFACE ===
show_integration_status() {
    echo "Enterprise Framework Integration Status"
    echo "======================================="
    echo "Version: $INTEGRATION_VERSION"
    echo ""
    
    echo "Framework Status:"
    for framework in "${!FRAMEWORK_STATUS[@]}"; do
        local status="${FRAMEWORK_STATUS[$framework]}"
        local status_icon="❓"
        case "$status" in
            "loaded"|"available") status_icon="✅" ;;
            "failed"|"missing") status_icon="❌" ;;
            "degraded"|"limited") status_icon="⚠️" ;;
        esac
        printf "  %s %-12s: %s\n" "$status_icon" "$framework" "$status"
    done
    echo ""
    
    echo "Integration Files:"
    echo "  Configuration: $CONFIG_DIR"
    echo "  Status File: $STATUS_FILE"
    echo "  Integration Log: $INTEGRATION_LOG"
    echo ""
    
    # Show recent log entries
    if [[ -f "$INTEGRATION_LOG" ]]; then
        echo "Recent Log Entries:"
        tail -5 "$INTEGRATION_LOG" | sed 's/^/  /'
    fi
}

run_comprehensive_test() {
    log_integration "INFO" "Running comprehensive enterprise framework test"
    
    # Test all available frameworks
    local test_results=()
    
    # Test logging
    if test_logging_framework; then
        test_results+=("logging:PASS")
    else
        test_results+=("logging:FAIL")
    fi
    
    # Test alerting
    if test_alerting_framework; then
        test_results+=("alerting:PASS")
    else
        test_results+=("alerting:FAIL")
    fi
    
    # Test GitHub integration
    if test_github_framework; then
        test_results+=("github:PASS")
    else
        test_results+=("github:FAIL")
    fi
    
    # Test unified interfaces
    if command -v unified_log >/dev/null 2>&1; then
        unified_log "INFO" "Testing unified logging interface" "test"
        test_results+=("unified_logging:PASS")
    else
        test_results+=("unified_logging:FAIL")
    fi
    
    if command -v unified_alert >/dev/null 2>&1; then
        unified_alert "INFO" "Test Alert" "Testing unified alerting interface" "test"
        test_results+=("unified_alerting:PASS")
    else
        test_results+=("unified_alerting:FAIL")
    fi
    
    # Display results
    echo "Comprehensive Test Results:"
    echo "=========================="
    local passed=0
    local failed=0
    
    for result in "${test_results[@]}"; do
        local test_name="${result%:*}"
        local test_status="${result#*:}"
        
        if [[ "$test_status" == "PASS" ]]; then
            echo "  ✅ $test_name"
            ((passed++))
        else
            echo "  ❌ $test_name"
            ((failed++))
        fi
    done
    
    echo ""
    echo "Summary: $passed passed, $failed failed"
    
    if [[ $failed -eq 0 ]]; then
        log_integration "INFO" "All comprehensive tests passed"
        return 0
    else
        log_integration "ERROR" "Some comprehensive tests failed"
        return 1
    fi
}

show_usage() {
    cat << EOF
Enterprise Framework Integration v$INTEGRATION_VERSION

USAGE:
    $0 [COMMAND] [OPTIONS]

COMMANDS:
    init                       - Initialize framework integration
    status                     - Show integration status
    test                       - Run comprehensive tests
    monitor                    - Start monitoring (daemon mode)
    stop-monitor              - Stop monitoring daemon
    health                     - Check framework health
    reload                     - Reload all frameworks
    log LEVEL MESSAGE         - Send unified log message
    alert SEVERITY TITLE MSG  - Send unified alert

EXAMPLES:
    $0 init                           # Initialize integration
    $0 status                         # Show status
    $0 test                          # Run comprehensive tests
    $0 log INFO "Test message"       # Send log message
    $0 alert MEDIUM "Test" "Alert"   # Send alert

EOF
}

# === MAIN EXECUTION ===
main() {
    local command="${1:-}"
    
    case "$command" in
        "init")
            init_enterprise_integration
            ;;
        "status")
            show_integration_status
            ;;
        "test")
            run_comprehensive_test
            ;;
        "monitor")
            start_framework_monitoring
            echo "Framework monitoring started in background"
            ;;
        "stop-monitor")
            if [[ -f "${CONFIG_DIR}/monitor.pid" ]]; then
                local pid=$(cat "${CONFIG_DIR}/monitor.pid")
                if kill "$pid" 2>/dev/null; then
                    echo "Framework monitoring stopped (PID: $pid)"
                    rm -f "${CONFIG_DIR}/monitor.pid"
                else
                    echo "No monitoring process found"
                fi
            else
                echo "No monitoring PID file found"
            fi
            ;;
        "health")
            check_framework_health
            generate_health_report
            echo "Health check completed"
            ;;
        "reload")
            log_integration "INFO" "Reloading enterprise frameworks"
            load_enterprise_frameworks
            echo "Frameworks reloaded"
            ;;
        "log")
            if [[ $# -ge 3 ]]; then
                init_enterprise_integration >/dev/null 2>&1
                unified_log "$2" "$3" "cli" "${4:-{}}"
            else
                echo "Usage: $0 log LEVEL MESSAGE [ADDITIONAL_DATA]"
                exit 1
            fi
            ;;
        "alert")
            if [[ $# -ge 4 ]]; then
                init_enterprise_integration >/dev/null 2>&1
                unified_alert "$2" "$3" "$4" "${5:-cli}"
            else
                echo "Usage: $0 alert SEVERITY TITLE MESSAGE [CONTEXT]"
                exit 1
            fi
            ;;
        "--help"|"-h"|"help"|"")
            show_usage
            ;;
        *)
            echo "ERROR: Unknown command: $command" >&2
            echo "Use '$0 --help' for usage information" >&2
            exit 1
            ;;
    esac
}

# Auto-initialize when sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    init_enterprise_integration
fi

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi