#!/usr/bin/env bash
# 10-select_v6.9.34_enhanced.sh — Enhanced Language/Option Selection Script
set -euo pipefail
IFS=$'\n\t'

VERSION="6.9.34"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LANG_DIR="$HOME/.cursor/lang"
CONFIG_FILE="$HOME/.cursor/config"

# Create user directories instead of system directories
setup_user_dirs() {
  mkdir -p "$HOME/.cursor"
  mkdir -p "$LANG_DIR"
  touch "$CONFIG_FILE"
}

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')][SELECT] $*"
}

error() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')][SELECT][ERROR] $*" >&2
  exit 1
}

show_help() {
  cat << EOF
Cursor Language/Option Selection Script v$VERSION

USAGE:
  $0 [OPTION]

OPTIONS:
  --help, -h      Show this help message
  --list          List available languages
  --set LANG      Set language (en, it, etc.)
  --get           Get current language setting
  --reset         Reset to default settings

EXAMPLES:
  $0 --list       # Show available languages
  $0 --set en     # Set English
  $0 --set it     # Set Italian
  $0 --get        # Show current language

DESCRIPTION:
  Manages language and configuration settings for Cursor IDE.
  Settings are stored in user directory to avoid permission issues.

EOF
}

list_languages() {
  log "Available languages:"
  echo "  en - English (default)"
  echo "  it - Italian"
  
  if [[ -f "$SCRIPT_DIR/08-localization_v6.9.34.json" ]]; then
    log "Loading additional languages from localization file..."
    # Extract language codes from JSON file
    grep -o '"[a-z][a-z]"' "$SCRIPT_DIR/08-localization_v6.9.34.json" | sort -u | sed 's/"//g' | while read -r lang; do
      if [[ "$lang" != "en" ]] && [[ "$lang" != "it" ]]; then
        echo "  $lang - Available"
      fi
    done
  fi
}

get_current_language() {
  if [[ -f "$CONFIG_FILE" ]] && grep -q "^LANGUAGE=" "$CONFIG_FILE"; then
    grep "^LANGUAGE=" "$CONFIG_FILE" | cut -d= -f2
  else
    echo "en"
  fi
}

set_language() {
  local lang="$1"
  
  # Validate language
  case "$lang" in
    en|it)
      log "Setting language to: $lang"
      ;;
    *)
      log "Warning: Language '$lang' may not be fully supported"
      ;;
  esac
  
  # Update config file
  setup_user_dirs
  
  # Remove existing language setting and add new one
  grep -v "^LANGUAGE=" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" 2>/dev/null || true
  echo "LANGUAGE=$lang" >> "$CONFIG_FILE.tmp"
  mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
  
  # Create language-specific directory
  mkdir -p "$LANG_DIR/$lang"
  
  log "Language set to: $lang"
  log "Configuration saved to: $CONFIG_FILE"
}

reset_settings() {
  log "Resetting to default settings..."
  
  if [[ -f "$CONFIG_FILE" ]]; then
    rm -f "$CONFIG_FILE"
  fi
  
  if [[ -d "$LANG_DIR" ]]; then
    rm -rf "$LANG_DIR"
  fi
  
  setup_user_dirs
  set_language "en"
  
  log "Settings reset to defaults"
}

interactive_selection() {
  echo "=== Cursor IDE Language Selection ==="
  echo
  
  list_languages
  echo
  
  current_lang=$(get_current_language)
  echo "Current language: $current_lang"
  echo
  
  read -r -p "Select language (en/it) [current: $current_lang]: " selected_lang
  
  if [[ -z "$selected_lang" ]]; then
    selected_lang="$current_lang"
  fi
  
  set_language "$selected_lang"
  
  echo
  echo "Language selection completed!"
}

# Main execution
main() {
  case "${1:-}" in
    --help|-h)
      show_help
      ;;
    --list)
      list_languages
      ;;
    --set)
      if [[ -z "${2:-}" ]]; then
        error "Language code required. Use --help for usage."
      fi
      set_language "$2"
      ;;
    --get)
      echo "Current language: $(get_current_language)"
      ;;
    --reset)
      reset_settings
      ;;
    "")
      interactive_selection
      ;;
    *)
      error "Unknown option: $1. Use --help for usage information."
      ;;
  esac
}

# Execute main function
main "$@"

