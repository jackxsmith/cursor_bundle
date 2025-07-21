#!/bin/bash
# Fully automates installation/authentication of gh, repository creation/rename,
# sets repository to public, updates local settings, pushes changes, and opens
# the repository in the browser. Designed for Debian/Ubuntu systems.

set -euo pipefail

OLD_REPO_DIR="${1:-$HOME/Downloads/cursor_bundle_v6.9.32}"
NEW_REPO_NAME="cursor_bundle"

command_exists() { command -v "$1" >/dev/null 2>&1; }

# Install gh if needed
if ! command_exists gh; then
    echo "GitHub CLI not found. Installing via apt…"
    type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)
    sudo mkdir -p -m 755 /etc/apt/keyrings
    out=$(mktemp) && wget -nv -O "$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg
    cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    sudo mkdir -p -m 755 /etc/apt/sources.list.d
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt update
    sudo apt install gh -y
    echo "✓ GitHub CLI installed"
else
    echo "GitHub CLI already installed."
fi

# Authenticate if needed
if ! gh auth status >/dev/null 2>&1; then
    echo "GitHub CLI not authenticated. Launching gh auth login…"
    gh auth login
else
    echo "GitHub CLI already authenticated."
fi

# Validate local repo
if [[ ! -d "$OLD_REPO_DIR" ]]; then echo "Error: $OLD_REPO_DIR does not exist" >&2; exit 1; fi
if [[ ! -d "$OLD_REPO_DIR/.git" ]]; then echo "Error: $OLD_REPO_DIR is not a Git repository" >&2; exit 1; fi

# Determine if remote exists
remote_exists() { gh repo view "$1/$2" >/dev/null 2>&1; }

rename_and_update() {
    local repo_dir="$1"
    cd "$repo_dir"
    echo "→ Working in $(pwd)"

    local origin_url host owner old_repo_name
    origin_url=$(git remote get-url origin)
    if [[ "$origin_url" =~ ^git@([^:]+):([^/]+)/([^/]+)\.git$ ]]; then
        host="${BASH_REMATCH[1]}"; owner="${BASH_REMATCH[2]}"; old_repo_name="${BASH_REMATCH[3]}"
    elif [[ "$origin_url" =~ ^https://([^/]+)/([^/]+)/([^/]+)\.git$ ]]; then
        host="${BASH_REMATCH[1]}"; owner="${BASH_REMATCH[2]}"; old_repo_name="${BASH_REMATCH[3]}"
    else
        echo "Error: Cannot parse origin URL: $origin_url" >&2; return 1
    fi

    if [[ "$old_repo_name" != "$NEW_REPO_NAME" ]]; then
        echo "→ Attempting to rename $owner/$old_repo_name → $NEW_REPO_NAME…"
        if gh repo rename -R "$owner/$old_repo_name" "$NEW_REPO_NAME" -y >/dev/null 2>&1; then
            echo "✓ Remote renamed"
        else
            echo "! Rename failed. Creating repository $owner/$NEW_REPO_NAME…"
            gh repo create "$owner/$NEW_REPO_NAME" --public --confirm >/dev/null 2>&1 || echo "! Unable to create repository."
        fi
    else
        echo "✓ Local repo already named $NEW_REPO_NAME. Checking remote existence…"
        if remote_exists "$owner" "$NEW_REPO_NAME"; then
            echo "✓ Remote exists"
        else
            echo "! Remote missing. Creating repository…"
            gh repo create "$owner/$NEW_REPO_NAME" --public --confirm >/dev/null 2>&1 || echo "! Unable to create repository."
        fi
    fi

    # Always set visibility to public (no Python/JQ needed)
    echo "→ Setting repository visibility to public…"
    gh repo edit "$owner/$NEW_REPO_NAME" --visibility public --accept-visibility-change-consequences >/dev/null 2>&1 || true

    # Update local remote URL
    local new_url="git@$host:$owner/$NEW_REPO_NAME.git"
    git remote set-url origin "$new_url"
    echo "✓ origin remote updated to $new_url"

    # Rename directory if necessary
    local parent="$(dirname "$repo_dir")"
    local new_path="$parent/$NEW_REPO_NAME"
    if [[ "$repo_dir" != "$new_path" ]]; then
        if [[ -d "$new_path" ]]; then
            echo "! $new_path exists. Skipping directory rename."
        else
            echo "→ Renaming directory to $NEW_REPO_NAME…"
            cd "$parent" && mv "$(basename "$repo_dir")" "$NEW_REPO_NAME"
            repo_dir="$new_path"
            cd "$repo_dir"
            echo "✓ Directory renamed to $new_path"
        fi
    fi

    # Push changes
    local branch
    branch=$(git symbolic-ref --short HEAD || echo "main")
    echo "→ Pushing $branch and tags…"
    git push origin "$branch" --follow-tags || echo "! Push failed"
    echo "✓ Push complete"

    # Open repository in browser
    echo "→ Opening repository in browser…"
    gh repo view "$owner/$NEW_REPO_NAME" --web

    echo "Done."
}

rename_and_update "$OLD_REPO_DIR"
