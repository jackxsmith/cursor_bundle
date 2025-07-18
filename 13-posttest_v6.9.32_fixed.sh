#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# posttest_v6.9.32.sh
# Final post-test verification after installation and updates
# =============================================================================

log() { echo "[PostTest] $*"; }

check_cursor_version() {
if ! command -v cursor &>/dev/null; then
log "Cursor binary not found in PATH"
return 1
fi
local ver=$(cursor --version 2>/dev/null || echo "unknown")
log "Cursor version: $ver"
}

verify_ui_launch() {
if pgrep -f 'cursor_web_ui.py' &>/dev/null; then
log "Web UI appears to be running"
else
log "Web UI not detected"
fi
}

check_logs() {
local log_file="/var/log/cursor.log"
if [[ -f "$log_file" ]]; then
log "Log file exists: $log_file"
tail -n 5 "$log_file"
else
log "No log file found"
fi
}

# Run all post-test checks
log "Running post-install test verifications..."
check_cursor_version
verify_ui_launch
check_logs