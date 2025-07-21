#!/usr/bin/env bash
# Unified Launcher for Cursor v6.9.35
set -euo pipefail
IFS=$'\n\t'

VERSION="6.9.35"
APPIMAGE="./01-appimage_v6.9.35.AppImage"
LOGFILE="$HOME/.cursor_launcher.log"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >> "$LOGFILE"
}

error_exit() {
  echo "Error: $1" >&2
  log "ERROR: $1"
  exit 1
}

check_appimage() {
  if [[ ! -x "$APPIMAGE" ]]; then
    error_exit "AppImage not found or not executable: $APPIMAGE"
  fi
}

check_dependencies() {
  log "Checking dependencies..."
  local deps=(xdg-open libfuse2 curl)
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      error_exit "Missing dependency: $dep"
    fi
  done
  log "All dependencies found"
}

launch_app() {
  log "Launching Cursor AppImage..."
  nohup "$APPIMAGE" > /dev/null 2>&1 &
  sleep 2
  if pgrep -f "$APPIMAGE" > /dev/null; then
    log "AppImage launched successfully"
  else
    error_exit "Failed to launch AppImage"
  fi
}

create_desktop_entry() {
  log "Creating desktop entry..."
  local desktop="$HOME/.local/share/applications/cursor.desktop"
  mkdir -p "$(dirname "$desktop")"
  # Write a desktop entry pointing to the resolved AppImage path.
  local resolved_app="$(realpath "$APPIMAGE")"
  cat > "$desktop" <<DESKTOP_ENTRY
[Desktop Entry]
Name=Cursor
Exec=${resolved_app}
Icon=cursor
Type=Application
Categories=Utility;
DESKTOP_ENTRY
  log "Desktop entry created: $desktop"
}

create_symlink() {
  log "Creating symlink..."
  local link="/usr/local/bin/cursor"
  sudo ln -sf "$(realpath "$APPIMAGE")" "$link"
  log "Symlink created at $link"
}

show_version() {
  echo "Cursor Launcher version $VERSION"
}

remove_desktop_entry() {
  log "Removing desktop entry..."
  local desktop="$HOME/.local/share/applications/cursor.desktop"
  rm -f "$desktop"
  log "Desktop entry removed"
}

remove_symlink() {
  log "Removing symlink..."
  local link="/usr/local/bin/cursor"
  sudo rm -f "$link"
  log "Symlink removed"
}

show_help() {
  echo "Usage: $0 [options]"
  echo "Options:"
  echo "  --check       Check AppImage and dependencies"
  echo "  --install     Create desktop entry and symlink"
  echo "  --run         Run Cursor AppImage"
  echo "  --uninstall   Remove desktop entry and symlink"
  echo "  --version     Show version information"
  echo "  -h, --help    Show this help message"
}

main() {
  if [[ $# -eq 0 ]]; then
    show_help
    exit 0
  fi

  # Handle immediate options
  case "$1" in
    --version)
      show_version
      exit 0
      ;;
    --uninstall)
      remove_desktop_entry
      remove_symlink
      exit 0
      ;;
  esac

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --check)
        check_appimage
        check_dependencies
        ;;
      --install)
        check_appimage
        create_desktop_entry
        create_symlink
        ;;
      --run)
        check_appimage
        launch_app
        ;;
      -h|--help)
        show_help
        ;;
      *)
        error_exit "Unknown option: $1"
        ;;
    esac
    shift
  done
}

log "------------------------------------------"
log "Launcher started for version $VERSION"
main "$@"
log "Launcher completed"
