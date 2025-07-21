#!/usr/bin/env bash
# Test harness that runs enhanced and fixed test suites for the current version.
# Produces an error report and exits non-zero if any suite fails.
set -euo pipefail
VERSION=$(cat VERSION)
REPORT="error_report_v${VERSION}.txt"
rm -f "$REPORT"

run_suite() {
  local suite="$1"
  if [[ -x "$suite" ]]; then
    echo "Running $suite..." | tee -a "$REPORT"
    if "./$suite" >>"$REPORT" 2>&1; then
      echo "$suite passed." | tee -a "$REPORT"
    else
      echo "$suite FAILED." | tee -a "$REPORT"
      return 1
    fi
  else
    echo "$suite not found or not executable." | tee -a "$REPORT"
  fi
}

status=0
run_suite "22-test_cursor_suite_v${VERSION}_enhanced.sh" || status=1
run_suite "22-test_cursor_suite_v${VERSION}_fixed.sh" || status=1

if [[ $status -ne 0 ]]; then
  echo "One or more test suites failed. See $REPORT for details." >&2
  exit 1
fi

echo "All test suites passed." >>"$REPORT"
echo "Test harness completed."
