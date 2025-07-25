#!/bin/bash
# Notification functions for cursor_bundle release automation

# Slack notification function
notify_slack() {
    local message="$1"
    local channel="${2:-#releases}"
    local webhook_url="${SLACK_WEBHOOK_URL:-}"
    
    if [ -z "$webhook_url" ]; then
        echo "SLACK_WEBHOOK_URL not configured" >&2
        return 1
    fi
    
    local payload='{
        "channel": "'$channel'",
        "username": "Release Bot",
        "text": "'$message'",
        "icon_emoji": ":rocket:"
    }'
    
    curl -s -X POST -H "Content-Type: application/json" \
         -d "$payload" \
         "$webhook_url" >/dev/null
}

# Multi-channel notification function
notify_all() {
    local message="$1"
    local title="${2:-Release Notification}"
    
    local success_count=0
    local total_count=0
    
    # Try Slack
    if [ -n "$SLACK_WEBHOOK_URL" ]; then
        ((total_count++))
        if notify_slack "$message"; then
            ((success_count++))
        fi
    fi
    
    echo "Notifications sent: $success_count/$total_count" >&2
    
    if [ $success_count -gt 0 ]; then
        return 0
    else
        return 1
    fi
}