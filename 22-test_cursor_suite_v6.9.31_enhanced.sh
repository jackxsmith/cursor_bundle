#!/usr/bin/env bash
# 22-test_cursor_suite_v6.9.32_enhanced.sh — Enhanced Cursor Test Suite
set -euo pipefail
IFS=$'\n\t'

VERSION="6.9.32"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="cursor_test_${VERSION}.log"
JSON="cursor_test_${VERSION}.json"
ERROR_LOG="cursor_errors_${VERSION}.log"
TMPDIR=$(mktemp -d)
INSTALL_PREFIX="/opt/cursor_test_${VERSION}"
SYMLINK="/usr/local/bin/cursor_test"
DOCKER_IMAGE="cursor_test:${VERSION}"
TIMEOUT_CMD=${TIMEOUT_CMD:-timeout}
VERBOSE=1

# Initialize log files
init_logs() {
  # Initialise or clear log files
  : > "$LOG"
  : > "$JSON"
  : > "$ERROR_LOG"
  echo "=== Cursor Test Suite v$VERSION ===" > "$LOG"
  echo "Test started: $(date)" >> "$LOG"
  echo "[]" > "$JSON"  # Initialize as empty JSON array
}

log() { 
  if [[ $VERBOSE -eq 1 ]]; then 
    echo "[INFO] $*"
  fi
  echo "[$(date +'%Y-%m-%d %H:%M:%S')][INFO] $*" >> "$LOG"
}

error() { 
  echo "[ERROR] $*" >&2
  echo "[$(date +'%Y-%m-%d %H:%M:%S')][ERROR] $*" >> "$LOG"
  echo "[$(date +'%Y-%m-%d %H:%M:%S')][ERROR] $*" >> "$ERROR_LOG"
}

warn() {
  echo "[INFO] $*" >&2
  echo "[$(date +'%Y-%m-%d %H:%M:%S')][INFO] $*" >> "$LOG"
}

jsonlog() {
  local test_name="$1"
  local result="$2"
  local message="$3"
  local timestamp=$(date -Iseconds)
  
  # Create JSON entry
  local json_entry="{\"test\":\"$test_name\",\"result\":\"$result\",\"message\":\"$message\",\"timestamp\":\"$timestamp\"}"
  
  # Append to JSON log (simple append, not proper JSON array for now)
  echo "$json_entry" >> "$JSON"
}

cleanup() {
  if [[ $VERBOSE -eq 1 ]]; then 
    echo "Cleaning up..."
  fi
  rm -rf "$TMPDIR" 2>/dev/null || true
  docker rmi "$DOCKER_IMAGE" &>/dev/null || true
}
trap cleanup EXIT

show_help() {
  cat << EOF
Cursor Test Suite v$VERSION

USAGE:
  $0 [OPTIONS]

OPTIONS:
  --help, -h          Show this help message
  --verbose, -v       Enable verbose output
  --quiet, -q         Suppress output except errors
  --test TEST         Run specific test only
  --list              List available tests
  --json              Output results in JSON format only

AVAILABLE TESTS:
  dependencies        Check system dependencies
  file_structure      Validate bundle file structure
  syntax_check        Check script syntax
  installation        Test installation process
  launcher            Test launcher functionality
  web_ui              Test web interface
  docker              Test Docker deployment
  cleanup             Test cleanup/uninstall

EXAMPLES:
  $0                  # Run all tests
  $0 --test syntax    # Run syntax check only
  $0 --quiet --json   # JSON output only

EOF
}

# Test system dependencies
test_dependencies() {
  log "Testing system dependencies..."
  local deps=(bash grep awk tar curl python3)
  local missing=()
  local optional_missing=()
  
  # Check essential dependencies
  for d in "${deps[@]}"; do
    if ! command -v "$d" &>/dev/null; then
      missing+=("$d")
    fi
  done
  
  # Check optional dependencies
  local optional_deps=(zenity docker notify-send flask)
  for d in "${optional_deps[@]}"; do
    if ! command -v "$d" &>/dev/null; then
      optional_missing+=("$d")
    fi
  done
  
  if [[ ${#missing[@]} -gt 0 ]]; then
    error "Missing essential dependencies: ${missing[*]}"
    jsonlog "dependencies" "FAIL" "Missing essential: ${missing[*]}"
    return 1
  fi
  
  if [[ ${#optional_missing[@]} -gt 0 ]]; then
    warn "Optional dependencies not found (this is normal): ${optional_missing[*]}"
    jsonlog "dependencies" "WARN" "Missing optional: ${optional_missing[*]}"
  else
    jsonlog "dependencies" "PASS" "All dependencies present"
  fi
  
  log "Dependencies check completed"
  return 0
}

# Test file structure
test_file_structure() {
  log "Testing bundle file structure..."
  local required_files=(
    "01-appimage_v6.9.32.AppImage"
    "14-install_v6.9.32_enhanced.sh"
    "02-launcher_v6.9.32_enhanced.sh"
  )
  
  local missing_files=()
  
  for file in "${required_files[@]}"; do
    if [[ ! -f "$SCRIPT_DIR/$file" ]]; then
      missing_files+=("$file")
    fi
  done
  
  if [[ ${#missing_files[@]} -gt 0 ]]; then
    error "Missing required files: ${missing_files[*]}"
    jsonlog "file_structure" "FAIL" "Missing files: ${missing_files[*]}"
    return 1
  fi
  
  # Check AppImage is executable
  if [[ ! -x "$SCRIPT_DIR/01-appimage_v6.9.32.AppImage" ]]; then
    error "AppImage is not executable"
    jsonlog "file_structure" "FAIL" "AppImage not executable"
    return 1
  fi
  
  jsonlog "file_structure" "PASS" "All required files present"
  log "File structure check completed"
  return 0
}

# Test script syntax
test_syntax_check() {
  log "Testing script syntax..."
  local script_errors=()
  
  # Check all shell scripts
  for script in "$SCRIPT_DIR"/*.sh; do
    if [[ -f "$script" ]]; then
      local script_name=$(basename "$script")
      log "Checking syntax: $script_name"
      
      if ! bash -n "$script" 2>>"$ERROR_LOG"; then
        script_errors+=("$script_name")
        error "Syntax error in: $script_name"
      fi
    fi
  done
  
  # Check Python scripts
  for script in "$SCRIPT_DIR"/*.py; do
    if [[ -f "$script" ]]; then
      local script_name=$(basename "$script")
      log "Checking Python syntax: $script_name"
      
      if ! python3 -m py_compile "$script" 2>>"$ERROR_LOG"; then
        script_errors+=("$script_name")
        error "Python syntax error in: $script_name"
      fi
    fi
  done
  
  if [[ ${#script_errors[@]} -gt 0 ]]; then
    error "Syntax errors found in: ${script_errors[*]}"
    jsonlog "syntax_check" "FAIL" "Syntax errors: ${script_errors[*]}"
    return 1
  fi
  
  jsonlog "syntax_check" "PASS" "All scripts have valid syntax"
  log "Syntax check completed"
  return 0
}

# Test installation process
test_installation() {
  log "Testing installation process..."
  
  # Test dry-run first
  if [[ -x "$SCRIPT_DIR/14-install_v6.9.32_enhanced.sh" ]]; then
    log "Testing dry-run installation..."
    if ! "$SCRIPT_DIR/14-install_v6.9.32_enhanced.sh" --dry-run &>>"$LOG"; then
      error "Dry-run installation failed"
      jsonlog "installation" "FAIL" "Dry-run failed"
      return 1
    fi
  else
    error "Enhanced installer not found"
    jsonlog "installation" "FAIL" "Installer not found"
    return 1
  fi
  
  jsonlog "installation" "PASS" "Installation dry-run successful"
  log "Installation test completed"
  return 0
}

# Test launcher functionality
test_launcher() {
  log "Testing launcher functionality..."
  
  if [[ -x "$SCRIPT_DIR/02-launcher_v6.9.32_enhanced.sh" ]]; then
    log "Testing launcher help..."
    if ! "$SCRIPT_DIR/02-launcher_v6.9.32_enhanced.sh" --help &>>"$LOG"; then
      error "Launcher help failed"
      jsonlog "launcher" "FAIL" "Help option failed"
      return 1
    fi
    
    log "Testing launcher check..."
    if ! "$SCRIPT_DIR/02-launcher_v6.9.32_enhanced.sh" --check &>>"$LOG"; then
      warn "Launcher check had issues (may be expected)"
      jsonlog "launcher" "WARN" "Check had issues"
    else
      jsonlog "launcher" "PASS" "Launcher functionality working"
    fi
  else
    error "Enhanced launcher not found"
    jsonlog "launcher" "FAIL" "Launcher not found"
    return 1
  fi
  
  log "Launcher test completed"
  return 0
}

# Test web UI
test_web_ui() {
  log "Testing web UI..."
  
  local web_ui_script="$SCRIPT_DIR/06-launcherplus_v6.9.32_fixed.py"
  if [[ -f "$web_ui_script" ]]; then
    log "Testing web UI syntax..."
    if python3 -m py_compile "$web_ui_script" 2>>"$ERROR_LOG"; then
      log "Testing web UI startup..."
      # Start web UI in background and test
      if timeout 10 python3 "$web_ui_script" &>/dev/null & then
        local web_pid=$!
        sleep 3
        
        # Test if web UI responds
        if curl -s http://127.0.0.1:8080/ >/dev/null 2>&1; then
          jsonlog "web_ui" "PASS" "Web UI started and responded"
        else
          jsonlog "web_ui" "WARN" "Web UI started but no response"
        fi
        
        # Clean up
        kill "$web_pid" 2>/dev/null || true
      else
        jsonlog "web_ui" "WARN" "Web UI startup test skipped"
      fi
    else
      error "Web UI syntax error"
      jsonlog "web_ui" "FAIL" "Syntax error"
      return 1
    fi
  else
    warn "Web UI script not found"
    jsonlog "web_ui" "SKIP" "Script not found"
  fi
  
  log "Web UI test completed"
  return 0
}

# Test Docker deployment
test_docker() {
    log_info "Testing Docker installation method..."
    
    if ! command -v docker >/dev/null 2>&1; then
        log_warn "Docker not available, skipping Docker tests"
        return 0
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log_warn "Docker daemon not running, skipping Docker tests"
        return 0
    fi
    
    # Test Docker script syntax
    if [[ -f "15-docker_install_v6.9.32.sh" ]]; then
        if bash -n "15-docker_install_v6.9.32.sh"; then
            log_info "✓ Docker installation script syntax OK"
        else
            log_error "✗ Docker installation script syntax error"
            return 1
        fi
    else
        log_error "✗ Docker installation script missing"
        return 1
    fi
    
    # Test Dockerfile syntax
    if [[ -f "Dockerfile" ]]; then
        if docker build --dry-run . >/dev/null 2>&1; then
            log_info "✓ Dockerfile syntax OK"
        else
            log_warn "Dockerfile may have issues (dry-run not fully supported)"
        fi
    else
        log_error "✗ Dockerfile missing"
        return 1
    fi
    
    # Test docker-compose.yml
    if [[ -f "docker-compose.yml" ]]; then
        if command -v docker-compose >/dev/null 2>&1; then
            if docker-compose config >/dev/null 2>&1; then
                log_info "✓ Docker Compose configuration OK"
            else
                log_warn "Docker Compose configuration may have issues"
            fi
        else
            log_info "Docker Compose not available for validation"
        fi
    else
        log_error "✗ docker-compose.yml missing"
        return 1
    fi
    
    log_info "Docker installation method tests completed"
    return 0
}

# Test cleanup functionality
test_cleanup() {
  log "Testing cleanup functionality..."
  
  # Test uninstall option in enhanced installer
  if [[ -x "$SCRIPT_DIR/14-install_v6.9.32_enhanced.sh" ]]; then
    log "Testing uninstall dry-run..."
    if "$SCRIPT_DIR/14-install_v6.9.32_enhanced.sh" --uninstall --dry-run &>>"$LOG"; then
      jsonlog "cleanup" "PASS" "Uninstall dry-run successful"
    else
      error "Uninstall dry-run failed"
      jsonlog "cleanup" "FAIL" "Uninstall dry-run failed"
      return 1
    fi
  else
    warn "Enhanced installer not found for cleanup test"
    jsonlog "cleanup" "SKIP" "Installer not found"
  fi
  
  log "Cleanup test completed"
  return 0
}

# List available tests
list_tests() {
  echo "Available tests:"
  echo "  dependencies    - Check system dependencies"
  echo "  file_structure  - Validate bundle file structure"
  echo "  syntax_check    - Check script syntax"
  echo "  installation    - Test installation process"
  echo "  launcher        - Test launcher functionality"
  echo "  web_ui          - Test web interface"
  echo "  docker          - Test Docker deployment"
  echo "  cleanup         - Test cleanup/uninstall"
}

# Run all tests
run_all_tests() {
  log "Starting comprehensive test suite..."
  local failed_tests=()
  
  # Array of test functions
  local tests=(
    "test_dependencies"
    "test_file_structure"
    "test_syntax_check"
    "test_installation"
    "test_launcher"
    "test_web_ui"
    "test_docker"
    "test_cleanup"
  )
  
  for test_func in "${tests[@]}"; do
    log "Running: $test_func"
    if ! "$test_func"; then
      failed_tests+=("$test_func")
    fi
    echo  # Add spacing between tests
  done
  
  # Summary
  log "Test suite completed"
  
  if [[ ${#failed_tests[@]} -eq 0 ]]; then
    log "✅ All tests passed!"
    jsonlog "summary" "PASS" "All tests completed successfully"
    return 0
  else
    error "❌ Failed tests: ${failed_tests[*]}"
    jsonlog "summary" "FAIL" "Failed tests: ${failed_tests[*]}"
    return 1
  fi
}

# Run specific test
run_specific_test() {
  local test_name="$1"
  
  case "$test_name" in
    dependencies|deps)
      test_dependencies
      ;;
    file_structure|files)
      test_file_structure
      ;;
    syntax_check|syntax)
      test_syntax_check
      ;;
    installation|install)
      test_installation
      ;;
    launcher)
      test_launcher
      ;;
    web_ui|webui)
      test_web_ui
      ;;
    docker)
      test_docker
      ;;
    cleanup)
      test_cleanup
      ;;
    *)
      error "Unknown test: $test_name"
      echo "Use --list to see available tests"
      return 1
      ;;
  esac
}

# Main execution
main() {
  init_logs
  
  local specific_test=""
  local json_only=false
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --help|-h)
        show_help
        exit 0
        ;;
      --verbose|-v)
        VERBOSE=1
        shift
        ;;
      --quiet|-q)
        VERBOSE=0
        shift
        ;;
      --test)
        specific_test="$2"
        shift 2
        ;;
      --list)
        list_tests
        exit 0
        ;;
      --json)
        json_only=true
        VERBOSE=0
        shift
        ;;
      *)
        error "Unknown option: $1"
        show_help
        exit 1
        ;;
    esac
  done
  
  # Run tests
  local exit_code=0
  
  if [[ -n "$specific_test" ]]; then
    run_specific_test "$specific_test" || exit_code=1
  else
    run_all_tests || exit_code=1
  fi
  
  # Output results
  if [[ "$json_only" == "true" ]]; then
    cat "$JSON"
  else
    echo
    echo "=== Test Results ==="
    echo "Log file: $LOG"
    echo "JSON results: $JSON"
    echo "Error log: $ERROR_LOG"
    
    if [[ -s "$ERROR_LOG" ]]; then
      echo
      echo "Errors encountered:"
      cat "$ERROR_LOG"
    fi
  fi
  
  exit $exit_code
}

# Execute main function
main "$@"

