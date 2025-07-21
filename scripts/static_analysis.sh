#!/usr/bin/env bash
# Run static analysis tools for the Cursor project. Requires ruff and shellcheck
# to be installed in the environment. Additional tools can be integrated as
# needed (e.g. semgrep, bandit). Results are captured in static_analysis.log.
set -euo pipefail

LOG_FILE="static_analysis.log"
rm -f "$LOG_FILE"

echo "Running Ruff (Python linter)..." | tee -a "$LOG_FILE"
if command -v ruff >/dev/null 2>&1; then
  ruff check src scripts >> "$LOG_FILE" 2>&1 || true
else
  echo "Ruff is not installed; skipping Python lint." | tee -a "$LOG_FILE"
fi

echo "Running ShellCheck (Bash linter)..." | tee -a "$LOG_FILE"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck $(git ls-files '*.sh') >> "$LOG_FILE" 2>&1 || true
else
  echo "ShellCheck is not installed; skipping shell lint." | tee -a "$LOG_FILE"
fi

echo "Static analysis complete. Results saved to $LOG_FILE" | tee -a "$LOG_FILE"
