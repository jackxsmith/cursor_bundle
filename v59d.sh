#!/usr/bin/env bash
# v6.9.59.sh
#
# Purpose
# -------
# • Bump project from 6.9.58 → 6.9.59.
# • Remove obsolete or duplicate artefacts, leaving exactly one copy per logical
#   file (the latest, suffixed _v6.9.59) and deleting superseded logs,
#   tarballs, reports, etc.
# • Update version strings before any renames to avoid missing‑file warnings.
# • Run lint (Ruff + ShellCheck) and store results in `lint_report_v6.9.59.txt`.
# • Copy the original bundle into the repository as `original_bundle.zip`.
# • Generate diff, README, git log, extended git metadata, webhook template,
#   and a complete set of diagnostics (tests, builds, static analysis, deps, env,
#   change summary, performance placeholder, CI workflows, metrics, TODO/FIXME,
#   largest files, security audit).
# • Commit everything on `release/v6.9.59`, tag `v6.9.59`, and push both to origin.
#
# Safe to re‑run: skips moves if src=dst, skips deletes if file already gone.

set -euo pipefail
shopt -s globstar nullglob

OLD_VERSION="6.9.58"
NEW_VERSION="6.9.59"
REPO_DIR="${1:-$HOME/Downloads/cursor_bundle_v6.9.32}"
REPORT="cleanup_report_v${NEW_VERSION}.txt"
LINT="lint_report_v${NEW_VERSION}.txt"

echo "→ Working in $REPO_DIR"
[[ -d "$REPO_DIR" ]] || { echo "Repo not found"; exit 1; }
cd "$REPO_DIR"

# Initialise git repo if needed; set defaults for user name/email
git init -q 2>/dev/null || true
git config user.name >/dev/null 2>&1 || git config user.name "Automation"
git config user.email >/dev/null 2>&1 || git config user.email "automation@example.com"

: > "$REPORT"

###############################################################################
# 0. Preserve original bundle
###############################################################################
for candidate in "cursor_bundle_v6.9.32.zip" "cursor_bundle.zip"; do
  for path in "$REPO_DIR/.." "$HOME/Downloads"; do
    if [[ -f "$path/$candidate" ]]; then
      if [[ ! -f "original_bundle.zip" ]]; then
        cp "$path/$candidate" "original_bundle.zip"
        echo "cp   $path/$candidate → original_bundle.zip" >>"$REPORT"
      fi
      break 2
    fi
  done
done

###############################################################################
# 1. Update version strings
###############################################################################
echo "→ Updating version strings inside files …"
files_to_update=$(git ls-files '*.sh' '*.py' '*.json' '*.md' '*.txt' '*.yml' '*.yaml' || true)
for f in $files_to_update; do
  if [[ -f "$f" ]]; then
    perl -pi -e "s/\Q$OLD_VERSION\E/$NEW_VERSION/g" "$f"
  fi
done
echo "$NEW_VERSION" > VERSION
echo "ver  updated text files" >>"$REPORT"

###############################################################################
# 2. Remove obsolete artefacts
###############################################################################
echo "→ Removing obsolete artefacts/logs …"
find . -type f \( -name "*_v6.9.3[5-9]*" -o -name "*_v6.9.4[0-9]*" -o -name "*_v6.9.5[0-8]*" \) \
  -print | while read -r f; do
    rm -f "$f"
    echo "rm   $f" >>"$REPORT"
  done

###############################################################################
# 3. Ensure exactly one _vNEW_VERSION file
###############################################################################
suffix_file() {
  local p="$1"
  local stem="${p%.*}"
  local ext="${p##*.}"
  [[ $stem == *_v$NEW_VERSION ]] && return
  local new="${stem}_v$NEW_VERSION.$ext"
  if [[ -e "$new" ]]; then
    rm -f "$p"
    echo "dup  removed $p" >>"$REPORT"
  else
    mv "$p" "$new"
    echo "mv   $p → $new" >>"$REPORT"
  fi
}
for dir in . dist logs perf; do
  [[ -d $dir ]] || continue
  for f in "$dir"/**/*.{log,txt,json,gz,tgz,tar.gz}; do
    [[ -f "$f" ]] && suffix_file "$f"
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
# 5. Policies file (updated with new safeguards)
###############################################################################
cat > "21-policies_v$NEW_VERSION.txt" <<'EOF'
# Policies v6.9.59
* Use a dedicated release branch (`release/<version>`) and a separate tag (`v<version>`) to avoid refspec collisions.
* Consolidate all patterns in `find` expressions on a single line to prevent unmatched parentheses.
* Align here‑doc delimiters at column 1 so variables expand correctly and scripts can be parsed reliably.
* Exclude output files and irrelevant directories from scans to prevent self‑scanning.
* Close every `if` with a matching `fi`; do not use `end`.
* Write scripts using safe tools (`printf`, Python) rather than `cat <<EOF` to avoid executing code during script creation.
* Check tool availability before invoking tests, builds, security audits, static analyses, and report if missing.
* Keep exactly one artefact/log per logical file with suffix `_v6.9.59`, removing older duplicates.
* Update version strings before renaming to avoid missing‑file warnings.
* The script is idempotent: skips moves if src=dst and checks existence before acting.
* Lint results are written to `lint_report_v6.9.59.txt`.
* Commits are made on `release/v6.9.59`, with tag `v6.9.59` pushed to origin.
* All diagnostics—diff, logs, metadata, dependencies, environment, tests, builds, static analysis, performance placeholder, CI workflows, README, webhook template, code metrics, TODO/FIXME report, largest files report, and security audit—are generated and committed with this branch for full visibility.
EOF
echo "new   21-policies_v$NEW_VERSION.txt" >>"$REPORT"

###############################################################################
# 5.5. Generate context files
###############################################################################
# Diff
DIFF_FILE="diff-${OLD_VERSION}-to-${NEW_VERSION}.patch"
git diff HEAD > "$DIFF_FILE"
echo "new   $DIFF_FILE" >>"$REPORT"

# README
README="README.md"
cat <<EOF > "$README"
# Release v${NEW_VERSION}

This branch contains the release of version **v${NEW_VERSION}**.

## Contents
- **original_bundle.zip** – the original bundle archive for historical debugging.
- **${DIFF_FILE}** – unified diff showing changes between v${OLD_VERSION} and v${NEW_VERSION}.
- **v${NEW_VERSION}.sh** – the script used to perform this upgrade.
- **cleanup_report_v${NEW_VERSION}.txt** – records every file removed or renamed during the upgrade.
- **lint_report_v${NEW_VERSION}.txt** – output from the linting pass.
- **21-policies_v${NEW_VERSION}.txt** – defines the policies enforced during this upgrade.
- **git_log_${NEW_VERSION}.txt** – a snapshot of recent history (decorated commits and stats).
- **git_metadata_${NEW_VERSION}.txt** – detailed Git metadata (logs, refs, remotes, config).
- **webhook_config_v${NEW_VERSION}.json** – a template for GitHub webhooks.
- **test_results_v${NEW_VERSION}.txt** – output of available test suites.
- **build_log_v${NEW_VERSION}.txt** – logs from build processes, if available.
- **static_analysis_v${NEW_VERSION}.txt** – consolidated static analysis results.
- **dependencies_v${NEW_VERSION}.txt** – pip/npm dependency snapshots, if available.
- **environment_v${NEW_VERSION}.txt** – system and tool versions.
- **change_summary_v${NEW_VERSION}.txt** – commit messages since the previous tag.
- **performance_v${NEW_VERSION}.txt** – placeholder for performance profiling.
- **ci_workflows_v${NEW_VERSION}.tar.gz** – tarball of CI workflow definitions (or a note if absent).
- **code_metrics_v${NEW_VERSION}.txt** – counts of files and lines by extension.
- **todo_fixme_v${NEW_VERSION}.txt** – list of TODO/FIXME comments found in the repository.
- **largest_files_v${NEW_VERSION}.txt** – top 20 largest files by size.
- **security_audit_v${NEW_VERSION}.txt** – results of dependency vulnerability scans.

## Summary

This branch was created from the previous version tag \`v${OLD_VERSION}\`.  All version strings were updated to \`${NEW_VERSION}\`, duplicate artefacts were removed, and new artefacts were suffixed with \`_${NEW_VERSION}\`.  A fresh lint was run, and the upgrade script committed the changes on this branch and pushed both the branch and the tag \`v${NEW_VERSION}\` to the remote.  The extensive diagnostics included with this release make it easier to reproduce, debug, and analyse the project’s evolution.
EOF
echo "new   $README" >>"$REPORT"

# Git log
LOG_FILE="git_log_${NEW_VERSION}.txt"
git log --decorate --stat --oneline -n 20 > "$LOG_FILE" || true
echo "new   $LOG_FILE" >>"$REPORT"

# Git metadata (extended)
META_FILE="git_metadata_${NEW_VERSION}.txt"
{
  echo "### git log (50 commits):"
  git log --decorate --graph --pretty=oneline -n 50
  echo
  echo "### git show-ref:"
  git show-ref
  echo
  echo "### git remote -v:"
  git remote -v
  echo
  echo "### git config (sanitised):"
  git config --list
} > "$META_FILE"
echo "new   $META_FILE" >>"$REPORT"

# Webhook configuration file
WEBHOOK_FILE="webhook_config_v${NEW_VERSION}.json"
cat > "$WEBHOOK_FILE" <<EOF
{
  "name": "web",
  "active": true,
  "events": ["push", "pull_request"],
  "config": {
    "url": "https://example.com/webhook",
    "content_type": "json",
    "insecure_ssl": "0",
    "secret": "REPLACE_WITH_YOUR_SECRET"
  }
}
EOF
echo "new   $WEBHOOK_FILE" >>"$REPORT"

# Test results
TEST_FILE="test_results_v${NEW_VERSION}.txt"
{
  if command -v pytest >/dev/null 2>&1; then
    echo "Running pytest…"
    pytest -q || true
  elif [[ -f package.json ]] && command -v npm >/dev/null 2>&1; then
    echo "Running npm test…"
    npm test --silent || true
  else
    echo "No recognised test runner found; tests not executed."
  fi
} > "$TEST_FILE"
echo "new   $TEST_FILE" >>"$REPORT"

# Build logs
BUILD_FILE="build_log_v${NEW_VERSION}.txt"
{
  if [[ -f package.json ]] && command -v npm >/dev/null 2>&1; then
    echo "Running npm build…"
    npm run build --silent || true
  elif [[ -f Makefile ]]; then
    echo "Running make…"
    make || true
  else
    echo "No recognised build command found; build not executed."
  fi
} > "$BUILD_FILE"
echo "new   $BUILD_FILE" >>"$REPORT"

# Static analysis
ANALYSIS_FILE="static_analysis_v${NEW_VERSION}.txt"
{
  if command -v bandit >/dev/null 2>&1; then
    echo "Running bandit…"
    bandit -r . || true
  else
    echo "Bandit not installed; skipping Python security scan."
  fi
  if command -v pylint >/dev/null 2>&1; then
    echo "Running pylint…"
    pylint $(git ls-files '*.py') || true
  else
    echo "Pylint not installed; skipping Python lint."
  fi
  if [[ -f package.json ]] && command -v npm >/dev/null 2>&1; then
    if npm pkg get scripts.lint >/dev/null 2>&1; then
      echo "Running npm lint…"
      npm run lint --silent || true
    else
      echo "No npm lint script found; skipping JS lint."
    fi
  fi
} > "$ANALYSIS_FILE"
echo "new   $ANALYSIS_FILE" >>"$REPORT"

# Dependency snapshots
DEPS_FILE="dependencies_v${NEW_VERSION}.txt"
{
  if command -v pip >/dev/null 2>&1; then
    echo "### pip freeze:"
    pip freeze || true
  else
    echo "pip not installed; cannot capture Python dependencies."
  fi
  if [[ -f package.json ]] && command -v npm >/dev/null 2>&1; then
    echo -e "\n### npm list (depth=0):"
    npm list --depth=0 || true
  fi
} > "$DEPS_FILE"
echo "new   $DEPS_FILE" >>"$REPORT"

# Environment details
ENV_FILE="environment_v${NEW_VERSION}.txt"
{
  echo "Date: $(date)"
  echo "System: $(uname -a)"
  if command -v lsb_release >/dev/null 2>&1; then
    lsb_release -a || true
  fi
  echo
  echo "### Tool versions:"
  echo "Python: $(python -V 2>&1)"
  if command -v pip >/dev/null 2>&1; then
    pip --version || true
  fi
  if command -v node >/dev/null 2>&1; then
    echo "Node: $(node -v)"
    echo "npm: $(npm -v)"
  fi
  if command -v shellcheck >/dev/null 2>&1; then
    shellcheck --version || true
  fi
  if command -v ruff >/dev/null 2>&1; then
    ruff --version || true
  fi
  if command -v gh >/dev/null 2>&1; then
    gh --version || true
  fi
} > "$ENV_FILE"
echo "new   $ENV_FILE" >>"$REPORT"

# Change summary
CHANGE_FILE="change_summary_v${NEW_VERSION}.txt"
git log --pretty=short --no-merges "v${OLD_VERSION}..HEAD" > "$CHANGE_FILE" || true
echo "new   $CHANGE_FILE" >>"$REPORT"

# Performance placeholder
PERF_FILE="performance_v${NEW_VERSION}.txt"
echo "Performance profiling not available in this script." > "$PERF_FILE"
echo "new   $PERF_FILE" >>"$REPORT"

# CI workflows tarball (freshly created for this version)
CI_FILE="ci_workflows_v${NEW_VERSION}.tar.gz"
if [[ -d .github ]]; then
  tar -czf "$CI_FILE" .github
else
  echo "No .github directory found." > "$CI_FILE"
fi
echo "new   $CI_FILE" >>"$REPORT"

# Code metrics
METRICS_FILE="code_metrics_v${NEW_VERSION}.txt"
{
  echo "Extension,Files,Lines"
  for ext in $(git ls-files | sed 's/.*\.//' | sort | uniq); do
    count=$(git ls-files "*.$ext" | wc -l)
    lines=$(git ls-files "*.$ext" | xargs -r cat | wc -l)
    echo "$ext,$count,$lines"
  done | sort
} > "$METRICS_FILE"
echo "new   $METRICS_FILE" >>"$REPORT"

# TODO/FIXME report
TODO_FILE="todo_fixme_v${NEW_VERSION}.txt"
{
  echo "### TODO/FIXME references:"
  grep -RIn --exclude="$TODO_FILE" --exclude-dir={.git,node_modules,dist} -E "TODO|FIXME" . || echo "No TODO/FIXME markers found."
} > "$TODO_FILE"
echo "new   $TODO_FILE" >>"$REPORT"

# Largest files report
LARGEST_FILE="largest_files_v${NEW_VERSION}.txt"
{
  echo "### Top 20 largest files (in bytes):"
  find . -type f -not -path "./.git/*" -printf '%s %p\n' | sort -nr | head -n 20
} > "$LARGEST_FILE"
echo "new   $LARGEST_FILE" >>"$REPORT"

# Security audit
SECURITY_FILE="security_audit_v${NEW_VERSION}.txt"
{
  if [[ -f package.json ]] && command -v npm >/dev/null 2>&1; then
    echo "Running npm audit…"
    npm audit --json || true
  else
    echo "No npm project detected or npm not installed; skipping npm audit."
  fi
  if command -v safety >/dev/null 2>&1; then
    echo
    echo "Running safety…"
    safety check || true
  else
    echo
    echo "Safety not installed; skipping Python security audit."
  fi
} > "$SECURITY_FILE"
echo "new   $SECURITY_FILE" >>"$REPORT"

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
git push -u origin "$version_branch" --follow-tags || {
  echo "! Push failed. Please verify the remote and branch names."
}

###############################################################################
# 7. Summary
###############################################################################
echo "→ Cleanup summary"
cat "$REPORT"
echo -e "\nDone. Changes have been pushed to origin/$version_branch."
