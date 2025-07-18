#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ===========================================================================
# preinstall_v6.9.32.sh
# Pre-installation script for Cursor v6.9.32
# ===========================================================================

log() { echo "[PreInstall] $*"; }

log "Running pre-install checks..."

if [[ ! -f /etc/os-release ]]; then
log "OS release file not found. Assuming unknown Linux distribution."
else
# shellcheck source=/dev/null
. /etc/os-release
log "Detected distribution: $NAME $VERSION"
fi

if ! command -v curl &>/dev/null; then
log "curl is missing. Installing..."
sudo apt update && sudo apt install -y curl
else
log "curl is present."
fi

log "Pre-install checks completed."