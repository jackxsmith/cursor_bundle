#!/usr/bin/env bash
# v6.9.45.sh
#
# 1. Bump Cursor bundle from 6.9.44 → 6.9.45
# 2. Enforce “version‑in‑filename” rigor:
#    • Every file in the repo whose name already contains ANY 6.9.X string
#      is renamed to _v6.9.45.{ext}  (unless it’s an old upgrade script v6.9.*.sh).
#    • All *.log, *.txt, *.tar.*, *.json, *.gz in dist/, logs/, perf/, root
#      are given a _v6.9.45 suffix if they lack one.
# 3. Adds a helper `scripts/version_suffix.sh` to append the current version
#    to any filename (other scripts can `source` it).
# 4. Makefile target `sanitize-names` to apply suffixing in future.
# 5. Updates policies, commits, tags locally.  No automatic push.

set -euo pipefail

OLD_VERSION="6.9.44"
NEW_VERSION="6.9.45"
REPO_DIR="${1:-$HOME/Downloads/cursor_bundle_v6.9.32}"

echo "→ Working in $REPO_DIR"
[[ -d "$REPO_DIR" ]] || { echo "Repo not found"; exit 1; }
cd "$REPO_DIR"

git init -q 2>/dev/null || true
git config user.name  >/dev/null 2>&1 || git config user.name  "Automation"
git config user.email >/dev/null 2>&1 || git config user.email "automation@example.com"

################################################################################
echo "→ Phase 1: rename files containing $OLD_VERSION → $NEW_VERSION …"
shopt -s globstar nullglob
for f in **/*"$OLD_VERSION"*; do
  [[ -f $f ]] || continue
  case "$f" in
    v*.sh) continue ;;  # keep historical upgrade scripts unchanged
  esac
  nf="${f//$OLD_VERSION/$NEW_VERSION}"
  [[ $nf == "$f" ]] || { mkdir -p "$(dirname "$nf")"; mv "$f" "$nf"; echo "  $f → $nf"; }
done
shopt -u globstar nullglob

################################################################################
echo "→ Phase 2: change version strings inside files …"
FILES=$(git ls-files '*.sh' '*.py' '*.json' '*.md' '*.txt' '*.yml' '*.yaml' || true)
[[ -n $FILES ]] && perl -pi -e "s/\Q$OLD_VERSION\E/$NEW_VERSION/g" $FILES || true
echo "$NEW_VERSION" > VERSION

################################################################################
echo "→ Phase 3: suffixing artefacts & logs lacking _v$NEW_VERSION …"
suffix_file() {
  local p=$1 base ext new
  base=$(basename "$p")
  [[ $base == *"_v$NEW_VERSION"* ]] && return
  ext="${base##*.}"
  new="${p%/*}/${base%.*}_v$NEW_VERSION.$ext"
  mv "$p" "$new"
  echo "  $p → $new"
}

for dir in . dist logs perf; do
  [[ -d $dir ]] || continue
  shopt -s nullglob
  for p in "$dir"/*.{log,txt,json,gz,tar.gz}; do [[ -f $p ]] && suffix_file "$p"; done
  shopt -u nullglob
done

################################################################################
echo "→ Phase 4: helper script & Makefile target …"
mkdir -p scripts
cat > scripts/version_suffix.sh <<'EOS'
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
EOS
chmod +x scripts/version_suffix.sh

grep -q '^sanitize-names:' Makefile 2>/dev/null || cat >> Makefile <<'MAKE'

sanitize-names:
	@echo "Suffixing artefacts in dist/, logs/, perf/ with current VERSION …"
	@bash scripts/version_suffix.sh
MAKE

################################################################################
echo "→ Phase 5: policies update …"
cat > "21-policies_v$NEW_VERSION.txt" <<EOF
# Policies v$NEW_VERSION
* All artefacts (.log, .txt, .json, .tar.gz, etc.) must carry *_vX.Y.Z* in filename.
* Historical upgrade scripts (v*.sh) remain unchanged.
* Use \`make sanitize-names\` or \`scripts/version_suffix.sh\` for future files.
* This upgrade bumps to v$NEW_VERSION; run script without sudo, then push.
EOF

################################################################################
echo "→ Committing & tagging …"
git add .
if git diff --cached --quiet; then
  echo "✓ Nothing to commit."
else
  git commit -m "chore: enforce version suffixes on artefacts & bump to v$NEW_VERSION"
  echo "✓ Commit created."
fi

if git rev-parse -q --verify refs/tags/v$NEW_VERSION >/dev/null; then
  echo "✓ Tag v$NEW_VERSION already exists."
else
  git tag "v$NEW_VERSION"
  echo "✓ Tag v$NEW_VERSION created."
fi

echo -e "\nUpgrade complete. Review, then push:\n  git push origin main --follow-tags"
