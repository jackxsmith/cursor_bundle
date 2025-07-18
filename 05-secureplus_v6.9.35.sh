#!/usr/bin/env bash
# 05-secureplus_v6.9.35.sh — wrapper for the secure-plus launcher

# Delegate execution to the actual fixed implementation.  This wrapper
# exists to satisfy legacy test suites that look for the filename
# without the `_fixed` suffix.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$DIR/05-secureplus_v6.9.35_fixed.sh" "$@"