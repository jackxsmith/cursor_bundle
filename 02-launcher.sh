#!/usr/bin/env bash
# 02-launcher.sh — wrapper for the unified launcher
#
# This thin wrapper exists to satisfy test suites expecting a
# versioned launcher script without a suffix.  It simply delegates
# all arguments to the best available implementation.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try to find the best available launcher script
if [ -f "$DIR/02-launcher-improved-v2.sh" ]; then
    exec "$DIR/02-launcher-improved-v2.sh" "$@"
elif [ -f "$DIR/02-launcher-improved.sh" ]; then
    exec "$DIR/02-launcher-improved.sh" "$@"
elif [ -f "$DIR/02-launcher_fixed.sh" ]; then
    exec "$DIR/02-launcher_fixed.sh" "$@"
else
    echo "Error: No launcher script found!"
    echo "Available scripts:"
    ls -la "$DIR"/02-launcher* 2>/dev/null || echo "  None found"
    exit 1
fi