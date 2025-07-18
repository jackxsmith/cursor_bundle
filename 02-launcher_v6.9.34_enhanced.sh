#!/usr/bin/env bash
# 02-launcher_v6.9.34_enhanced.sh — Enhanced Cursor Launcher v6.9.34
set -euo pipefail
IFS=$'\n\t'

# ==============================================================================
# Enhanced Cursor Launcher with improved error handling and path resolution
# ==============================================================================

VERSION="6.9.34"
NAME="Cursor Launcher"
INSTALL_DIR="/opt/cursor"
BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try multiple possible AppImage locations
APPIMAGE_CANDIDATES=(
  "$BUNDLE_DIR/01-appimage_v6.9.34.AppImage"
  "$BUNDLE_DIR/cursor.AppImage"
  "/opt/cursor/cursor.AppImage"
  "$BUNDLE_DIR/appimage_v6.9.34.AppImage"
)

APPIMAGE=""
LOGFILE="$HOME/.cursor_launcher.log"
SYMLINK="/usr/local/bin/cursor"
DESKTOP_ENTRY="/usr/share/applications/cursor.desktop"

# Find the correct AppImage
find_appimage() {
  for candidate in "${APPIMAGE_CANDIDATES[@]}"; do
    if [[ -f "$candidate" ]] && [[ -x "$candidate" ]]; then
      APPIMAGE="$candidate"
      log "Found AppImage: $APPIMAGE"
      return 0
    fi
  done
  
  error "No valid AppImage found. Searched locations: ${APPIMAGE_CANDIDATES[*]}"
  return 1
}

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

error_exit() {
  echo "Error: $1" >&2
  log "ERROR: $1"
  exit 1
}

show_help() {
  cat << EOF
$NAME v$VERSION

USAGE:
  $0 [OPTION]

OPTIONS:
  --check       Check AppImage and dependencies
  --install     Create desktop entry and symlink (requires sudo)
  --run         Run Cursor AppImage
  --uninstall   Remove desktop entry and symlink (requires sudo)
  --version     Show version information
  -h, --help    Show this help message

EXAMPLES:
  $0 --check     # Verify installation
  $0 --install   # Set up desktop integration
  $0 --run       # Launch Cursor IDE
  $0             # Same as --run

DESCRIPTION:
  Enhanced launcher for Cursor IDE with automatic path detection,
  dependency checking, and desktop integration management.

EOF
}

show_version() {
  echo "$NAME v$VERSION"
  echo "Cursor IDE Launcher with enhanced error handling"
  if [[ -n "$APPIMAGE" ]]; then
    echo "AppImage location: $APPIMAGE"
  fi
}

check_appimage() {
  log "Checking AppImage and dependencies..."
  
  if ! find_appimage; then
    return 1
  fi
  
  # Check if AppImage is executable
  if [[ ! -x "$APPIMAGE" ]]; then
    error_exit "AppImage found but not executable: $APPIMAGE"
  fi
  
  log "✓ AppImage is valid and executable"
  return 0
}

check_dependencies() {
  log "Checking dependencies..."
  local deps=(xdg-open)
  local missing=()
  
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      missing+=("$dep")
    fi
  done
  
  # Check for fuse library
  if ! ldconfig -p 2>/dev/null | grep -q "libfuse.so"; then
    missing+=("libfuse2 or libfuse2t64")
  fi
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    log "⚠ Missing dependencies: ${missing[*]}"
    log "Install with: sudo apt-get install ${missing[*]// or*/}"
    return 1
  fi
  
  log "✓ All dependencies found"
  return 0
}

install_desktop_integration() {
  log "Installing desktop integration..."
  
  if [[ $EUID -ne 0 ]]; then
    error_exit "Desktop integration requires sudo privileges. Run: sudo $0 --install"
  fi
  
  if ! find_appimage; then
    return 1
  fi
  
  # Create installation directory if it doesn't exist
  mkdir -p "$INSTALL_DIR"
  
  # Copy AppImage to standard location if not already there
  if [[ "$APPIMAGE" != "$INSTALL_DIR/cursor.AppImage" ]]; then
    log "Copying AppImage to $INSTALL_DIR"
    cp -p "$APPIMAGE" "$INSTALL_DIR/cursor.AppImage"
    chmod +x "$INSTALL_DIR/cursor.AppImage"
  fi
  
  # Create icon if it doesn't exist
  if [[ ! -f "$INSTALL_DIR/cursor.svg" ]]; then
    log "Creating default icon"
    tee "$INSTALL_DIR/cursor.svg" > /dev/null <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <rect width="64" height="64" fill="#007ACC"/>
  <text x="32" y="40" font-family="Arial" font-size="24" fill="white" text-anchor="middle">C</text>
</svg>
EOF
  fi
  
  # Create desktop entry
  log "Creating desktop entry: $DESKTOP_ENTRY"
  tee "$DESKTOP_ENTRY" > /dev/null <<EOF
[Desktop Entry]
Name=Cursor
Comment=AI-powered code editor
Exec=$SYMLINK %F
Icon=$INSTALL_DIR/cursor.svg
Type=Application
Categories=Development;IDE;TextEditor;
StartupNotify=true
MimeType=text/plain;text/x-chdr;text/x-csrc;text/x-c++hdr;text/x-c++src;text/x-java;text/x-dsrc;text/x-pascal;text/x-perl;text/x-python;application/x-php;application/x-httpd-php3;application/x-httpd-php4;application/x-httpd-php5;text/x-sql;text/x-diff;
EOF
  
  # Create symlink
  log "Creating symlink: $SYMLINK"
  ln -sf "$INSTALL_DIR/cursor.AppImage" "$SYMLINK"
  
  # Update desktop database
  if command -v update-desktop-database &>/dev/null; then
    update-desktop-database /usr/share/applications/ 2>/dev/null || true
  fi
  
  log "✓ Desktop integration installed successfully"
  echo "Cursor can now be launched from the application menu or by running 'cursor'"
}

uninstall_desktop_integration() {
  log "Removing desktop integration..."
  
  if [[ $EUID -ne 0 ]]; then
    error_exit "Uninstall requires sudo privileges. Run: sudo $0 --uninstall"
  fi
  
  # Remove desktop entry
  if [[ -f "$DESKTOP_ENTRY" ]]; then
    log "Removing desktop entry: $DESKTOP_ENTRY"
    rm -f "$DESKTOP_ENTRY"
  fi
  
  # Remove symlink
  if [[ -L "$SYMLINK" ]]; then
    log "Removing symlink: $SYMLINK"
    rm -f "$SYMLINK"
  fi
  
  # Update desktop database
  if command -v update-desktop-database &>/dev/null; then
    update-desktop-database /usr/share/applications/ 2>/dev/null || true
  fi
  
  log "✓ Desktop integration removed"
  echo "Note: AppImage remains at $INSTALL_DIR/cursor.AppImage"
  echo "To completely remove Cursor, delete the $INSTALL_DIR directory"
}

launch_app() {
  log "Launching Cursor AppImage..."
  
  if ! find_appimage; then
    return 1
  fi
  
  # Check dependencies before launching
  if ! check_dependencies; then
    log "⚠ Some dependencies missing, but attempting to launch anyway..."
  fi
  
  # Launch AppImage
  log "Executing: $APPIMAGE"
  
  # Try to launch in background
  if command -v nohup &>/dev/null; then
    nohup "$APPIMAGE" "$@" > /dev/null 2>&1 &
  else
    "$APPIMAGE" "$@" &
  fi
  
  local app_pid=$!
  sleep 2
  
  # Check if process is still running
  if kill -0 "$app_pid" 2>/dev/null; then
    log "✓ Cursor launched successfully (PID: $app_pid)"
  else
    log "⚠ Cursor may have failed to launch or exited immediately"
    return 1
  fi
}

run_check() {
  echo "=== Cursor IDE System Check ==="
  echo
  
  # Check AppImage
  if check_appimage; then
    echo "✓ AppImage: OK"
  else
    echo "✗ AppImage: FAILED"
    return 1
  fi
  
  # Check dependencies
  if check_dependencies; then
    echo "✓ Dependencies: OK"
  else
    echo "⚠ Dependencies: MISSING (see log for details)"
  fi
  
  # Check installation
  if [[ -f "$INSTALL_DIR/cursor.AppImage" ]] && [[ -L "$SYMLINK" ]]; then
    echo "✓ Installation: OK"
  else
    echo "⚠ Installation: Not found (run --install for desktop integration)"
  fi
  
  # Check desktop entry
  if [[ -f "$DESKTOP_ENTRY" ]]; then
    echo "✓ Desktop entry: OK"
  else
    echo "⚠ Desktop entry: Not found"
  fi
  
  echo
  echo "System check completed. See $LOGFILE for details."
}

# Main execution
main() {
  # Initialize log
  touch "$LOGFILE" 2>/dev/null || LOGFILE="/tmp/cursor_launcher.log"
  
  case "${1:-}" in
    --help|-h)
      show_help
      ;;
    --version)
      show_version
      ;;
    --check)
      run_check
      ;;
    --install)
      install_desktop_integration
      ;;
    --uninstall)
      uninstall_desktop_integration
      ;;
    --run|"")
      shift 2>/dev/null || true
      launch_app "$@"
      ;;
    *)
      error_exit "Unknown option: $1. Use --help for usage information."
      ;;
  esac
}

# Execute main function
main "$@"

