#!/usr/bin/env bash
# v6.9.58.sh  (fixed)
#
# Bump 6.9.45 → 6.9.58 **and** normalise every path.
# – Moves old upgrade scripts to scripts/upgrades/  (kept as‑is)
# – Renames files containing 6.9.45 → 6.9.58
# – Removes stray 6.9.(35‑44) fragments
# – Appends _v6.9.58 suffix to logs / artefacts lacking it
# – Generates rename_report_v6.9.58.txt
#
# Re‑run safely; skips mv when src == dst and ignores scripts/upgrades/*
# No auto‑push.

set -euo pipefail
shopt -s globstar nullglob

OLD_VERSION="6.9.45"
NEW_VERSION="6.9.58"
REPO_DIR="${1:-$HOME/Downloads/cursor_bundle_v6.9.32}"
REPORT="rename_report_v${NEW_VERSION}.txt"

echo "→ Working in $REPO_DIR"
[[ -d $REPO_DIR ]] || { echo "Repo not found"; exit 1; }
cd "$REPO_DIR"

git init -q 2>/dev/null || true
git config user.name  >/dev/null 2>&1 || git config user.name  "Automation"
git config user.email >/dev/null 2>&1 || git config user.email "automation@example.com"

: > "$REPORT"

########################################################################
# 1. Move historical upgrade scripts (only once)
########################################################################
mkdir -p scripts/upgrades
for s in v[0-9]*.[0-9]*.[0-9]*.sh; do
  [[ -f $s ]] || continue
  [[ $s == scripts/upgrades/* ]] && continue
  mv "$s" scripts/upgrades/ && echo "move  $s → scripts/upgrades/" >>"$REPORT"
done

########################################################################
# 2. Rename paths containing OLD_VERSION → NEW_VERSION
########################################################################
echo "→ Renaming paths $OLD_VERSION → $NEW_VERSION"
for p in **/*"$OLD_VERSION"*; do
  [[ -e $p ]] || continue
  [[ $p == scripts/upgrades/* ]] && continue
  np="${p//$OLD_VERSION/$NEW_VERSION}"
  [[ $np == "$p" ]] && continue
  mkdir -p "$(dirname "$np")"
  mv "$p" "$np"
  echo "ren   $p → $np" >>"$REPORT"
done

########################################################################
# 3. Strip obsolete version fragments (6.9.35‑6.9.44) except in upgrades
########################################################################
OBSOLETE_RE='6\.9\.(3[5-9]|4[0-4])'
echo "→ Cleaning obsolete fragments"
for p in **/*; do
  [[ -f $p || -d $p ]] || continue
  [[ $p == scripts/upgrades/* ]] && continue
  if [[ $p =~ $OBSOLETE_RE ]]; then
    np=$(echo "$p" | sed -E "s/_?v?$OBSOLETE_RE//g")
    [[ $np == "$p" ]] && continue
    mkdir -p "$(dirname "$np")"
    mv "$p" "$np"
    echo "clean $p → $np" >>"$REPORT"
  fi
done

########################################################################
# 4. Ensure artefacts/logs end with _vNEW_VERSION
########################################################################
suffix () {
  local path="$1" stem ext new
  [[ -f $path ]] || return
  stem="${path%.*}"
  ext="${path##*.}"
  [[ $stem == *_v$NEW_VERSION ]] && return
  new="${stem}_v$NEW_VERSION.$ext"
  mv "$path" "$new"
  echo "suff  $path → $new" >>"$REPORT"
}
for f in **/*.{log,txt,json,gz,tgz,tar.gz}; do suffix "$f"; done

########################################################################
# 5. Update version strings inside files
########################################################################
FILES=$(git ls-files '*.sh' '*.py' '*.json' '*.md' '*.txt' '*.yml' '*.yaml' || true)
[[ -n $FILES ]] && perl -pi -e "s/\Q$OLD_VERSION\E/$NEW_VERSION/g" $FILES || true
echo "$NEW_VERSION" > VERSION

########################################################################
# 6. Policies
########################################################################
cat > "21-policies_v$NEW_VERSION.txt" <<EOF
# Policies v$NEW_VERSION
* Every artefact/log ends with _v$NEW_VERSION.<ext>
* Old upgrade scripts live in scripts/upgrades/ unchanged.
* Script can be re‑run safely; skips duplicate moves.
* Push manually after verification.
EOF
echo "new   21-policies_v$NEW_VERSION.txt" >>"$REPORT"

########################################################################
# 7. Commit & tag
########################################################################
git add .
if git diff --cached --quiet; then
  echo "✓ Nothing to commit."
else
  git commit -m "chore: path cleanup & bump to v$NEW_VERSION"
  echo "✓ Commit created."
fi
git rev-parse -q --verify refs/tags/v$NEW_VERSION >/dev/null || git tag "v$NEW_VERSION"

echo "→ Rename summary"
cat "$REPORT"
echo -e "\nPush with:  git push origin main --follow-tags"
