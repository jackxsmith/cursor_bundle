#!/usr/bin/env bash
# bump_and_merge.sh
#
# Usage:
#   ./bump_and_merge.sh                  # auto‑increments patch version
#   ./bump_and_merge.sh 6.9.61 6.9.62    # explicit old/new
#   ./bump_and_merge.sh 6.9.61 6.9.62 /path/to/repo
#
# Requires: git, bash 4+, optional gh (GitHub CLI) for auto‑merge

set -euo pipefail
shopt -s globstar nullglob

###############################################################################
# 0. Parameter parsing + auto‑increment logic
###############################################################################
if [[ $# -ge 2 ]]; then
  OLD_VERSION="$1"
  NEW_VERSION="$2"
  REPO_DIR="${3:-$HOME/Downloads/cursor_bundle}"
else
  REPO_DIR="$HOME/Downloads/cursor_bundle"
  OLD_VERSION=$(cat "$REPO_DIR/VERSION")
  IFS='.' read -r MAJ MIN PAT <<<"$OLD_VERSION"
  NEW_VERSION="$MAJ.$MIN.$((PAT+1))"
fi

TARGET_REMOTE="git@github.com:jackxsmith/cursor_bundle.git"
REPORT="cleanup_report_v${NEW_VERSION}.txt"
LINT="lint_report_v${NEW_VERSION}.txt"

echo "→ Working in $REPO_DIR"
[[ -d "$REPO_DIR" ]] || { echo "Repo not found"; exit 1; }
cd "$REPO_DIR"

git init -q 2>/dev/null || true
git config user.name  >/dev/null 2>&1 || git config user.name  "Automation"
git config user.email >/dev/null 2>&1 || git config user.email "automation@example.com"

###############################################################################
# 1. Ensure origin points to jackxsmith/cursor_bundle
###############################################################################
current_remote=$(git remote get-url origin 2>/dev/null || echo "")
if [[ "$current_remote" != "$TARGET_REMOTE" ]]; then
  if git remote | grep -q '^origin$'; then
    echo "→ Updating origin remote → $TARGET_REMOTE"
    git remote set-url origin "$TARGET_REMOTE"
  else
    echo "→ Adding origin remote → $TARGET_REMOTE"
    git remote add origin "$TARGET_REMOTE"
  fi
fi

: >"$REPORT"

###############################################################################
# 2. Create placeholder CI archives for OLD_VERSION
###############################################################################
for f in "ci_workflows_v${OLD_VERSION}.tar.gz" \
         "ci_workflows_v${OLD_VERSION}.tar_v${OLD_VERSION}.gz"; do
  [[ -f $f ]] || touch "$f"
done

###############################################################################
# 3. Preserve original bundle
###############################################################################
for z in cursor_bundle_v6.9.32.zip cursor_bundle.zip; do
  for p in "$REPO_DIR/.." "$HOME/Downloads"; do
    if [[ -f "$p/$z" && ! -f original_bundle.zip ]]; then
      cp "$p/$z" original_bundle.zip
      echo "cp   $p/$z → original_bundle.zip" >>"$REPORT"
      break 2
    fi
  done
done

###############################################################################
# 4. Update version strings
###############################################################################
echo "→ Updating version strings …"
for f in $(git ls-files '*.sh' '*.py' '*.json' '*.md' '*.txt' '*.yml' '*.yaml' || true); do
  [[ -f $f ]] && perl -pi -e "s/\Q$OLD_VERSION\E/$NEW_VERSION/g" "$f"
done
echo "$NEW_VERSION" > VERSION
echo "ver  updated text files" >>"$REPORT"

###############################################################################
# 5. Remove obsolete artefacts (preserve ci_workflows_*)
###############################################################################
echo "→ Removing obsolete artefacts …"
find . -type f \
  \( -name "*_v6.9.3[5-9]*" -o -name "*_v6.9.4[0-9]*" -o -name "*_v6.9.5[0-9]*" \) \
  ! -path "./ci_workflows_*" -print | while read -r f; do
    rm -f "$f"; echo "rm   $f" >>"$REPORT"
done

###############################################################################
# 6. Ensure single _vNEW_VERSION copy (skip ci_workflows_*)
###############################################################################
suffix() {
  local f="$1"; [[ $f == ./ci_workflows_* ]] && return
  local stem="${f%.*}" ext="${f##*.}"
  [[ $stem == *_v$NEW_VERSION ]] && return
  local new="${stem}_v$NEW_VERSION.$ext"
  if [[ -e $new ]]; then rm -f "$f"; echo "dup  removed $f" >>"$REPORT"
  else mv "$f" "$new"; echo "mv   $f → $new"   >>"$REPORT"; fi
}
for d in . dist logs perf; do
  [[ -d $d ]] || continue
  for f in "$d"/**/*.{log,txt,json,gz,tgz,tar.gz}; do [[ -f $f ]] && suffix "$f"; done
done

###############################################################################
# 7. Lint
###############################################################################
: >"$LINT"
echo "→ Linting …"
command -v ruff >/dev/null && ruff check $(git ls-files '*.py') >>"$LINT" 2>&1 || echo "Ruff not installed." >>"$LINT"
command -v shellcheck >/dev/null && shellcheck $(git ls-files '*.sh') >>"$LINT" 2>&1 || echo "ShellCheck not installed." >>"$LINT"
echo "lint report saved to $LINT" >>"$REPORT"

###############################################################################
# 8. Policies file
###############################################################################
cat >"21-policies_v$NEW_VERSION.txt" <<EOF
Policies v${NEW_VERSION}
• Force 'origin' to $TARGET_REMOTE
• Preserve all ci_workflows_* files; create placeholders for OLD_VERSION tarballs
• Single‑artefact rule: keep only _v${NEW_VERSION} copies
EOF
echo "new   21-policies_v$NEW_VERSION.txt" >>"$REPORT"

###############################################################################
# 9. Diagnostics
###############################################################################
DIFF="diff-${OLD_VERSION}-to-${NEW_VERSION}.patch"; git diff HEAD >"$DIFF"
echo "new   $DIFF" >>"$REPORT"

BASE_RANGE=$(git rev-parse -q --verify "refs/tags/v$OLD_VERSION" >/dev/null && echo "v$OLD_VERSION" || git rev-list --max-parents=0 HEAD | tail -n1)
git log --decorate --stat --oneline -n 20                    > "git_log_${NEW_VERSION}.txt"
git log $BASE_RANGE..HEAD --pretty=short --no-merges         > "change_summary_v${NEW_VERSION}.txt"
git show-ref                                                 > "git_metadata_${NEW_VERSION}.txt"

CI_TAR="ci_workflows_v${NEW_VERSION}.tar.gz"
[[ -d .github ]] && tar -czf "$CI_TAR" .github || echo "No workflows" >"$CI_TAR"
echo "new   $CI_TAR" >>"$REPORT"

###############################################################################
# 10. Commit, tag, push
###############################################################################
BR="release/v$NEW_VERSION"
git add .
git checkout -B "$BR"
git commit -m "chore: cleanup & bump to v$NEW_VERSION (auto‑merge script)"
git tag -f "v$NEW_VERSION"
git push -u origin "$BR" --follow-tags

###############################################################################
# 11. Create + merge PR (if gh present)
###############################################################################
if command -v gh >/dev/null 2>&1; then
  echo "→ Creating pull‑request and merging via gh …"
  # If PR doesn’t exist, create; otherwise continue
  gh pr view "$BR" >/dev/null 2>&1 || \
    gh pr create --base main --head "$BR" --title "Release v$NEW_VERSION" \
                 --body "Automated bump to v$NEW_VERSION. Diagnostics included."
  gh pr merge "$BR" --merge --delete-branch --yes
else
  echo "⚠️  gh CLI not installed or not authenticated – merge manually."
fi

###############################################################################
# 12. Summary
###############################################################################
echo "→ Cleanup summary"
cat "$REPORT"
echo -e "\nAll done.  Branch $BR and tag v$NEW_VERSION processed."
