#!/usr/bin/env bash
# Sign every file in dist/ with GPG (detached ASCII).
set -euo pipefail
for f in dist/*; do
  [[ -f $f ]] || continue
  gpg --armor --batch --yes --output "${f}.asc" --detach-sig "$f"
done
echo "Artifacts signed."
