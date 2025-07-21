#!/usr/bin/env bash
set -euo pipefail
LOG="mutation_report.txt"
echo "Running mutation tests…" > "$LOG"
if command -v mutmut >/dev/null 2>&1; then
  mutmut run --paths-to-mutate src >>"$LOG" 2>&1
else
  echo "mutmut not installed – skipping" >>"$LOG"
fi
echo "Done. See $LOG."
