#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# tracker_v6.9.35.sh
# Tracks function names and confirms script completeness for Cursor v6.9.35
# ============================================================================

log() { echo "[Tracker] $*"; }

TARGET_DIR="$(dirname "${BASH_SOURCE[0]}")"

log "Scanning for shell function definitions..."

mapfile -t FILES < <(find "$TARGET_DIR" -maxdepth 1 -type f -name "*.sh" ! -name "*tracker*" ! -name "*test*")

declare -A FUNCTION_MAP

for f in "${FILES[@]}"; do
name=$(basename "$f")
log "Checking $name"
while read -r line; do
if [[ $line =~ ^[[:space:]]*([a-zA-Z0-9_]+)[[:space:]]*\(\)[[:space:]]*\{ ]]; then
fn="${BASH_REMATCH[1]}"
FUNCTION_MAP["$fn"]+="$name "
fi
done < "$f"
done

log ""
log "Detected functions:"
for fn in "${!FUNCTION_MAP[@]}"; do
echo " - $fn (in ${FUNCTION_MAP[$fn]})"
done

log ""
log "Checking for unused internal functions..."

MISSING_USAGE=()

for fn in "${!FUNCTION_MAP[@]}"; do
used=false
for f in "${FILES[@]}"; do
if grep -q "[^a-zA-Z0-9_]$fn[^a-zA-Z0-9_]" "$f"; then
used=true
break
fi
done
if ! $used; then
MISSING_USAGE+=("$fn")
fi
done

if [[ ${#MISSING_USAGE[@]} -eq 0 ]]; then
  log "✅ All internal functions are referenced."
else
  # Do not treat unused functions as warnings; simply log them for reference.
  log "Note: the following internal functions are not referenced by other scripts:"
  for fn in "${MISSING_USAGE[@]}"; do
    echo "   - $fn"
  done
fi

log ""
log "Verifying 17-policycheck_v6.9.35_fixed.sh presence..."

POLICY_SCRIPT="$TARGET_DIR/17-policycheck_v6.9.35_fixed.sh"

if [[ ! -f "$POLICY_SCRIPT" ]]; then
echo "[ERROR] 17-policycheck_v6.9.35_fixed.sh is missing"
exit 2
fi

log "Loading internal file policy..."
mapfile -t INTERNAL < <(grep -E '^ *"' "$POLICY_SCRIPT" | sed 's/^[[:space:]]*"//' | sed 's/"$//' | grep -v '^#')

log "Verifying presence of all internal files..."
MISSING_FILES=()

for file in "${INTERNAL[@]}"; do
if [[ ! -f "$TARGET_DIR/$file" ]]; then
MISSING_FILES+=("$file")
fi
done

if [[ ${#MISSING_FILES[@]} -eq 0 ]]; then
log "✅ All internal files present."
else
echo "[ERROR] Missing files:"
for file in "${MISSING_FILES[@]}"; do
echo "   - $file"
done
exit 3
fi

log ""
log "Confirming .version matches v6.9.35..."

VERSION_FILE="$TARGET_DIR/.version"
if [[ ! -f "$VERSION_FILE" ]]; then
echo "[ERROR] .version file missing"
exit 4
fi

VERSION_STR=$(cat "$VERSION_FILE")
if [[ "$VERSION_STR" != "v6.9.35" ]]; then
echo "[ERROR] Version mismatch: $VERSION_STR"
exit 5
fi

log "✅ Version file validated."

log "All tracker tests passed."

exit 0