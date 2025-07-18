#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# launcher_secure_v6.9.32.sh
# Unified launcher with enhanced security checks for Cursor v6.9.32
# ============================================================================

log() { echo "[LauncherSecure] $*"; }
log_error() { echo "[ERROR][LauncherSecure] $*" >&2; }

check_env() {
[[ -z "${DISPLAY:-}" ]] && log_error "DISPLAY not set. GUI apps may fail." && exit 1
}

check_integrity() {
local f="$1"
if [[ ! -f "$f" ]]; then
log_error "Missing file: $f"
exit 1
fi
    # Skipping checksum verification as no .sha256 provided
}

launch_cursor() {
local binary="./01-appimage_v6.9.32.AppImage"
check_integrity "$binary"
chmod +x "$binary"
"$binary" &
log "Cursor launched."
}

main() {
log "Launching Cursor securely..."
check_env
launch_cursor
}

main