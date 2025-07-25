#!/usr/bin/env bash
# 02-launcher_v6.9.35_enhanced.sh — Enhanced Cursor Launcher v6.9.35
set -euo pipefail
IFS=$'\n\t'

# ==============================================================================
# Enhanced Cursor Launcher with improved error handling and path resolution
# ==============================================================================

VERSION="6.9.163"
NAME="Cursor Launcher"
INSTALL_DIR="/opt/cursor"
BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try multiple possible AppImage locations
APPIMAGE_CANDIDATES=(
  "$BUNDLE_DIR/01-appimage.AppImage"
  "$BUNDLE_DIR/cursor.AppImage"
  "/opt/cursor/cursor.AppImage"
  "$BUNDLE_DIR/appimage_v6.9.163.AppImage"
  "$BUNDLE_DIR/01-appimage_v6.9.163.AppImage"
  "/usr/local/bin/cursor.AppImage"
  "$HOME/.local/bin/cursor.AppImage"
  "$HOME/Applications/cursor.AppImage"
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
      log "INFO" "Found AppImage: $APPIMAGE"
      return 0
    fi
  done
  
  log "ERROR" "No valid AppImage found. Searched locations: ${APPIMAGE_CANDIDATES[*]}"
  return 1
}

log() {
  local level="${1:-INFO}"
  local message="$*"
  local timestamp="$(date +'%Y-%m-%d %H:%M:%S')"
  
  case "$level" in
    INFO|*) echo "[${timestamp}] INFO: ${message}" | tee -a "$LOGFILE" ;;
    WARN) echo "[${timestamp}] WARN: ${message}" | tee -a "$LOGFILE" ;;
    ERROR) echo "[${timestamp}] ERROR: ${message}" | tee -a "$LOGFILE" >&2 ;;
    DEBUG) [[ "${DEBUG:-}" == "true" ]] && echo "[${timestamp}] DEBUG: ${message}" | tee -a "$LOGFILE" ;;
  esac
}

error_exit() {
  log "ERROR" "$1"
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
  log "INFO" "Checking AppImage and dependencies..."
  
  if ! find_appimage; then
    return 1
  fi
  
  # Check if AppImage is executable
  if [[ ! -x "$APPIMAGE" ]]; then
    error_exit "AppImage found but not executable: $APPIMAGE"
  fi
  
  # Security check: verify file is not a symlink to unexpected location
  if [[ -L "$APPIMAGE" ]]; then
    local link_target="$(readlink -f "$APPIMAGE")"
    log "WARN" "AppImage is a symlink pointing to: $link_target"
    
    # Ensure symlink target is within expected directories
    if [[ ! "$link_target" =~ ^(/opt/cursor|/usr/local|/home/.*/Applications|/.*/cursor_bundle) ]]; then
      error_exit "AppImage symlink points to unexpected location: $link_target"
    fi
  fi
  
  # Check file size (reasonable AppImage should be > 50MB and < 2GB)
  local file_size
  file_size="$(stat -c%s "$APPIMAGE" 2>/dev/null || echo 0)"
  if [[ "$file_size" -lt 52428800 ]]; then
    log "WARN" "AppImage size ($((file_size / 1024 / 1024))MB) seems small for a typical Cursor installation"
  elif [[ "$file_size" -gt 2147483648 ]]; then
    log "WARN" "AppImage size ($((file_size / 1024 / 1024))MB) seems unusually large"
  fi
  
  log "INFO" "✓ AppImage is valid and executable ($(du -h "$APPIMAGE" | cut -f1))"
  return 0
}

check_dependencies() {
  log "INFO" "Checking dependencies..."
  local deps=(xdg-open curl wget)
  local missing=()
  local optional_deps=()
  
  # Required dependencies
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      missing+=("$dep")
    fi
  done
  
  # Check for fuse library (required for AppImage)
  if ! ldconfig -p 2>/dev/null | grep -q "libfuse.so"; then
    if ! dpkg -l 2>/dev/null | grep -q "libfuse2\|libfuse3"; then
      missing+=("libfuse2")
    fi
  fi
  
  # Optional dependencies for better integration
  local opt_deps=(git nodejs npm python3 docker)
  for dep in "${opt_deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      optional_deps+=("$dep")
    fi
  done
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    log "ERROR" "Missing required dependencies: ${missing[*]}"
    log "INFO" "Install with: sudo apt-get install ${missing[*]}"
    return 1
  fi
  
  if [[ ${#optional_deps[@]} -gt 0 ]]; then
    log "WARN" "Missing optional dependencies for enhanced functionality: ${optional_deps[*]}"
    log "INFO" "Install with: sudo apt-get install ${optional_deps[*]}"
  fi
  
  log "INFO" "✓ All required dependencies found"
  return 0
}

install_desktop_integration() {
  log "INFO" "Installing desktop integration..."
  
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
    log "INFO" "Copying AppImage to $INSTALL_DIR"
    cp -p "$APPIMAGE" "$INSTALL_DIR/cursor.AppImage"
    chmod +x "$INSTALL_DIR/cursor.AppImage"
    # Verify the copy was successful
    if [[ ! -x "$INSTALL_DIR/cursor.AppImage" ]]; then
      error_exit "Failed to copy AppImage to $INSTALL_DIR"
    fi
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
  log "INFO" "Launching Cursor AppImage..."
  
  if ! find_appimage; then
    return 1
  fi
  
  # Check dependencies before launching
  if ! check_dependencies; then
    log "WARN" "Some dependencies missing, but attempting to launch anyway..."
  fi
  
  # Check available display
  if [[ -z "${DISPLAY:-}" ]] && [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    log "WARN" "No display server detected. GUI applications may not work."
  fi
  
  # Launch AppImage with better error handling
  log "INFO" "Executing: $APPIMAGE with args: $*"
  
  # Set up environment for AppImage
  export APPIMAGE_SILENT_INSTALL=1
  
  # Try to launch in background with proper error handling
  if command -v nohup &>/dev/null; then
    if ! nohup "$APPIMAGE" "$@" </dev/null >/dev/null 2>&1 & then
      error_exit "Failed to launch AppImage with nohup"
    fi
  else
    if ! "$APPIMAGE" "$@" </dev/null >/dev/null 2>&1 & then
      error_exit "Failed to launch AppImage"
    fi
  fi
  
  local app_pid=$!
  sleep 3
  
  # Check if process is still running
  if kill -0 "$app_pid" 2>/dev/null; then
    log "INFO" "✓ Cursor launched successfully (PID: $app_pid)"
    # Save PID for potential cleanup
    echo "$app_pid" > "$HOME/.cursor_last_pid" 2>/dev/null || true
  else
    log "ERROR" "Cursor failed to launch or exited immediately"
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

# Security validation
validate_environment() {
  log "INFO" "Validating environment security..."
  
  # Check if running as root (not recommended)
  if [[ "$EUID" -eq 0 ]] && [[ "${1:-}" != "--install" ]] && [[ "${1:-}" != "--uninstall" ]]; then
    log "WARN" "Running as root is not recommended for launching applications"
  fi
  
  # Check for suspicious environment variables
  local suspicious_vars=("LD_PRELOAD" "LD_LIBRARY_PATH")
  for var in "${suspicious_vars[@]}"; do
    if [[ -n "${!var:-}" ]]; then
      log "WARN" "Suspicious environment variable detected: $var=${!var}"
    fi
  done
  
  # Validate PATH doesn't contain current directory
  if [[ ":$PATH:" == *":."* ]] || [[ ":$PATH:" == *"::"* ]]; then
    log "WARN" "PATH contains current directory (security risk)"
  fi
  
  log "INFO" "✓ Environment validation completed"
}

# System information gathering
get_system_info() {
  log "DEBUG" "System: $(uname -a)"
  log "DEBUG" "Shell: $SHELL"
  log "DEBUG" "User: $(whoami)"
  log "DEBUG" "Working directory: $(pwd)"
  log "DEBUG" "Script location: $BUNDLE_DIR"
}

# Main execution
main() {
  # Initialize log with better error handling
  if ! touch "$LOGFILE" 2>/dev/null; then
    if [[ -w "/tmp" ]]; then
      LOGFILE="/tmp/cursor_launcher_$(date +%s).log"
    else
      LOGFILE="$HOME/.cursor_launcher_$(date +%s).log"
    fi
    touch "$LOGFILE" 2>/dev/null || {
      echo "Warning: Cannot create log file. Logging to stdout only."
      LOGFILE="/dev/stdout"
    }
  fi
  
  # Security and environment validation
  validate_environment "$@"
  
  # Gather system info for debugging
  get_system_info
  
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

