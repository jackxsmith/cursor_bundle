#!/usr/bin/env bash
# install_v6.9.33.sh — wrapper script for Cursor installer v6.9.33
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$DIR/14-install_v6.9.33_fixed.sh" "$@"
