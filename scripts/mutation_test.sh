#!/usr/bin/env bash
# Run mutation tests on Python code using mutmut. Ensure mutmut is installed.
# Generates mutation_report.txt summarising the results.
set -euo pipefail

REPORT="mutation_report.txt"
rm -f "$REPORT"

if ! command -v mutmut >/dev/null 2>&1; then
  echo "mutmut is not installed; please install via pip (pip install mutmut)" | tee "$REPORT"
  exit 0
fi

# Run mutmut (this may take time)
echo "Running mutmut..." | tee "$REPORT"
mutmut run || true

# Generate summary
mutmut results | tee -a "$REPORT"
echo "Mutation testing complete. See $REPORT for details."
