#!/usr/bin/env bash
set -euo pipefail
echo "Running coverage…"
pytest --cov=src --cov-report=xml --cov-report=html
echo "Coverage XML → coverage.xml, HTML → htmlcov/"
