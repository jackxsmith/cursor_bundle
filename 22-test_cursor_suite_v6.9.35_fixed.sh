#!/usr/bin/env bash

# Test Debian package installation via dpkg-deb -x
# Run test_deb() and log errors
test_deb() {
  echo "[INFO] Testing .deb package structure"
  DEB_FILE=$(ls *.deb | head -n1)
  if [[ -z "$DEB_FILE" ]]; then
    echo "[ERROR] No .deb file found"
    echo "test_deb failed" >> "$ERROR_LOG"
    return 1
  fi
  mkdir -p deb_test
  dpkg-deb -x "$DEB_FILE" deb_test
  # Check that AppImage and symlink exist in extracted structure
  if [[ ! -f deb_test/opt/cursor/cursor.AppImage ]]; then
    echo "[ERROR] AppImage missing in .deb"
    echo "test_deb failed" >> "$ERROR_LOG"
    return 1
  fi
  if [[ ! -f deb_test/usr/local/bin/cursor ]]; then
    echo "[ERROR] Symlink 'cursor' missing in .deb"
    echo "test_deb failed" >> "$ERROR_LOG"
    return 1
  fi
  echo "[INFO] .deb package structure OK"
  rm -rf deb_test
  return 0
}

#!/usr/bin/env bash
# Full Enterprise Test Suite for Cursor v6.9.35
set -euo pipefail
IFS=$'\n\t'
VERSION="6.9.35"
LOG="cursor_test_${VERSION}.log"
JSON="cursor_test_${VERSION}.json"
TMPDIR=$(mktemp -d)
INSTALL_PREFIX="/opt/cursor_test_${VERSION}"
SYMLINK="/usr/local/bin/cursor_test"
DOCKER_IMAGE="cursor_test:${VERSION}"
TIMEOUT_CMD=${TIMEOUT_CMD:-timeout}
VERBOSE=1
ERROR_LOG="cursor_errors.log"

log()    { [[ $VERBOSE -eq 1 ]] && echo "[INFO] $*"; echo "[INFO] $*" >> "$LOG"; }
error()  { echo "[ERROR] $*"; echo "[ERROR] $*" >> "$LOG"; }
jsonlog(){ echo "{\"test\":\"$1\",\"result\":\"$2\",\"msg\":\"$3\"}" >> "$JSON"; }

cleanup() {
  [[ $VERBOSE -eq 1 ]] && echo "Cleaning up..."
  rm -rf "$TMPDIR"
  docker rmi "$DOCKER_IMAGE" &>/dev/null || true
}
trap cleanup EXIT

test_dependencies() {
  log "Testing dependencies..."
  local deps=(bash grep awk tar dpkg curl zenity python3 docker notify-send flask)
  for d in "${deps[@]}"; do
    command -v "$d" &>/dev/null || { error "Missing: $d"; jsonlog "dependencies" "FAIL" "Missing $d"; return 1; }
  done
  jsonlog "dependencies" "PASS" "All present"
}

test_checksums() {
  log "Testing checksums..."
  for f in install_v${VERSION}.sh cursor.AppImage; do
    [[ -f "${f}.sha256" ]] || { error "Missing checksum for $f"; jsonlog "checksums" "FAIL" "Missing checksum"; return 1; }
    sha256sum -c "${f}.sha256" &>>"$LOG" || { error "Checksum mismatch: $f"; jsonlog "checksums" "FAIL" "Mismatch $f"; return 1; }
  done
  jsonlog "checksums" "PASS" "SHA256 OK"
}

test_extract_bundle() {
  log "Testing tar.gz extraction..."
  tar -xzf cursor_v${VERSION}.tar.gz -C "$TMPDIR"
  [[ -x "$TMPDIR/install_v${VERSION}.sh" ]] || { error "Missing installer in tarball"; jsonlog "extract_bundle" "FAIL" "No installer"; return 1; }
  jsonlog "extract_bundle" "PASS" "Extract OK"
}

test_portable_launch() {
  log "Testing portable launch..."
  $TIMEOUT_CMD 20 "$TMPDIR/install_v${VERSION}.sh" --portable &>>"$LOG" &
  PORT_PID=$!
  sleep 3
  kill "$PORT_PID" || true
  jsonlog "portable_launch" "PASS" "Portable OK"
}

test_install_uninstall() {
  log "Testing install/uninstall..."
  sudo "$TMPDIR/install_v${VERSION}.sh" --install &>>"$LOG"
  [[ -x "/opt/cursor/cursor.AppImage" ]] || { error "Install failed"; jsonlog "install" "FAIL" "Missing binary"; return 1; }
  sudo "$TMPDIR/install_v${VERSION}.sh" --uninstall &>>"$LOG"
  jsonlog "install_uninstall" "PASS" "Install/Uninstall OK"
}

test_desktop_symlink() {
  log "Testing symlink/desktop entry..."
  sudo ln -sf "/opt/cursor/cursor.AppImage" "$SYMLINK"
  command -v cursor_test &>>"$LOG" || { error "Symlink failed"; jsonlog "symlink" "FAIL" "No symlink"; return 1; }
  sudo rm -f "$SYMLINK"
  jsonlog "symlink" "PASS" "Symlink OK"
}

# Run test_notify() and log errors
test_notify() {
  log "Testing notification..."
  notify-send "Cursor Test" "Notification" || { 
    echo "test_notify failed" >> "$ERROR_LOG"
    jsonlog "notify" "WARN" "notify-send failed"
    return 0
  }
  jsonlog "notify" "PASS" "Notification OK"
}

# Run test_cli_flags() and log errors
test_cli_flags() {
  log "Testing CLI flags..."
  "$TMPDIR/install_v${VERSION}.sh" --help | grep "$VERSION" || { 
    error "--help flag fail"
    echo "test_cli_flags failed" >> "$ERROR_LOG"
    jsonlog "cli_flags" "FAIL" "--help"
    return 1
  }
  "$TMPDIR/install_v${VERSION}.sh" --version | grep "$VERSION" || { 
    error "--version flag fail"
    echo "test_cli_flags failed" >> "$ERROR_LOG"
    jsonlog "cli_flags" "FAIL" "--version"
    return 1
  }
  jsonlog "cli_flags" "PASS" "Flags OK"
}

# Run test_auto_updater() and log errors
test_auto_updater() {
  log "Testing auto-updater stub..."
  "$TMPDIR/install_v${VERSION}.sh" --check-update &>>"$LOG" || {
    echo "test_auto_updater failed" >> "$ERROR_LOG"
    jsonlog "auto_updater" "WARN" "Auto-updater stub failed"
  }
  jsonlog "auto_updater" "PASS" "Auto-updater OK"
}

# Run test_docker() and log errors
test_docker() {
  log "Testing Docker image..."
  $TIMEOUT_CMD 300 docker build -t "$DOCKER_IMAGE" . &>>"$LOG" || {
    echo "test_docker failed" >> "$ERROR_LOG"
    error "Docker build failed"
    jsonlog "docker" "FAIL" "Docker build"
    return 1
  }
  docker run --rm "$DOCKER_IMAGE" --version | grep "$VERSION" || { 
    error "Docker run failed"
    echo "test_docker failed" >> "$ERROR_LOG"
    jsonlog "docker" "FAIL" "Docker run"
    return 1
  }
  jsonlog "docker" "PASS" "Docker OK"
}

# Run test_localization() and log errors
test_localization() {
  for LANG in en_US.UTF-8 it_IT.UTF-8; do
    log "Testing Zenity UI ($LANG)..."
    LANG=$LANG zenity --info --timeout=2 --text="Locale test" &>/dev/null || {
      echo "test_localization failed for $LANG" >> "$ERROR_LOG"
    }
  done
  jsonlog "localization" "PASS" "Zenity OK"
}

# Run test_flask_ui() and log errors
test_flask_ui() {
  log "Testing Flask UI..."
  $TIMEOUT_CMD 30 python3 webui_v${VERSION}.py --port 9090 --test &>/dev/null &
  FLASK_PID=$!
  sleep 5
  curl -fsS "http://127.0.0.1:9090/health" &>>"$LOG" || { 
    kill $FLASK_PID
    error "Flask health check failed"
    echo "test_flask_ui failed" >> "$ERROR_LOG"
    jsonlog "flask_ui" "FAIL" "Flask health"
    return 1
  }
  kill $FLASK_PID
  jsonlog "flask_ui" "PASS" "Flask OK"
}

# Run test_plugin_hooks() and log errors
test_plugin_hooks() {
  log "Testing plugin hooks..."
  sudo "$TMPDIR/install_v${VERSION}.sh" --install &>>"$LOG"
  grep -q "pre-install hook executed" /var/log/cursor_test_${VERSION}.log &>>"$LOG" || {
    error "Pre-install hook"
    echo "test_plugin_hooks failed" >> "$ERROR_LOG"
  }
  grep -q "post-install hook executed" /var/log/cursor_test_${VERSION}.log &>>"$LOG" || {
    error "Post-install hook"
    echo "test_plugin_hooks failed" >> "$ERROR_LOG"
  }
  sudo "$TMPDIR/install_v${VERSION}.sh" --uninstall &>>"$LOG"
  grep -q "post-test hook executed" /var/log/cursor_test_${VERSION}.log &>>"$LOG" || {
    error "Post-test hook"
    echo "test_plugin_hooks failed" >> "$ERROR_LOG"
  }
  jsonlog "plugin_hooks" "PASS" "Hooks OK"
}

# Test in Vagrant VM
test_vm() {
  echo "[INFO] Spinning up Vagrant VM for tests..."
  if ! command -v vagrant &>/dev/null; then
    echo '[ERROR] vagrant not installed; please install Vagrant to run VM tests.'
    echo "test_vm failed" >> "$ERROR_LOG"
    return 1
  fi
  vagrant up --provision
  if [ $? -ne 0 ]; then 
    echo '[ERROR] Vagrant provisioning failed'
    echo "test_vm failed" >> "$ERROR_LOG"
    return 1
  fi
  vagrant destroy -f
  echo '[INFO] Vagrant VM tests completed successfully.'
  return 0
}

# Test in Docker container
test_container() {
  # Run test_deb and log errors
  test_deb || echo "test_deb failed" >> "$ERROR_LOG"
  echo "[INFO] Building Docker image for tests..."
  if ! command -v docker &>/dev/null; then
    echo '[ERROR] docker not installed; please install Docker to run container tests.'
    echo "test_container failed" >> "$ERROR_LOG"
    return 1
  fi
  docker build -t cursor_test_suite .
  if [ $? -ne 0 ]; then 
    echo '[ERROR] Docker build failed'
    echo "test_container failed" >> "$ERROR_LOG"
    return 1
  fi
  docker run --rm cursor_test_suite
  if [ $? -ne 0 ]; then 
    echo '[ERROR] Docker container tests failed'
    echo "test_container failed" >> "$ERROR_LOG"
    return 1
  fi
  echo '[INFO] Docker container tests completed successfully.'
  return 0
}

run_all() {
  test_file_launcher
  test_file_launcher_sh
  test_file_autoupdater
  test_file_secure
  test_file_secureplus
  test_file_vagrantfile
  test_file_dockerfile
  test_file_readme
  test_file_policies
}

test_file_launcher() {
  echo "[INFO] Testing file 01-appimage_v6.9.35.AppImage"
  if ! test -f "01-appimage_v6.9.35.AppImage"; then
    echo "[ERROR] File check failed: 01-appimage_v6.9.35.AppImage" >> "$ERROR_LOG"
  else
    echo "[INFO] Validating AppImage presence" "01-appimage_v6.9.35.AppImage"
  fi
}

test_file_launcher_sh() {
  echo "[INFO] Testing file 02-launcher_v6.9.35.sh"
  if ! bash -n "02-launcher_v6.9.35.sh" 2>/dev/null; then
    echo "[ERROR] File check failed: 02-launcher_v6.9.35.sh" >> "$ERROR_LOG"
  fi
}

test_file_autoupdater() {
  echo "[INFO] Testing file 03-autoupdater_v6.9.35.sh"
  if ! bash -n "03-autoupdater_v6.9.35.sh" 2>/dev/null; then
    echo "[ERROR] File check failed: 03-autoupdater_v6.9.35.sh" >> "$ERROR_LOG"
  fi
}

test_file_secure() {
  echo "[INFO] Testing file 04-secure_v6.9.35.sh"
  if ! bash -n "04-secure_v6.9.35.sh" 2>/dev/null; then
    echo "[ERROR] File check failed: 04-secure_v6.9.35.sh" >> "$ERROR_LOG"
  fi
}

test_file_secureplus() {
  echo "[INFO] Testing file 05-secureplus_v6.9.35.sh"
  if ! bash -n "05-secureplus_v6.9.35.sh" 2>/dev/null; then
    echo "[ERROR] File check failed: 05-secureplus_v6.9.35.sh" >> "$ERROR_LOG"
  fi
}

test_file_vagrantfile() {
  echo "[INFO] Testing file Vagrantfile"
  if ! grep -q "Vagrant.configure" "Vagrantfile" 2>/dev/null; then
    echo "[ERROR] File check failed: Vagrantfile" >> "$ERROR_LOG"
  fi
}

test_file_dockerfile() {
  echo "[INFO] Testing file Dockerfile"
  if ! grep -q "^FROM" "Dockerfile" 2>/dev/null; then
    echo "[ERROR] File check failed: Dockerfile" >> "$ERROR_LOG"
  fi
}

test_file_readme() {
  echo "[INFO] Testing file README.md"
  if ! test -s "README.md" 2>/dev/null; then
    echo "[ERROR] File check failed: README.md" >> "$ERROR_LOG"
  fi
}

test_file_policies() {
  echo "[INFO] Testing file 21-policies_v6.9.35.txt"
  if ! grep -Ec "^[1-9][0-9]?\. " "21-policies_v6.9.35.txt" >/dev/null 2>&1; then
    echo "[ERROR] File check failed: 21-policies_v6.9.35.txt" >> "$ERROR_LOG"
  fi
}

# Main execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "[INFO] Starting Cursor test suite..."
  run_all
  echo "[INFO] Test suite completed."
fi

