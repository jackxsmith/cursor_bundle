#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# tracker_v6.9.34.sh — Enhanced Function Tracker v4 for Cursor Bundle
# ============================================================================

log() { echo "[Tracker] $*"; }
log_error() { echo "[ERROR][Tracker] $*" >&2; }

usage() {
echo "Usage: $0 <directory> [--fix]"
echo "Scans all .sh, .py, and .json files for missing or mismatched functions."
echo "--fix: attempts to auto-repair missing function headers"
exit 1
}

[ $# -lt 1 ] && usage

DIR="$1"
FIX=false
[[ ${2:-} == "--fix" ]] && FIX=true

declare -A FUNC_COUNT
declare -A FILE_MAP

detect_functions() {
local f="$1"
local base
base=$(basename "$f")
local funcs

if [[ $f == *.sh ]]; then
funcs=$(grep -E '^\s*(function )?[a-zA-Z0-9_]+\s*\(\)\s*\{' "$f" | sed -E 's/^\s*(function )?//; s/\s*\(\)\s*\{.*$//')
elif [[ $f == *.py ]]; then
funcs=$(grep -E '^\s*def\s+[a-zA-Z0-9_]+\s*\(' "$f" | sed -E 's/^\s*def\s+//; s/\s*\(.*$//')
elif [[ $f == *.json ]]; then
funcs=$(jq -r 'keys[]' "$f" 2>/dev/null || true)
else
return
fi

for fn in $funcs; do
FUNC_COUNT["$fn"]=$((FUNC_COUNT["$fn"] + 1))
FILE_MAP["$fn"]="$base"
done
}

run_scan() {
log "Scanning files in $DIR..."
while IFS= read -r -d '' file; do
detect_functions "$file"
done < <(find "$DIR" -type f \( -name "*.sh" -o -name "*.py" -o -name "*.json" \) -print0)
}

report_results() {
log "Function summary:"
for fn in "${!FUNC_COUNT[@]}"; do
local count="${FUNC_COUNT[$fn]}"
if [[ $count -gt 1 ]]; then
log_error "Function '$fn' defined multiple times (${count}x) — e.g., ${FILE_MAP[$fn]}"
elif [[ $count -eq 1 ]]; then
log "✅ $fn"
fi
done
}

fix_headers() {
log "Attempting to fix headers..."
while IFS= read -r -d '' file; do
if [[ $file == *.sh ]]; then
sed -i '1{/^#!\/usr\/bin\/env bash/!s/^/#!\/usr\/bin\/env bash\n/}' "$file"
elif [[ $file == *.py ]]; then
sed -i '1{/^#!\/usr\/bin\/env python3/!s/^/#!\/usr\/bin\/env python3\n/}' "$file"
fi
done < <(find "$DIR" -type f \( -name "*.sh" -o -name "*.py" \) -print0)
}

main() {
run_scan
report_results
$FIX && fix_headers
}

main


## New Packaging Policy
- Before creating a new ZIP bundle, update both the tar.gz and .deb artifacts.
- Increment the VERSION in installer and control files accordingly.
- Verify that all artifacts match the version specified in the bundle name.
