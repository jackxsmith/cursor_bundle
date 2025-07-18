#!/usr/bin/env bash
INSTALL_DIR="/opt/cursor"
# 14-install_v6.9.34.sh — Cursor v6.9.34 Installer (fixed for Ubuntu 25.04)
set -euo pipefail
IFS=$'\n\t'

### Configuration
VERSION="6.9.34"
BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPIMAGE="$BUNDLE_DIR/01-appimage_v6.9.34.AppImage"
PREINSTALL_SCRIPTS=("$BUNDLE_DIR"/*preinstall*_v6.9.34.sh)
INSTALLER="$BUNDLE_DIR/14-install_v6.9.34.sh"
SYMLINK="/usr/local/bin/cursor"
DESKTOP_ENTRY="/usr/share/applications/cursor.desktop"
ICON="$INSTALL_DIR/cursor.svg"
LOG_FILE="$BUNDLE_DIR/install_${VERSION}.log"
RELEASE_URL="https://api.cursor.com/releases/$VERSION/cursor.AppImage"

### Helpers
log()   { echo "[install][INFO] $*" | tee -a "$LOG_FILE"; }
warn()  { echo "[install][INFO] $*" | tee -a "$LOG_FILE" >&2; }
error() { echo "[install][ERROR] $*" | tee -a "$LOG_FILE" >&2; exit 1; }

### 1. Ensure libfuse2t64 on Ubuntu 25.04
if [[ "$(lsb_release -rs)" == "25.04" ]]; then
  if ! dpkg -l | grep -q libfuse2t64; then
    log "Detected Ubuntu 25.04 — installing libfuse2t64 for AppImage support"
    sudo apt-get update
    sudo apt-get install -y libfuse2t64
  else
    log "libfuse2t64 already installed"
  fi
fi

### 2. Clean up any leading line numbers in preinstall scripts
PREINSTALL_SCRIPTS=("$BUNDLE_DIR"/*preinstall*_v6.9.34.sh)
for script in "${PREINSTALL_SCRIPTS[@]}"; do
  if [[ -f "$script" ]]; then
    log "Stripping line numbers from $(basename "$script")"
    sed -i 's/^[[:digit:]]\+\([[:space:]]\+\)\?//' "$script"
    chmod +x "$script"
  fi
done

### 3. Run pre-install scripts (if any)
PREINSTALL_SCRIPTS=("$BUNDLE_DIR"/*preinstall*_v6.9.34.sh)
for script in "${PREINSTALL_SCRIPTS[@]}"; do
  if [[ -x "$script" ]]; then
    log "Executing $(basename "$script")"
    "$script" >> "$LOG_FILE" 2>&1
  fi
done

### 4. Download or verify AppImage
if [[ ! -f "$APPIMAGE" ]]; then
  log "AppImage not found — downloading version $VERSION"
  curl -fsSL "$RELEASE_URL" -o "$APPIMAGE"
  chmod +x "$APPIMAGE"
else
  log "AppImage already present — verifying executable permission"
  chmod +x "$APPIMAGE"
fi

### 5. Install to /opt and create symlink
log "Installing to $INSTALL_DIR"
sudo mkdir -p "$INSTALL_DIR"
sudo cp -p "$APPIMAGE" "$INSTALL_DIR/cursor.AppImage"

# Create a simple icon if not present
if [[ ! -f "$BUNDLE_DIR/cursor.svg" ]]; then
  sudo tee "$INSTALL_DIR/cursor.svg" > /dev/null <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <rect width="64" height="64" fill="#007ACC"/>
  <text x="32" y="40" font-family="Arial" font-size="24" fill="white" text-anchor="middle">C</text>
</svg>
EOF
else
  sudo cp -p "$BUNDLE_DIR/cursor.svg" "$INSTALL_DIR/cursor.svg"
fi

sudo tee "$DESKTOP_ENTRY" > /dev/null <<EOF
[Desktop Entry]
Name=Cursor
Exec=$SYMLINK
Icon=$INSTALL_DIR/cursor.svg
Type=Application
Categories=Development;IDE;
EOF

sudo ln -sf "$INSTALL_DIR/cursor.AppImage" "$SYMLINK"
sudo chmod +x "$SYMLINK"

### 6. Final message
log "Cursor v$VERSION installed successfully."

# Automatically run test suite after install
if [[ -f "$BUNDLE_DIR/22-test_cursor_suite_v6.9.34_fixed.sh" ]]; then
  bash "$BUNDLE_DIR/22-test_cursor_suite_v6.9.34_fixed.sh"
fi
echo "You can launch it by running: cursor"

exit 0

