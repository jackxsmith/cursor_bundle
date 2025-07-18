#!/usr/bin/env bash
# 03-autoupdater_v6.9.32.sh — wrapper for the auto-updater
#
# Provides a minimal command-line interface for checking updates.  This
# wrapper simply calls the fixed implementation which reports that no
# updates are available.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/03-autoupdater_v6.9.32_fixed.sh" "$@"