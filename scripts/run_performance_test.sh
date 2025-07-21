#!/usr/bin/env bash
set -euo pipefail
LOG=perf/perf_report.txt
mkdir -p perf
echo "Running k6 load test…" > "$LOG"
if command -v k6 >/dev/null 2>&1; then
  k6 run perf/basic_load.js >>"$LOG" 2>&1
else
  echo "k6 not installed – skipping performance test." >>"$LOG"
fi
