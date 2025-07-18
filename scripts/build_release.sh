#!/usr/bin/env bash
set -euo pipefail
# Simple release script: create a tarball of the project
VERSION=$(cat VERSION)
RELEASE_DIR="dist"
mkdir -p "$RELEASE_DIR"
tar -czf "$RELEASE_DIR/cursor_bundle_v$VERSION.tar.gz" --exclude='dist' .
echo "Created release archive at $RELEASE_DIR/cursor_bundle_v$VERSION.tar.gz"
