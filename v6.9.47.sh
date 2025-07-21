#!/usr/bin/env bash
# v6.9.58.sh
#
# Purpose
# -------
# • Bump project from 6.9.46 → 6.9.58
# • Remove *all* obsolete or duplicate artefacts, leaving exactly one copy per
#   logical file (the latest, suffixed _v6.9.58) and deleting superseded logs,
#   tarballs, reports, etc.
# • Eliminate “missing‑file” warnings by updating version strings *before* any
#   renames, and by checking each path exists before operating on it.
# • Run a quick lint check (Ruff for Python, ShellCheck for Bash) and store
#   results in `lint_report_v6.9.58.txt`.
# • Commit and tag locally (no automatic push).
#
# Safe to re‑run: skips moves if src=dst, skips deletes if file already gone.

set -euo pipefail
shopt -s globstar nullglob

OLD_VERSION="6.9.46"
NEW_VERSION="6.9.58"
REPO_DIR="${1:-$HOME/Downloads/cursor_bundle_v6.9.32}"
REPORT="cleanup_report_v${NEW_VERSION}.txt"
LINT="lint_report_v${NEW_VERSION}.txt"

echo "→ Working in $REPO_DIR"
[[ -d "$REPO_DIR" ]] || { echo "Repo not found"; exit 1; }
cd "$REPO_DIR"

git init -q 2>/dev/null || true
git config user.name  >/dev/null 2>&1 || git config user.name  "Automation"
git config user.email >/dev/null 2>&1 || git config user.email "automation@example.com"

: > "$REPORT"

###############################################################################
# 1. Update version strings *first* to avoid Perl missing‑file warnings later.
###############################################################################
echo "→ Updating version strings inside files …"
FILES=$(git ls-files '*.sh' '*.py' '*.json' '*.md' '*.txt' '*.yml' '*.yaml' || true)
if [[ -n $FILES ]]; then
  perl -pi -e "s/\Q$OLD_VERSION\E/$NEW_VERSION/g" $FILES
  echo "ver  updated text files" >>"$REPORT"
fi
echo "$NEW_VERSION" > VERSION

###############################################################################
# 2. Remove obsolete duplicate artefacts (common older suffixes).
###############################################################################
echo "→ Removing obsolete artefacts/logs …"
find . -type f \( -name "*_v6.9.3[5-9]*" -o -name "*_v6.9.4[0-6]*" \) | while read -r f; do
  rm -f "$f" && echo "rm   $f" >>"$REPORT"
done

###############################################################################
# 3. Ensure exactly one artefact/log with _vNEW_VERSION suffix.
###############################################################################
suffix_file() {
  local p="$1" stem ext new
  stem="${p%.*}"; ext="${p##*.}"
  [[ $stem == *_v$NEW_VERSION ]] && return
  new="${stem}_v$NEW_VERSION.$ext"
  [[ -e $new ]] && { rm -f "$p"; echo "dup  removed $p" >>"$REPORT"; return; }
  mv "$p" "$new"
  echo "mv   $p → $new" >>"$REPORT"
}

for dir in . dist logs perf; do
  [[ -d $dir ]] || continue
  for f in "$dir"/**/*.{log,txt,json,gz,tgz,tar.gz}; do
    [[ -f $f ]] && suffix_file "$f"
  done
done

###############################################################################
# 4. Quick lint pass (Ruff & ShellCheck)
###############################################################################
: > "$LINT"
echo "→ Running lint (Ruff + ShellCheck)…"
if command -v ruff >/dev/null 2>&1; then
  ruff check $(git ls-files '*.py') >>"$LINT" 2>&1 || true
else
  echo "Ruff not installed." >>"$LINT"
fi
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck $(git ls-files '*.sh') >>"$LINT" 2>&1 || true
else
  echo "ShellCheck not installed." >>"$LINT"
fi
echo "lint report saved to $LINT" >>"$REPORT"

###############################################################################
# 5. Policies update
###############################################################################
cat > "21-policies_v$NEW_VERSION.txt" <<EOF
# Policies v$NEW_VERSION
* There must be only one artefact/log per logical file, named *_v$NEW_VERSION.*
* Older duplicates (_v6.9.35‑46) are deleted during upgrade.
* Lint report stored at $LINT; CI must fail on critical issues.
* Script re‑runnable; pushes done manually after review.
EOF
echo "new  21-policies_v$NEW_VERSION.txt" >>"$REPORT"

###############################################################################
# 6. Commit & tag
###############################################################################
git add .
if git diff --cached --quiet; then
  echo "✓ Nothing to commit."
else
  git commit -m "chore: full cleanup & bump to v$NEW_VERSION (one artefact per version)"
  echo "✓ Commit created."
fi
git rev-parse -q --verify refs/tags/v$NEW_VERSION >/dev/null || git tag "v$NEW_VERSION"

###############################################################################
# 7. Summary
###############################################################################
echo "→ Cleanup summary"
cat "$REPORT"
echo -e "\nPush with:  git push origin main --follow-tags"
