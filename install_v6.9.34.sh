#!/usr/bin/env bash
# install_v6.9.34.sh — wrapper script for Cursor installer v6.9.34
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$DIR/14-install_v6.9.34_fixed.sh" "$@"
