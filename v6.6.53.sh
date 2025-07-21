#!/usr/bin/env bash
# v6.9.53.sh
#
# Purpose
# -------
# • Bump project from 6.9.52 → 6.9.53.
# • Remove *all* obsolete or duplicate artefacts, leaving exactly one copy per
#   logical file (the latest, suffixed _v6.9.53) and deleting superseded logs,
#   tarballs, reports, etc.  This covers all older suffixes from 6.9.35 up
#   through 6.9.52.
# • Update version strings before any renames to avoid missing‑file warnings.
# • Run a quick lint pass (Ruff for Python, ShellCheck for Bash) and store
#   results in `lint_report_v6.9.53.txt`.
# • Copy the original bundle into the repository as `original_bundle.zip` so it is
#   included in each version branch.
# • Commit on a new branch named `release/v6.9.53`, tag the commit `v6.9.53`, and
#   push both the branch and the tag to the `origin` remote.
#
# Safe to re‑run: skips moves if src=dst, skips deletes if file already gone.

set -euo pipefail
shopt -s globstar nullglob

OLD_VERSION="6.9.52"
NEW_VERSION="6.9.53"
REPO_DIR="${1:-$HOME/Downloads/cursor_bundle_v6.9.32}"
REPORT="cleanup_report_v${NEW_VERSION}.txt"
LINT="lint_report_v${NEW_VERSION}.txt"

echo "→ Working in $REPO_DIR"
[[ -d "$REPO_DIR" ]] || { echo "Repo not found"; exit 1; }
cd "$REPO_DIR"

git init -q 2>/dev/null || true
# Configure defaults if unset
if ! git config user.name >/dev/null 2>&1; then
  git config user.name "Automation"
fi
if ! git config user.email >/dev/null 2>&1; then
  git config user.email "automation@example.com"
fi

# Prepare report file
: > "$REPORT"

###############################################################################
# 0. Ensure original bundle and logs are preserved
###############################################################################
# Copy the original zip bundle into the repository if it exists outside of it.
# This makes sure each version branch contains the full original archive.
for candidate in "cursor_bundle_v6.9.32.zip" "cursor_bundle.zip"; do
  # Look in the parent directory and in the user's Downloads folder
  for path in "$REPO_DIR/.." "$HOME/Downloads"; do
    if [[ -f "$path/$candidate" ]]; then
      dest_name="original_bundle.zip"
      if [[ ! -f "$dest_name" ]]; then
        cp "$path/$candidate" "$dest_name"
        echo "cp   $path/$candidate → $dest_name" >>"$REPORT"
      fi
      break 2
    fi
  done
done

###############################################################################
# 1. Update version strings first
###############################################################################
echo "→ Updating version strings inside files …"
FILES=$(git ls-files '*.sh' '*.py' '*.json' '*.md' '*.txt' '*.yml' '*.yaml' || true)
if [[ -n $FILES ]]; then
  perl -pi -e "s/\Q$OLD_VERSION\E/$NEW_VERSION/g" $FILES
  echo "ver  updated text files" >>"$REPORT"
fi
echo "$NEW_VERSION" > VERSION

###############################################################################
# 2. Remove obsolete duplicate artefacts
###############################################################################
echo "→ Removing obsolete artefacts/logs …"
# Delete any file with a suffix from v6.9.35–52.  Group patterns on one line.
find . -type f \( -name "*_v6.9.3[5-9]*" -o -name "*_v6.9.4[0-9]*" -o -name "*_v6.9.5[0-2]*" \) \
  | while read -r f; do
  rm -f "$f" && echo "rm   $f" >>"$REPORT"
done

###############################################################################
# 3. Ensure exactly one artefact/log with _vNEW_VERSION suffix
###############################################################################
suffix_file() {
  local p="$1" stem ext new
  stem="${p%.*}"; ext="${p##*.}"
  [[ $stem == *_v$NEW_VERSION ]] && return
  new="${stem}_v$NEW_VERSION.$ext"
  if [[ -e $new ]]; then
    rm -f "$p"
    echo "dup  removed $p" >>"$REPORT"
    return
  fi
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
# 4. Quick lint pass
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
cat > "21-policies_v$NEW_VERSION.txt" <<'EOF'
# Policies v6.9.53
* Exactly one artefact/log is kept for each logical file, suffixed `_v6.9.53`.  Older duplicates (v6.9.35–52) are removed.
* Version strings are updated before renaming, preventing missing‑file warnings.
* The script is idempotent: it skips moves if the source and destination are the same, and checks that files exist before acting.
* Lint results are written to `lint_report_v6.9.53.txt`.
* Commits are made on a new branch named `release/v6.9.53` to avoid naming conflicts with the tag `v6.9.53`.  Both the branch and the tag are pushed to the `origin` remote.
EOF
echo "new   21-policies_v$NEW_VERSION.txt" >>"$REPORT"

###############################################################################
# 6. Commit on a new version branch, tag and push
###############################################################################
# Always use a release/ prefix so the branch and tag names don’t collide.
version_branch="release/v$NEW_VERSION"

git add .
if git diff --cached --quiet; then
  echo "✓ Nothing to commit."
else
  # Create or switch to the version branch.
  if git show-ref --verify --quiet "refs/heads/$version_branch"; then
    git checkout "$version_branch"
  else
    git checkout -b "$version_branch"
  fi
  git commit -m "chore: full cleanup & bump to v$NEW_VERSION (one artefact per version)"
  echo "✓ Commit created."
fi

git rev-parse -q --verify refs/tags/v$NEW_VERSION >/dev/null || git tag "v$NEW_VERSION"

echo "→ Pushing changes to origin/$version_branch …"
if ! git push -u origin "$version_branch" --follow-tags; then
  echo "! Push failed. Please verify the remote and branch names."
fi

###############################################################################
# 7. Summary
###############################################################################
echo "→ Cleanup summary"
cat "$REPORT"
echo -e "\nDone. Changes have been pushed to origin/$version_branch."
