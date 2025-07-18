#!/usr/bin/env bash
set -euo pipefail
# Simple logging functions
log_info()  { echo "[INFO ] $*"; }
log_warn()  { echo "[WARN ] $*" >&2; }
log_error() { echo "[ERROR] $*" >&2; }
