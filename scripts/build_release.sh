#!/usr/bin/env bash
set -euo pipefail
# Build a tar.gz release archive based on VERSION and output to dist
VERSION=$(cat VERSION)
OUT_DIR="dist"
mkdir -p "$OUT_DIR"
ARCHIVE_NAME="cursor_v${VERSION}.tar.gz"
tar --exclude="$OUT_DIR" -czf "$OUT_DIR/$ARCHIVE_NAME" .
echo "Release created at $OUT_DIR/$ARCHIVE_NAME"
