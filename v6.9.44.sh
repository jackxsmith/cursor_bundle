#!/usr/bin/env bash
# v6.9.45.sh
# Bump Cursor bundle from 6.9.43 → 6.9.45 **and**
# normalise file‑naming so every generated artefact embeds the version
# as  _vX.Y.Z.{ext}.  Also skips renaming previous upgrade scripts, so
# history stays intact.  Commits + tags locally; no auto‑push.

set -euo pipefail

OLD_VERSION="6.9.43"
NEW_VERSION="6.9.45"
REPO_DIR="${1:-$HOME/Downloads/cursor_bundle_v6.9.32}"

echo "→ Working in $REPO_DIR"
[[ -d $REPO_DIR ]] || { echo "Repo not found"; exit 1; }
cd "$REPO_DIR"

git init -q 2>/dev/null || true
git config user.name  >/dev/null 2>&1 || git config user.name  "Automation"
git config user.email >/dev/null 2>&1 || git config user.email "automation@example.com"

###############################################################################
# 1  Rename artefacts that still carry the old version number
###############################################################################
echo "→ Renaming artefact files $OLD_VERSION → $NEW_VERSION …"
shopt -s globstar nullglob
for f in **/*"$OLD_VERSION"*; do
  [[ -f $f ]] || continue
  case "$f" in
    v*.sh)     continue ;;               # leave old upgrade scripts untouched
  esac
  nf="${f//$OLD_VERSION/$NEW_VERSION}"
  [[ $nf == "$f" ]] || { mkdir -p "$(dirname "$nf")"; mv "$f" "$nf"; echo "  $f → $nf"; }
done
shopt -u globstar nullglob

###############################################################################
# 2  Update version strings in tracked text files
###############################################################################
echo "→ Updating version strings …"
FILES=$(git ls-files '*.sh' '*.py' '*.json' '*.md' '*.txt' '*.yml' '*.yaml' || true)
[[ -n $FILES ]] && perl -pi -e "s/\Q$OLD_VERSION\E/$NEW_VERSION/g" $FILES || true
echo "$NEW_VERSION" > VERSION

###############################################################################
# 3  Ensure new version‑specific filenames for generated artefacts
###############################################################################
mkdir -p dist perf logs

# Example: rename dist/release.txt → dist/release_v6.9.45.txt
for artefact in dist/*; do
  [[ -f $artefact ]] || continue
  base=$(basename "$artefact")
  [[ $base == *_v$NEW_VERSION* ]] && continue
  ext="${base##*.}"
  new="dist/${base%.*}_v$NEW_VERSION.$ext"
  mv "$artefact" "$new"
  echo "  dist artefact renamed → $(basename "$new")"
done

# Rotate previous logs
for l in error_report perf/perf_report static_analysis dynamic_security; do
  for ext in txt log; do
    [[ -f "$l.$ext" ]] && mv "$l.$ext" "${l}_v$NEW_VERSION.$ext"
  done
done

###############################################################################
# 4  Write new policies file
###############################################################################
cat > "21-policies_v$NEW_VERSION.txt" <<EOF
# Policies v$NEW_VERSION
* All generated artefacts **must** include the exact version in their filename:
  - error_report_v$NEW_VERSION.txt
  - static_analysis_v$NEW_VERSION.log
  - sbom_v$NEW_VERSION.json
  - release_v$NEW_VERSION.tar.gz
* Upgrade scripts keep historical names (v6.9.43.sh, v6.9.45.sh, …) and are not renamed.
* Script runs without sudo; review, then push with:
    git push origin main --follow-tags
EOF

###############################################################################
# 5  Stage, commit, tag
###############################################################################
echo "→ Staging & committing …"
git add .
if git diff --cached --quiet; then
  echo "✓ Nothing to commit."
else
  git commit -m "chore: normalise artefact names & bump to v$NEW_VERSION"
  echo "✓ Commit created."
fi

if git rev-parse -q --verify refs/tags/v$NEW_VERSION >/dev/null; then
  echo "✓ Tag v$NEW_VERSION already exists."
else
  git tag "v$NEW_VERSION"
  echo "✓ Tag v$NEW_VERSION created."
fi

echo -e "\nDone. Push with:\n  git push origin main --follow-tags"
