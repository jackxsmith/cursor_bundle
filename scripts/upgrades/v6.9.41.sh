#!/usr/bin/env bash
# v6.9.41.sh
# Bump from 6.9.40 → 6.9.41, add Makefile targets,
# print progress, handle empty file list safely.

set -euo pipefail

OLD_VERSION="6.9.40"
NEW_VERSION="6.9.41"

# Determine repo location
REPO_DIR="${1:-$HOME/Downloads/cursor_bundle}"
echo "→ Working in $REPO_DIR"
[[ -d $REPO_DIR ]] || { echo "Repo not found"; exit 1; }
cd "$REPO_DIR"

# Ensure git repo + identity
git init -q 2>/dev/null || true
git config user.name  >/dev/null 2>&1 || git config user.name  "Automation"
git config user.email >/dev/null 2>&1 || git config user.email "automation@example.com"

echo "→ Renaming files containing $OLD_VERSION …"
shopt -s globstar nullglob
for f in **/*"$OLD_VERSION"*; do
  [[ -f $f ]] || continue
  nf="${f//$OLD_VERSION/$NEW_VERSION}"
  if [[ $nf != "$f" ]]; then
    mkdir -p "$(dirname "$nf")"
    mv "$f" "$nf"
    echo "  renamed: $f → $nf"
  fi
done
shopt -u globstar nullglob
echo "✓ File renaming complete."

echo "→ Updating version strings inside tracked files …"
FILES=$(git ls-files '*.sh' '*.py' '*.json' '*.md' '*.txt' '*.yml' '*.yaml' || true)
if [[ -n $FILES ]]; then
  perl -pi -e "s/\Q$OLD_VERSION\E/$NEW_VERSION/g" $FILES
  echo "✓ Version strings updated."
else
  echo "  (no files to update)"
fi
echo "$NEW_VERSION" > VERSION

echo "→ Ensuring Makefile targets …"
if [[ -f Makefile ]] && ! grep -q '^mutation-test:' Makefile; then
cat >> Makefile <<'MAKE'

mutation-test:
	bash scripts/mutation_test.sh

coverage-report:
	bash scripts/generate_coverage.sh
MAKE
  echo "  Added mutation-test and coverage-report targets."
fi

echo "→ Writing policies file …"
cat > "21-policies_v$NEW_VERSION.txt" <<'EOF'
# Policies v6.9.41
* Upgrade scripts must follow vX.Y.Z.sh naming.
* Makefile must have `mutation-test` and `coverage-report` targets.
* Run without sudo; push manually after verifying CI.
EOF

echo "→ Staging changes …"
git add .

if git diff --cached --quiet; then
  echo "✓ No changes to commit."
else
  git commit -m "feat: upgrade to v$NEW_VERSION with mutation‑test & coverage targets"
  echo "✓ Commit created."
fi

if git rev-parse -q --verify "refs/tags/v$NEW_VERSION" >/dev/null; then
  echo "✓ Tag v$NEW_VERSION already exists."
else
  git tag "v$NEW_VERSION"
  echo "✓ Tag v$NEW_VERSION created."
fi

echo -e "\nAll done. Review locally, then push:\n  git push origin main --follow-tags"
