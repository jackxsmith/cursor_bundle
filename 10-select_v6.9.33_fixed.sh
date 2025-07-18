#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# select_v6.9.33.sh
# Language selector for Cursor v6.9.33
# ============================================================================

LANG_DIR="/opt/cursor/lang"

log() { echo "[LangSelect] $*"; }

list_languages() {
find "$LANG_DIR" -type f -name '*.json' -exec basename {} .json \;
}

select_language() {
local choice
echo "Available languages:"
mapfile -t langs < <(list_languages)
select choice in "${langs[@]}"; do
if [[ -n "$choice" ]]; then
echo "$choice" > /opt/cursor/.lang
log "Language set to $choice"
return 0
else
log "Invalid selection."
fi
done
}

main() {
mkdir -p "$LANG_DIR"
select_language
}

main "$@"

# Total lines: 43