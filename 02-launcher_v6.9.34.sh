#!/usr/bin/env bash
# 02-launcher_v6.9.34.sh — wrapper for the unified launcher
#
# This thin wrapper exists to satisfy test suites expecting a
# versioned launcher script without a suffix.  It simply delegates
# all arguments to the fixed implementation.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/02-launcher_v6.9.34_fixed.sh" "$@"