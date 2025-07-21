#!/usr/bin/env bash
# Usage: suffix_version <file> <version>
# Renames <file> to *_v<version>.<ext>.  Skips if suffix already present.
set -euo pipefail
f="$1"; v="$2"
[[ -f $f ]] || exit 1
base=$(basename "$f")
[[ $base == *_v"$v"* ]] && exit 0
ext="${base##*.}"
mv "$f" "${f%.*}_v${v}.${ext}"
