#!/usr/bin/env bash
# Generate code coverage reports using pytest-cov. Requires pytest and pytest-cov.
# Produces coverage.xml and htmlcov directory.
set -euo pipefail

if ! command -v pytest >/dev/null 2>&1; then
  echo "pytest is not installed; please install via pip (pip install pytest pytest-cov)"
  exit 0
fi

# Run tests with coverage
echo "Generating coverage report..."
pytest --cov=src --cov-report=xml --cov-report=html || true
echo "Coverage report generated. Files: coverage.xml and htmlcov/index.html"
