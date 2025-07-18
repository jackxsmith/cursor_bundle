#!/usr/bin/env bash
INSTALL_DIR="/opt/cursor"
# 14-install_v6.9.34_enhanced.sh — Cursor v6.9.34 Enhanced Installer
# Automatically installs all dependencies and handles all installation scenarios
set -euo pipefail
IFS=$'\n\t'

### Configuration
VERSION="6.9.34"
BUNDLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPIMAGE="$BUNDLE_DIR/01-appimage_v6.9.34.AppImage"
PREINSTALL_SCRIPTS=("$BUNDLE_DIR"/*preinstall*_v6.9.34.sh)
INSTALLER="$BUNDLE_DIR/14-install_v6.9.34_enhanced.sh"
SYMLINK="/usr/local/bin/cursor"
DESKTOP_ENTRY="/usr/share/applications/cursor.desktop"
ICON="$INSTALL_DIR/cursor.svg"
LOG_FILE="$BUNDLE_DIR/install_${VERSION}.log"
RELEASE_URL="https://api.cursor.com/releases/$VERSION/cursor.AppImage"
DRY_RUN=false
VERBOSE=true

### Helpers
log()   { 
  if [[ "$VERBOSE" == "true" ]]; then
    echo "[install][INFO] $*"
  fi
  echo "[$(date +'%Y-%m-%d %H:%M:%S')][INFO] $*" >> "$LOG_FILE" 2>/dev/null || true
}

warn()  { 
  echo "[install][INFO] $*" >&2
  echo "[$(date +'%Y-%m-%d %H:%M:%S')][INFO] $*" >> "$LOG_FILE" 2>/dev/null || true
}

error() { 
  echo "[install][ERROR] $*" >&2
  echo "[$(date +'%Y-%m-%d %H:%M:%S')][ERROR] $*" >> "$LOG_FILE" 2>/dev/null || true
  exit 1
}

show_help() {
  cat << EOF
Cursor IDE Installer v$VERSION

USAGE:
  $0 [OPTIONS]

OPTIONS:
  --help, -h          Show this help message
  --version, -v       Show version information
  --dry-run          Show what would be done without making changes
  --uninstall        Remove Cursor installation
  --quiet            Suppress verbose output
  --force            Force installation even if already installed

EXAMPLES:
  $0                  # Standard installation
  $0 --dry-run        # Preview installation steps
  $0 --uninstall      # Remove Cursor
  $0 --force          # Force reinstallation

DESCRIPTION:
  This script automatically installs Cursor IDE with all required dependencies.
  It supports multiple Linux distributions and handles all prerequisites.

REQUIREMENTS:
  - Linux system with package manager (apt, yum, dnf, or pacman)
  - Internet connection for dependency installation
  - sudo privileges for system installation

INSTALLATION LOCATIONS:
  - Binary: $INSTALL_DIR/cursor.AppImage
  - Symlink: $SYMLINK
  - Desktop: $DESKTOP_ENTRY
  - Icon: $ICON

For more information, visit: https://cursor.sh
EOF
}

show_version() {
  echo "Cursor IDE Installer v$VERSION"
  echo "Bundle contains Cursor IDE v6.9.34 AppImage"
  echo "Enhanced with automatic dependency management"
}

### Detect Linux Distribution
detect_distro() {
  if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DISTRO="$ID"
    DISTRO_VERSION="$VERSION_ID"
    DISTRO_NAME="$PRETTY_NAME"
  elif [[ -f /etc/redhat-release ]]; then
    DISTRO="rhel"
    DISTRO_NAME=$(cat /etc/redhat-release)
  elif [[ -f /etc/debian_version ]]; then
    DISTRO="debian"
    DISTRO_NAME="Debian $(cat /etc/debian_version)"
  else
    DISTRO="unknown"
    DISTRO_NAME="Unknown Linux"
  fi
  
  log "Detected distribution: $DISTRO_NAME"
}

### Install Dependencies Based on Distribution
install_dependencies() {
  log "Installing required dependencies..."
  
  case "$DISTRO" in
    ubuntu|debian)
      if [[ "$DRY_RUN" == "true" ]]; then
        log "[DRY-RUN] Would run: apt-get update && apt-get install -y curl libfuse2 libfuse2t64 python3 python3-pip zenity xdg-utils"
        return 0
      fi
      
      # Update package list
      log "Updating package list..."
      sudo apt-get update -qq || warn "Failed to update package list"
      
      # Install base dependencies
      local packages=(curl wget ca-certificates gnupg lsb-release)
      
      # Add fuse libraries based on Ubuntu version
      if [[ "$DISTRO" == "ubuntu" ]]; then
        local ubuntu_version=$(lsb_release -rs | cut -d. -f1)
        if [[ "$ubuntu_version" -ge 25 ]]; then
          packages+=(libfuse2t64)
        else
          packages+=(libfuse2)
        fi
      else
        packages+=(libfuse2)
      fi
      
      # Add optional but useful packages
      packages+=(python3 python3-pip zenity xdg-utils desktop-file-utils)
      
      log "Installing packages: ${packages[*]}"
      sudo apt-get install -y "${packages[@]}" || warn "Some packages failed to install"
      
      # Install Flask for web UI
      if command -v pip3 &>/dev/null; then
        log "Installing Flask for web UI..."
        pip3 install --user flask || warn "Failed to install Flask"
      fi
      ;;
      
    fedora|rhel|centos)
      if [[ "$DRY_RUN" == "true" ]]; then
        log "[DRY-RUN] Would run: dnf install -y curl fuse-libs python3 python3-pip zenity xdg-utils"
        return 0
      fi
      
      local packages=(curl wget ca-certificates fuse-libs python3 python3-pip zenity xdg-utils desktop-file-utils)
      log "Installing packages: ${packages[*]}"
      sudo dnf install -y "${packages[@]}" || sudo yum install -y "${packages[@]}" || warn "Some packages failed to install"
      
      if command -v pip3 &>/dev/null; then
        pip3 install --user flask || warn "Failed to install Flask"
      fi
      ;;
      
    arch|manjaro)
      if [[ "$DRY_RUN" == "true" ]]; then
        log "[DRY-RUN] Would run: pacman -S --noconfirm curl fuse2 python python-pip zenity xdg-utils"
        return 0
      fi
      
      local packages=(curl wget ca-certificates fuse2 python python-pip zenity xdg-utils desktop-file-utils)
      log "Installing packages: ${packages[*]}"
      sudo pacman -S --noconfirm "${packages[@]}" || warn "Some packages failed to install"
      
      if command -v pip &>/dev/null; then
        pip install --user flask || warn "Failed to install Flask"
      fi
      ;;
      
    *)
      warn "Unsupported distribution: $DISTRO_NAME"
      warn "Please install manually: curl, libfuse2, python3, python3-pip, zenity, xdg-utils"
      ;;
  esac
  
  log "Dependency installation completed"
}

### Verify Dependencies
verify_dependencies() {
  log "Verifying dependencies..."
  local missing=()
  
  # Check essential dependencies
  local deps=(curl)
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      missing+=("$dep")
    fi
  done
  
  # Check fuse library
  if ! ldconfig -p | grep -q "libfuse.so"; then
    missing+=("libfuse2/libfuse2t64")
  fi
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
      # In dry-run mode, log missing dependencies as a warning but do not abort.
      warn "[DRY-RUN] Missing dependencies detected: ${missing[*]} (ignored in dry-run mode)"
    else
      error "Missing dependencies: ${missing[*]}. Please install them manually or run with sudo."
    fi
  else
    log "All essential dependencies verified"
  fi
}

### Uninstall Function
uninstall_cursor() {
  log "Uninstalling Cursor IDE..."
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] Would remove:"
    log "[DRY-RUN]   - $INSTALL_DIR"
    log "[DRY-RUN]   - $SYMLINK"
    log "[DRY-RUN]   - $DESKTOP_ENTRY"
    return 0
  fi
  
  # Remove installation directory
  if [[ -d "$INSTALL_DIR" ]]; then
    log "Removing installation directory: $INSTALL_DIR"
    sudo rm -rf "$INSTALL_DIR"
  fi
  
  # Remove symlink
  if [[ -L "$SYMLINK" ]]; then
    log "Removing symlink: $SYMLINK"
    sudo rm -f "$SYMLINK"
  fi
  
  # Remove desktop entry
  if [[ -f "$DESKTOP_ENTRY" ]]; then
    log "Removing desktop entry: $DESKTOP_ENTRY"
    sudo rm -f "$DESKTOP_ENTRY"
  fi
  
  # Update desktop database
  if command -v update-desktop-database &>/dev/null; then
    sudo update-desktop-database /usr/share/applications/ 2>/dev/null || true
  fi
  
  log "Cursor IDE uninstalled successfully"
}

### Check if already installed
check_existing_installation() {
  if [[ -f "$INSTALL_DIR/cursor.AppImage" ]] && [[ -L "$SYMLINK" ]]; then
    log "Cursor IDE is already installed"
    if [[ "$1" != "--force" ]]; then
      echo "Cursor IDE is already installed. Use --force to reinstall or --uninstall to remove."
      exit 0
    else
      log "Force flag detected, proceeding with reinstallation"
    fi
  fi
}

### Main Installation Function
install_cursor() {
  log "Starting Cursor IDE installation..."
  
  if [[ "$DRY_RUN" == "true" ]]; then
    log "[DRY-RUN] Would install Cursor IDE to $INSTALL_DIR"
    log "[DRY-RUN] Would create symlink at $SYMLINK"
    log "[DRY-RUN] Would create desktop entry at $DESKTOP_ENTRY"
    return 0
  fi
  
  # Run pre-install scripts
  for script in "${PREINSTALL_SCRIPTS[@]}"; do
    if [[ -x "$script" ]]; then
      log "Executing pre-install script: $(basename "$script")"
      "$script" >> "$LOG_FILE" 2>&1 || warn "Pre-install script failed: $(basename "$script")"
    fi
  done
  
  # Verify AppImage exists
  if [[ ! -f "$APPIMAGE" ]]; then
    log "AppImage not found, attempting to download..."
    if command -v curl &>/dev/null; then
      curl -fsSL "$RELEASE_URL" -o "$APPIMAGE" || error "Failed to download AppImage"
      chmod +x "$APPIMAGE"
    else
      error "AppImage not found and curl not available for download"
    fi
  else
    log "AppImage found: $APPIMAGE"
    chmod +x "$APPIMAGE"
  fi
  
  # Create installation directory
  log "Creating installation directory: $INSTALL_DIR"
  sudo mkdir -p "$INSTALL_DIR"
  
  # Copy AppImage
  log "Installing AppImage to $INSTALL_DIR"
  sudo cp -p "$APPIMAGE" "$INSTALL_DIR/cursor.AppImage"
  sudo chmod +x "$INSTALL_DIR/cursor.AppImage"
  
  # Create or copy icon
  if [[ -f "$BUNDLE_DIR/cursor.svg" ]]; then
    sudo cp -p "$BUNDLE_DIR/cursor.svg" "$INSTALL_DIR/cursor.svg"
  else
    log "Creating default icon"
    sudo tee "$INSTALL_DIR/cursor.svg" > /dev/null <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<svg width="64" height="64" viewBox="0 0 64 64" xmlns="http://www.w3.org/2000/svg">
  <rect width="64" height="64" fill="#007ACC"/>
  <text x="32" y="40" font-family="Arial" font-size="24" fill="white" text-anchor="middle">C</text>
</svg>
EOF
  fi
  
  # Create desktop entry
  log "Creating desktop entry: $DESKTOP_ENTRY"
  sudo tee "$DESKTOP_ENTRY" > /dev/null <<EOF
[Desktop Entry]
Name=Cursor
Comment=AI-powered code editor
Exec=$SYMLINK
Icon=$INSTALL_DIR/cursor.svg
Type=Application
Categories=Development;IDE;TextEditor;
StartupNotify=true
MimeType=text/plain;text/x-chdr;text/x-csrc;text/x-c++hdr;text/x-c++src;text/x-java;text/x-dsrc;text/x-pascal;text/x-perl;text/x-python;application/x-php;application/x-httpd-php3;application/x-httpd-php4;application/x-httpd-php5;text/x-sql;text/x-diff;
EOF
  
  # Create symlink
  log "Creating symlink: $SYMLINK"
  sudo ln -sf "$INSTALL_DIR/cursor.AppImage" "$SYMLINK"
  
  # Update desktop database
  if command -v update-desktop-database &>/dev/null; then
    sudo update-desktop-database /usr/share/applications/ 2>/dev/null || true
  fi
  
  # Run post-install scripts
  local postinstall_scripts=("$BUNDLE_DIR"/*postinstall*_v6.9.34.sh)
  for script in "${postinstall_scripts[@]}"; do
    if [[ -x "$script" ]]; then
      log "Executing post-install script: $(basename "$script")"
      "$script" >> "$LOG_FILE" 2>&1 || warn "Post-install script failed: $(basename "$script")"
    fi
  done
  
  log "Cursor IDE v$VERSION installed successfully!"
  echo ""
  echo "✅ Installation completed successfully!"
  echo ""
  echo "You can now launch Cursor IDE by:"
  echo "  • Running: cursor"
  echo "  • Using the desktop application menu"
  echo "  • Running: $SYMLINK"
  echo ""
  echo "Installation details:"
  echo "  • Binary: $INSTALL_DIR/cursor.AppImage"
  echo "  • Symlink: $SYMLINK"
  echo "  • Desktop entry: $DESKTOP_ENTRY"
  echo "  • Log file: $LOG_FILE"
}

### Parse Command Line Arguments
parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --help|-h)
        show_help
        exit 0
        ;;
      --version|-v)
        show_version
        exit 0
        ;;
      --dry-run)
        DRY_RUN=true
        log "Dry-run mode enabled"
        shift
        ;;
      --uninstall)
        uninstall_cursor
        exit 0
        ;;
      --quiet)
        VERBOSE=false
        shift
        ;;
      --force)
        shift
        ;;
      *)
        error "Unknown option: $1. Use --help for usage information."
        ;;
    esac
  done
}

### Main Execution
main() {
  # Initialize log file
  touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/cursor_install_${VERSION}.log"
  
  log "Starting Cursor IDE installer v$VERSION"
  log "Command line: $0 $*"
  
  # Parse arguments
  parse_arguments "$@"
  
  # Check for existing installation
  check_existing_installation "$@"
  
  # Detect distribution
  detect_distro
  
  # Install dependencies
  install_dependencies
  
  # Verify dependencies
  verify_dependencies
  
  # Install Cursor
  install_cursor
  
  # Run test suite if available
  local test_suite="$BUNDLE_DIR/22-test_cursor_suite_v6.9.34_fixed.sh"
  if [[ -f "$test_suite" ]] && [[ "$DRY_RUN" == "false" ]]; then
    log "Running post-installation tests..."
    bash "$test_suite" >> "$LOG_FILE" 2>&1 || warn "Some tests failed, but installation should work"
  fi
  
  log "Installation process completed"
}

# Execute main function with all arguments
main "$@"

