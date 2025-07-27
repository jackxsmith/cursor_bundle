#!/usr/bin/env bash
#
# Professional External Alerting System
# Enterprise-grade integration with Slack, PagerDuty, email, and webhooks
# 
# This implements the TODO from enterprise_logging_framework.sh
#

set -euo pipefail
IFS=$'\n\t'

# === CONFIGURATION ===
readonly ALERTING_VERSION="1.0.0"
readonly ALERTING_CONFIG_DIR="${HOME}/.cache/cursor/alerting"
readonly ALERTING_LOG="${ALERTING_CONFIG_DIR}/alerting.log"
readonly ALERTING_QUEUE="${ALERTING_CONFIG_DIR}/alert_queue"

# Alert severity levels
declare -A ALERT_SEVERITIES=(
    ["CRITICAL"]=1
    ["HIGH"]=2  
    ["MEDIUM"]=3
    ["LOW"]=4
    ["INFO"]=5
)

# Configuration with environment variable fallbacks
declare -g SLACK_WEBHOOK_URL="${SLACK_WEBHOOK_URL:-}"
declare -g PAGERDUTY_INTEGRATION_KEY="${PAGERDUTY_INTEGRATION_KEY:-}"
declare -g EMAIL_SMTP_SERVER="${EMAIL_SMTP_SERVER:-localhost}"
declare -g EMAIL_SMTP_PORT="${EMAIL_SMTP_PORT:-587}"
declare -g EMAIL_FROM="${EMAIL_FROM:-noreply@cursor-bundle.local}"
declare -g EMAIL_TO="${EMAIL_TO:-}"
declare -g CUSTOM_WEBHOOK_URL="${CUSTOM_WEBHOOK_URL:-}"
declare -g ALERT_RATE_LIMIT="${ALERT_RATE_LIMIT:-5}"  # alerts per minute
declare -g ALERT_COOLDOWN="${ALERT_COOLDOWN:-300}"    # seconds

# Rate limiting tracking
declare -A ALERT_COUNTERS=()
declare -A LAST_ALERT_TIME=()

# === INITIALIZATION ===
init_alerting_system() {
    mkdir -p "$ALERTING_CONFIG_DIR"
    touch "$ALERTING_LOG" "$ALERTING_QUEUE"
    
    log_alert "INFO" "External alerting system initialized v$ALERTING_VERSION" "alerting_system"
    
    # Start background alert processor if not already running
    start_alert_processor
}

log_alert() {
    local level="$1"
    local message="$2"
    local component="$3"
    local timestamp=$(date -Iseconds)
    
    echo "[$timestamp] [$level] [$component] $message" >> "$ALERTING_LOG"
}

# === SLACK INTEGRATION ===
send_slack_alert() {
    local severity="$1"
    local title="$2"
    local message="$3"
    local context="$4"
    
    if [[ -z "$SLACK_WEBHOOK_URL" ]]; then
        log_alert "DEBUG" "Slack webhook URL not configured, skipping Slack alert" "slack"
        return 1
    fi
    
    # Rate limiting check
    if ! check_rate_limit "slack" "$severity"; then
        log_alert "WARN" "Slack alert rate limited" "slack"
        return 1
    fi
    
    # Choose color based on severity
    local color="good"
    case "$severity" in
        "CRITICAL") color="danger" ;;
        "HIGH") color="warning" ;;
        "MEDIUM") color="warning" ;;
        "LOW") color="good" ;;
        "INFO") color="good" ;;
    esac
    
    # Construct Slack payload
    local payload=$(cat << EOF
{
    "username": "Cursor Bundle Monitor",
    "icon_emoji": ":warning:",
    "attachments": [
        {
            "color": "$color",
            "title": "[$severity] $title",
            "text": "$message",
            "fields": [
                {
                    "title": "Severity",
                    "value": "$severity",
                    "short": true
                },
                {
                    "title": "Context",
                    "value": "$context",
                    "short": true
                },
                {
                    "title": "Timestamp",
                    "value": "$(date -Iseconds)",
                    "short": true
                },
                {
                    "title": "Host",
                    "value": "$(hostname)",
                    "short": true
                }
            ],
            "footer": "Cursor Bundle Monitoring",
            "ts": $(date +%s)
        }
    ]
}
EOF
)
    
    # Send to Slack
    if curl -X POST \
        -H 'Content-type: application/json' \
        --data "$payload" \
        --max-time 30 \
        --retry 3 \
        --retry-delay 2 \
        "$SLACK_WEBHOOK_URL" >/dev/null 2>&1; then
        
        log_alert "INFO" "Slack alert sent successfully: $title" "slack"
        update_rate_limit "slack"
        return 0
    else
        log_alert "ERROR" "Failed to send Slack alert: $title" "slack"
        return 1
    fi
}

# === PAGERDUTY INTEGRATION ===
send_pagerduty_alert() {
    local severity="$1"
    local title="$2"
    local message="$3"
    local context="$4"
    
    if [[ -z "$PAGERDUTY_INTEGRATION_KEY" ]]; then
        log_alert "DEBUG" "PagerDuty integration key not configured, skipping PagerDuty alert" "pagerduty"
        return 1
    fi
    
    # Only send HIGH and CRITICAL alerts to PagerDuty
    if [[ "$severity" != "CRITICAL" && "$severity" != "HIGH" ]]; then
        log_alert "DEBUG" "Severity $severity below PagerDuty threshold" "pagerduty"
        return 0
    fi
    
    # Rate limiting check
    if ! check_rate_limit "pagerduty" "$severity"; then
        log_alert "WARN" "PagerDuty alert rate limited" "pagerduty"
        return 1
    fi
    
    # Generate unique dedup key
    local dedup_key="cursor-bundle-$(echo "$title" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')"
    
    # PagerDuty payload
    local payload=$(cat << EOF
{
    "routing_key": "$PAGERDUTY_INTEGRATION_KEY",
    "event_action": "trigger",
    "dedup_key": "$dedup_key",
    "payload": {
        "summary": "[$severity] $title",
        "source": "$(hostname)",
        "severity": "$(echo "$severity" | tr '[:upper:]' '[:lower:]')",
        "component": "cursor-bundle",
        "group": "$context",
        "class": "application",
        "custom_details": {
            "message": "$message",
            "context": "$context",
            "timestamp": "$(date -Iseconds)",
            "host": "$(hostname)",
            "user": "${USER:-unknown}",
            "process_id": "$$"
        }
    }
}
EOF
)
    
    # Send to PagerDuty
    if curl -X POST \
        -H 'Content-Type: application/json' \
        --data "$payload" \
        --max-time 30 \
        --retry 3 \
        --retry-delay 2 \
        "https://events.pagerduty.com/v2/enqueue" >/dev/null 2>&1; then
        
        log_alert "INFO" "PagerDuty alert sent successfully: $title" "pagerduty"
        update_rate_limit "pagerduty"
        return 0
    else
        log_alert "ERROR" "Failed to send PagerDuty alert: $title" "pagerduty"
        return 1
    fi
}

# === EMAIL INTEGRATION ===
send_email_alert() {
    local severity="$1"
    local title="$2"
    local message="$3"
    local context="$4"
    
    if [[ -z "$EMAIL_TO" ]]; then
        log_alert "DEBUG" "Email recipient not configured, skipping email alert" "email"
        return 1
    fi
    
    # Rate limiting check
    if ! check_rate_limit "email" "$severity"; then
        log_alert "WARN" "Email alert rate limited" "email"
        return 1
    fi
    
    # Create email content
    local email_subject="[$severity] Cursor Bundle Alert: $title"
    local email_body=$(cat << EOF
Cursor Bundle Monitoring Alert

Severity: $severity
Title: $title
Context: $context
Timestamp: $(date -Iseconds)
Host: $(hostname)
User: ${USER:-unknown}
Process ID: $$

Details:
$message

---
This is an automated alert from Cursor Bundle Monitoring System.
EOF
)
    
    # Try different email sending methods
    if command -v mail >/dev/null 2>&1; then
        # Use system mail command
        if echo "$email_body" | mail -s "$email_subject" "$EMAIL_TO" 2>/dev/null; then
            log_alert "INFO" "Email alert sent successfully via mail: $title" "email"
            update_rate_limit "email"
            return 0
        fi
    fi
    
    if command -v sendmail >/dev/null 2>&1; then
        # Use sendmail
        local email_message=$(cat << EOF
From: $EMAIL_FROM
To: $EMAIL_TO
Subject: $email_subject

$email_body
EOF
)
        
        if echo "$email_message" | sendmail "$EMAIL_TO" 2>/dev/null; then
            log_alert "INFO" "Email alert sent successfully via sendmail: $title" "email"
            update_rate_limit "email"
            return 0
        fi
    fi
    
    # Try Python SMTP as fallback
    if command -v python3 >/dev/null 2>&1; then
        local python_script=$(cat << 'EOF'
import smtplib
import sys
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

smtp_server = sys.argv[1]
smtp_port = int(sys.argv[2])
from_email = sys.argv[3]
to_email = sys.argv[4]
subject = sys.argv[5]
body = sys.argv[6]

try:
    msg = MIMEMultipart()
    msg['From'] = from_email
    msg['To'] = to_email
    msg['Subject'] = subject
    msg.attach(MIMEText(body, 'plain'))
    
    server = smtplib.SMTP(smtp_server, smtp_port)
    server.starttls()
    server.send_message(msg)
    server.quit()
    print("SUCCESS")
except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(1)
EOF
)
        
        if python3 -c "$python_script" "$EMAIL_SMTP_SERVER" "$EMAIL_SMTP_PORT" "$EMAIL_FROM" "$EMAIL_TO" "$email_subject" "$email_body" 2>/dev/null | grep -q "SUCCESS"; then
            log_alert "INFO" "Email alert sent successfully via Python SMTP: $title" "email"
            update_rate_limit "email"
            return 0
        fi
    fi
    
    log_alert "ERROR" "Failed to send email alert: $title" "email"
    return 1
}

# === WEBHOOK INTEGRATION ===
send_webhook_alert() {
    local severity="$1"
    local title="$2"
    local message="$3"
    local context="$4"
    
    if [[ -z "$CUSTOM_WEBHOOK_URL" ]]; then
        log_alert "DEBUG" "Custom webhook URL not configured, skipping webhook alert" "webhook"
        return 1
    fi
    
    # Rate limiting check
    if ! check_rate_limit "webhook" "$severity"; then
        log_alert "WARN" "Webhook alert rate limited" "webhook"
        return 1
    fi
    
    # Generic webhook payload
    local payload=$(cat << EOF
{
    "alert_type": "cursor_bundle_monitoring",
    "severity": "$severity",
    "title": "$title",
    "message": "$message",
    "context": "$context",
    "timestamp": "$(date -Iseconds)",
    "host": "$(hostname)",
    "user": "${USER:-unknown}",
    "process_id": "$$",
    "version": "$ALERTING_VERSION"
}
EOF
)
    
    # Send webhook
    if curl -X POST \
        -H 'Content-Type: application/json' \
        --data "$payload" \
        --max-time 30 \
        --retry 3 \
        --retry-delay 2 \
        "$CUSTOM_WEBHOOK_URL" >/dev/null 2>&1; then
        
        log_alert "INFO" "Webhook alert sent successfully: $title" "webhook"
        update_rate_limit "webhook"
        return 0
    else
        log_alert "ERROR" "Failed to send webhook alert: $title" "webhook"
        return 1
    fi
}

# === RATE LIMITING ===
check_rate_limit() {
    local service="$1"
    local severity="$2"
    local current_time=$(date +%s)
    local rate_key="${service}_${severity}"
    
    # Check cooldown period for this specific alert type
    local last_time="${LAST_ALERT_TIME[$rate_key]:-0}"
    if [[ $((current_time - last_time)) -lt $ALERT_COOLDOWN ]]; then
        return 1
    fi
    
    # Check rate limiting (alerts per minute)
    local count_key="${service}_count"
    local current_count="${ALERT_COUNTERS[$count_key]:-0}"
    local window_start="${ALERT_COUNTERS[${count_key}_window]:-$current_time}"
    
    # Reset counter if window expired (1 minute)
    if [[ $((current_time - window_start)) -gt 60 ]]; then
        ALERT_COUNTERS["$count_key"]=0
        ALERT_COUNTERS["${count_key}_window"]=$current_time
        current_count=0
    fi
    
    # Check if rate limit exceeded
    if [[ $current_count -ge $ALERT_RATE_LIMIT ]]; then
        return 1
    fi
    
    return 0
}

update_rate_limit() {
    local service="$1"
    local current_time=$(date +%s)
    local count_key="${service}_count"
    
    ALERT_COUNTERS["$count_key"]=$((${ALERT_COUNTERS[$count_key]:-0} + 1))
}

# === MAIN ALERT DISPATCHER ===
send_external_alert() {
    local severity="$1"
    local title="$2"
    local message="$3"
    local context="${4:-general}"
    
    # Validate severity
    if [[ -z "${ALERT_SEVERITIES[$severity]:-}" ]]; then
        log_alert "ERROR" "Invalid alert severity: $severity" "dispatcher"
        return 1
    fi
    
    log_alert "INFO" "Dispatching $severity alert: $title" "dispatcher"
    
    # Queue alert for background processing
    local alert_data=$(cat << EOF
{
    "severity": "$severity",
    "title": "$title", 
    "message": "$message",
    "context": "$context",
    "timestamp": "$(date -Iseconds)",
    "host": "$(hostname)",
    "process_id": "$$"
}
EOF
)
    
    echo "$alert_data" >> "$ALERTING_QUEUE"
    
    # For critical alerts, send immediately
    if [[ "$severity" == "CRITICAL" ]]; then
        process_alert_immediately "$alert_data"
    fi
    
    return 0
}

process_alert_immediately() {
    local alert_data="$1"
    
    # Parse alert data
    local severity title message context
    if command -v jq >/dev/null 2>&1; then
        severity=$(echo "$alert_data" | jq -r '.severity')
        title=$(echo "$alert_data" | jq -r '.title')
        message=$(echo "$alert_data" | jq -r '.message')
        context=$(echo "$alert_data" | jq -r '.context')
    else
        # Fallback parsing without jq
        severity=$(echo "$alert_data" | grep -o '"severity": *"[^"]*"' | cut -d'"' -f4)
        title=$(echo "$alert_data" | grep -o '"title": *"[^"]*"' | cut -d'"' -f4)
        message=$(echo "$alert_data" | grep -o '"message": *"[^"]*"' | cut -d'"' -f4)
        context=$(echo "$alert_data" | grep -o '"context": *"[^"]*"' | cut -d'"' -f4)
    fi
    
    # Send to all configured channels
    local success_count=0
    
    if send_slack_alert "$severity" "$title" "$message" "$context"; then
        ((success_count++))
    fi
    
    if send_pagerduty_alert "$severity" "$title" "$message" "$context"; then
        ((success_count++))
    fi
    
    if send_email_alert "$severity" "$title" "$message" "$context"; then
        ((success_count++))
    fi
    
    if send_webhook_alert "$severity" "$title" "$message" "$context"; then
        ((success_count++))
    fi
    
    if [[ $success_count -eq 0 ]]; then
        log_alert "WARN" "No external alerts were sent successfully" "dispatcher"
    else
        log_alert "INFO" "Alert sent to $success_count external systems" "dispatcher"
    fi
}

# === BACKGROUND ALERT PROCESSOR ===
start_alert_processor() {
    local pid_file="$ALERTING_CONFIG_DIR/processor.pid"
    
    # Check if processor is already running
    if [[ -f "$pid_file" ]]; then
        local existing_pid=$(cat "$pid_file")
        if kill -0 "$existing_pid" 2>/dev/null; then
            log_alert "DEBUG" "Alert processor already running (PID: $existing_pid)" "processor"
            return 0
        else
            rm -f "$pid_file"
        fi
    fi
    
    # Start background processor
    nohup bash -c "
        echo $$ > '$pid_file'
        while true; do
            if [[ -s '$ALERTING_QUEUE' ]]; then
                # Process queued alerts
                while IFS= read -r alert_data; do
                    if [[ -n \"\$alert_data\" ]]; then
                        source '$0'  # Source this script
                        process_alert_immediately \"\$alert_data\"
                    fi
                done < '$ALERTING_QUEUE'
                
                # Clear processed alerts
                > '$ALERTING_QUEUE'
            fi
            
            sleep 30  # Check every 30 seconds
        done
    " </dev/null >/dev/null 2>&1 &
    
    log_alert "INFO" "Alert processor started in background" "processor"
}

stop_alert_processor() {
    local pid_file="$ALERTING_CONFIG_DIR/processor.pid"
    
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill "$pid" 2>/dev/null; then
            log_alert "INFO" "Alert processor stopped (PID: $pid)" "processor"
            rm -f "$pid_file"
        fi
    fi
}

# === TESTING FUNCTIONS ===
test_alerting_system() {
    log_alert "INFO" "Testing external alerting system" "test"
    
    echo "Testing external alerting system..."
    echo "Configured services:"
    [[ -n "$SLACK_WEBHOOK_URL" ]] && echo "  ✓ Slack webhook configured"
    [[ -n "$PAGERDUTY_INTEGRATION_KEY" ]] && echo "  ✓ PagerDuty integration configured"
    [[ -n "$EMAIL_TO" ]] && echo "  ✓ Email alerts configured"
    [[ -n "$CUSTOM_WEBHOOK_URL" ]] && echo "  ✓ Custom webhook configured"
    
    # Send test alerts
    echo "Sending test alerts..."
    send_external_alert "INFO" "Test Alert" "This is a test alert from the Cursor Bundle monitoring system" "testing"
    
    echo "Test completed. Check configured channels for test alerts."
}

# === CONFIGURATION HELPER ===
show_alerting_config() {
    cat << EOF
External Alerting System Configuration

Environment Variables:
  SLACK_WEBHOOK_URL          - Slack webhook URL for alerts
  PAGERDUTY_INTEGRATION_KEY  - PagerDuty integration key
  EMAIL_SMTP_SERVER          - SMTP server for email alerts (default: localhost)
  EMAIL_SMTP_PORT            - SMTP port (default: 587)
  EMAIL_FROM                 - From email address
  EMAIL_TO                   - To email address(es)
  CUSTOM_WEBHOOK_URL         - Custom webhook URL
  ALERT_RATE_LIMIT           - Alerts per minute (default: 5)
  ALERT_COOLDOWN             - Cooldown between similar alerts in seconds (default: 300)

Usage Examples:
  source external_alerting_system.sh
  send_external_alert "CRITICAL" "System Down" "Application has stopped responding" "application"
  send_external_alert "HIGH" "High Memory Usage" "Memory usage above 90%" "performance"
  test_alerting_system

Log Files:
  $ALERTING_LOG
  $ALERTING_QUEUE
EOF
}

# === INITIALIZATION ON SOURCE ===
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    init_alerting_system
fi

# === COMMAND LINE INTERFACE ===
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        "test")
            test_alerting_system
            ;;
        "config")
            show_alerting_config
            ;;
        "stop")
            stop_alert_processor
            ;;
        "--help"|"-h"|"")
            echo "External Alerting System v$ALERTING_VERSION"
            echo "Usage: $0 [test|config|stop|--help]"
            echo "  test   - Send test alerts to all configured channels"
            echo "  config - Show configuration help"
            echo "  stop   - Stop background alert processor"
            ;;
        *)
            echo "Unknown command: $1"
            echo "Use '$0 --help' for usage information"
            exit 1
            ;;
    esac
fi