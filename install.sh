#!/usr/bin/env bash
# install.sh — wrapper script for Cursor installer
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Try to find the best available install script
if [ -f "$DIR/14-install-improved-v2.sh" ]; then
    exec bash "$DIR/14-install-improved-v2.sh" "$@"
elif [ -f "$DIR/14-install-improved.sh" ]; then
    exec bash "$DIR/14-install-improved.sh" "$@"
elif [ -f "$DIR/14-install_fixed.sh" ]; then
    exec bash "$DIR/14-install_fixed.sh" "$@"
else
    echo "Error: No install script found!"
    echo "Available scripts:"
    ls -la "$DIR"/14-install* 2>/dev/null || echo "  None found"
    exit 1
fi
