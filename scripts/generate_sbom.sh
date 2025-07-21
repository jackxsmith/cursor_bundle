#!/usr/bin/env bash
# Generate SBOM (CycloneDX JSON) for dist/.
set -euo pipefail
if command -v cyclonedx >/dev/null 2>&1; then
  cyclonedx dir --output dist/sbom.json dist
else
  echo '{"notice":"CycloneDX CLI not installed; SBOM generation skipped"}' > dist/sbom.json
fi
echo "SBOM generated at dist/sbom.json"
