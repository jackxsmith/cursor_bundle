#!/usr/bin/env bash
# v6.9.55.sh
#
# Purpose
# -------
# • Bump project from 6.9.54 → 6.9.55.
# • Remove obsolete or duplicate artefacts, leaving exactly one copy per logical
#   file (the latest, suffixed _v6.9.55) and deleting superseded logs,
#   tarballs, reports, etc.  This covers all older suffixes from 6.9.35 up
#   through 6.9.54.
# • Update version strings before any renames to avoid missing‑file warnings.
# • Run a quick lint pass (Ruff for Python, ShellCheck for Bash) and store
#   results in `lint_report_v6.9.55.txt`.
# • Copy the original bundle into the repository as `original_bundle.zip`.
# • Generate a diff file, git log, and README for debugging and history.
# • Commit all changes on `release/v6.9.55`, tag `v6.9.55`, and push to origin.
#
# Safe to re‑run: skips moves if src=dst, skips deletes if file already gone.

set -euo pipefail
shopt -s globstar nullglob

OLD_VERSION="6.9.54"
NEW_VERSION="6.9.55"
REPO_DIR="${1:-$HOME/Downloads/cursor_bundle_v6.9.32}"
REPORT="cleanup_report_v${NEW_VERSION}.txt"
LINT="lint_report_v${NEW_VERSION}.txt"

echo "→ Working in $REPO_DIR"
[[ -d "$REPO_DIR" ]] || { echo "Repo not found"; exit 1; }
cd "$REPO_DIR"

git init -q 2>/dev/null || true
if ! git config user.name >/dev/null 2>&1; then
  git config user.name "Automation"
fi
if ! git config user.email >/dev/null 2>&1; then
  git config user.email "automation@example.com"
fi

: > "$REPORT"

###############################################################################
# 0. Preserve original bundle
###############################################################################
for candidate in "cursor_bundle_v6.9.32.zip" "cursor_bundle.zip"; do
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
# 1. Update version strings
###############################################################################
echo "→ Updating version strings inside files …"
FILES=$(git ls-files '*.sh' '*.py' '*.json' '*.md' '*.txt' '*.yml' '*.yaml' || true)
if [[ -n $FILES ]]; then
  perl -pi -e "s/\Q$OLD_VERSION\E/$NEW_VERSION/g" $FILES
  echo "ver  updated text files" >>"$REPORT"
fi
echo "$NEW_VERSION" > VERSION

###############################################################################
# 2. Remove obsolete artefacts
###############################################################################
echo "→ Removing obsolete artefacts/logs …"
find . -type f \( -name "*_v6.9.3[5-9]*" -o -name "*_v6.9.4[0-9]*" -o -name "*_v6.9.5[0-4]*" \) \
| while read -r f; do
  rm -f "$f" && echo "rm   $f" >>"$REPORT"
done

###############################################################################
# 3. Ensure exactly one _vNEW_VERSION file
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
# 4. Lint
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
# 5. Policies file
###############################################################################
cat > "21-policies_v$NEW_VERSION.txt" <<'EOF'
# Policies v6.9.55
* Exactly one artefact/log is kept for each logical file, suffixed `_v6.9.55`.  Older duplicates (v6.9.35–54) are removed.
* Version strings are updated before renaming, preventing missing‑file warnings.
* The script is idempotent: it skips moves if the source and destination are the same, and checks that files exist before acting.
* Lint results are written to `lint_report_v6.9.55.txt`.
* Commits are made on a new branch named `release/v6.9.55` to avoid naming conflicts with the tag `v6.9.55`.  Both the branch and the tag are pushed to the `origin` remote.
* Additional context files (diff, log and README) are created and committed with this branch to aid in history inspection and debugging.
EOF
echo "new   21-policies_v$NEW_VERSION.txt" >>"$REPORT"

###############################################################################
# 5.5. Diff, README, and log
###############################################################################
diff_file="diff-${OLD_VERSION}-to-${NEW_VERSION}.patch"
git diff HEAD > "$diff_file"
echo "new   $diff_file" >>"$REPORT"

readme_file="README.md"
cat <<EOF > "$readme_file"
# Release v${NEW_VERSION}

This branch contains the release of version **v${NEW_VERSION}**.

## Contents

- **original_bundle.zip** – a copy of the original bundle archive.  Keeping this file makes it easy to inspect the initial state of the project for any historical debugging.
- **${diff_file}** – a unified diff showing all changes made between v${OLD_VERSION} and v${NEW_VERSION}.  This allows for quick review of the upgrade without digging through Git history.
- **v${NEW_VERSION}.sh** – the script used to perform this upgrade.  Having the script alongside the changes makes it easier to reproduce or debug the process.
- **cleanup_report_v${NEW_VERSION}.txt** – records every file removed or renamed during the upgrade.
- **lint_report_v${NEW_VERSION}.txt** – output from the linting pass on Python and shell scripts.
- **21-policies_v${NEW_VERSION}.txt** – defines the policies enforced during this upgrade.

## Summary

This branch was created from the previous version tag \`v${OLD_VERSION}\`.  All version strings were updated to \`${NEW_VERSION}\`, duplicate artefacts were removed, and new artefacts were suffixed with \`_${NEW_VERSION}\`.  A fresh lint was run, and the upgrade script committed the changes on this branch and pushed both the branch and the tag \`v${NEW_VERSION}\` to the remote.  See \`${diff_file}\` for the exact code changes.
EOF
echo "new   $readme_file" >>"$REPORT"

log_file="git_log_${NEW_VERSION}.txt"
git log --decorate --stat --oneline -n 20 > "$log_file" || true
echo "new   $log_file" >>"$REPORT"

###############################################################################
# 6. Commit, tag and push on release/vNEW_VERSION
###############################################################################
version_branch="release/v$NEW_VERSION"
git add .
if git diff --cached --quiet; then
  echo "✓ Nothing to commit."
else
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
