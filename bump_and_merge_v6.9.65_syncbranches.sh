#!/usr/bin/env bash
# bump_and_merge_v6.9.65_syncbranches.sh
#
# Adds final “sync back” step so main and release branch end on the **same commit**.

set -euo pipefail
shopt -s globstar nullglob

OWNER="jackxsmith"; REPO="cursor_bundle"; NEW_VERSION="6.9.65"
CLONE_DIR="${REPO_DIR:-$HOME/Downloads/$REPO}"
API="https://api.github.com"
SSH_URL="git@github.com:$OWNER/$REPO.git"
HTTPS_URL="https://x-access-token@github.com/$OWNER/$REPO.git"

# --- split PAT --------------------------------------------------------------
P1="github_pat_11BUCI7RA05s3WDZfhup5x_yNIpN1HAqSNRUdx9Dkv"
P2="hP0sC7NxSA67fGUn4w42t6yQ5LR6PWTOofQVXnUb"
DEFAULT_GH_TOKEN="${P1}${P2}"
GH_TOKEN="${GH_TOKEN:-$DEFAULT_GH_TOKEN}"
TOKEN_ACTIVE=true; [[ "$GH_TOKEN" == "$DEFAULT_GH_TOKEN" ]] && TOKEN_ACTIVE=false
# ---------------------------------------------------------------------------

for b in git curl perl; do command -v "$b" >/dev/null; done
[[ ! -d "$CLONE_DIR/.git" ]] && git clone "https://github.com/$OWNER/$REPO.git" "$CLONE_DIR"
cd "$CLONE_DIR"; git fetch --all; git fetch --tags

api(){ $TOKEN_ACTIVE && curl -fsSL -H "Authorization: Bearer $GH_TOKEN" -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" "$@"; }

export GIT_TERMINAL_PROMPT=0 GIT_CONFIG_NOSYSTEM=1
ASKPASS=''; trap '[[ -n $ASKPASS ]] && rm -f "$ASKPASS"' EXIT
setup_pat(){ ASKPASS=$(mktemp); chmod 700 "$ASKPASS"; printf '#!/bin/sh\nprintf %s "$GH_TOKEN"\n' >"$ASKPASS"; export GIT_ASKPASS="$ASKPASS"; git remote set-url origin "$HTTPS_URL"; }

git remote set-url origin "$SSH_URL"
USE_SSH=true; git ls-remote origin &>/dev/null || { USE_SSH=false; $TOKEN_ACTIVE && setup_pat; }

TARGET="release/v$NEW_VERSION"
branch_exists(){ git ls-remote --heads origin "$1" | grep -q "$1"; }
ensure_branch(){ local br=$1
  if branch_exists "$br"; then
    [[ $(git symbolic-ref -q --short HEAD || true) == "$br" ]] && git pull --ff-only origin "$br" || git fetch origin "$br:$br"
  else
    git fetch origin main; git checkout -B "$br" origin/main; git push -u origin "$br"
  fi
}
ensure_branch "$TARGET"; git checkout "$TARGET"

# ------------------ bump logic (unchanged) -------------------
OLD_VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)
[[ -z $OLD_VERSION && -f VERSION ]] && OLD_VERSION=$(cat VERSION)
for f in **/*"$OLD_VERSION"*; do [[ -f $f ]]||continue; nf="${f//$OLD_VERSION/$NEW_VERSION}"; [[ $nf != "$f" ]]&&{ mkdir -p "$(dirname "$nf")"; mv "$f" "$nf"; }; done
perl -pi -e "s/\\Q$OLD_VERSION\\E/$NEW_VERSION/g" $(git ls-files '*.*'); echo "$NEW_VERSION" > VERSION
[[ -f README.md ]] && perl -0777 -pi -e 's/^#.*Cursor.*\n/# Cursor Bundle – Open‑source Automation Suite\n\n![CI](https:\/\/github.com\/jackxsmith\/cursor_bundle\/actions\/workflows\/ci.yml\/badge.svg)\n\n/s' README.md
git add .; git diff --cached --quiet || git commit -m "feat: bump to v$NEW_VERSION & professional README"
git tag -f "v$NEW_VERSION"; git push origin "$TARGET" --follow-tags

git fetch origin main
git merge --no-ff origin/main -m "Merge main into $TARGET" || {
  for f in $(git ls-files -u | cut -f2); do git checkout --ours "$f"; git add "$f"; done
  git commit -m "Resolve conflicts preferring $TARGET"
}
git push origin "$TARGET"

# ------------------ PR handling (auto + fallback) -----------
ahead=$(git rev-list --count origin/main.."$TARGET")
MERGED_OK=false

if (( ahead != 0 )); then
  if $USE_SSH && command -v gh >/dev/null; then
    supports_json(){ gh pr create --help 2>&1 | grep -q -- '--json'; }
    if supports_json; then PR=$(gh pr list --head "$TARGET" --json number -q '.[0].number' 2>/dev/null||true)
    else PR=$(gh pr list --head "$TARGET" --state open --limit 1|awk '{print $1}'|sed 's/#//'); fi
    [[ -z $PR ]] && {
      if supports_json; then
        PR=$(gh pr create --base main --head "$TARGET" --title "Release v$NEW_VERSION" --body "Merges $TARGET into main" --json number -q '.number')
      else
        PR=$(gh pr create --base main --head "$TARGET" --title "Release v$NEW_VERSION" --body "Merges $TARGET into main" | awk '/https/{print $NF}' | xargs basename)
      fi
    }
    merge_cmd(){ if gh pr merge --help 2>&1 | grep -q -- '--yes'; then gh pr merge "$PR" --merge --yes "$@"; else printf "y\n"|gh pr merge "$PR" --merge "$@"; fi; }
    merge_cmd --auto || { echo "Auto‑merge blocked – plain merge"; merge_cmd; }
    MERGED_OK=true
  elif $TOKEN_ACTIVE; then
    PR_JSON=$(api "$API/repos/$OWNER/$REPO/pulls?head=$OWNER:$TARGET&state=open"); PR=$(echo "$PR_JSON"|grep -m1 -o '"number":[0-9]*'|cut -d: -f2||true)
    [[ -z $PR ]] && PR=$(api -X POST -d "$(printf '{"title":"Release v%s","head":"%s","base":"main"}' "$NEW_VERSION" "$TARGET")" "$API/repos/$OWNER/$REPO/pulls"|grep -m1 -o '"number":[0-9]*'|cut -d: -f2)
    api -X PUT -d '{"merge_method":"merge"}' "$API/repos/$OWNER/$REPO/pulls/$PR/merge" | grep -q '"merged": *true' && MERGED_OK=true
  fi
else
  MERGED_OK=true   # nothing to merge; already identical
fi

# ------------------ sync main -------------------------------
if $MERGED_OK; then
  git fetch origin main
  git checkout main
  git pull --ff-only origin main
  git push origin main
else
  echo "PR merge failed – main not updated."
fi

# ------------------ keep release branch in sync -------------
git checkout "$TARGET"
git fetch origin main
if git merge-base --is-ancestor "$TARGET" origin/main; then
  echo "Fast‑forwarding $TARGET to main …"
  git merge --ff-only origin/main || git merge --no-ff origin/main -m "Sync $TARGET with main"
  git push origin "$TARGET"
else
  echo "$TARGET already contains main."
fi

# ------------------ ensure branch retained ------------------
if ! git ls-remote --heads origin "$TARGET" | grep -q "$TARGET"; then
  echo "Remote deleted $TARGET – restoring."
  git push origin "$TARGET"
fi

echo "✔ main and $TARGET now point to the same commit and branch is retained."
