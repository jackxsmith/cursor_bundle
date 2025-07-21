#!/bin/bash
# This script installs and authenticates GitHub CLI, ensures a repository named
# cursor_bundle exists and is public, updates the local repository and remote,
# and pushes changes. Designed for Debian/Ubuntu.

set -euo pipefail

OLD_REPO_DIR="${1:-$HOME/Downloads/cursor_bundle_v6.9.32}"
NEW_REPO_NAME="cursor_bundle"

command_exists() { command -v "$1" >/dev/null 2>&1; }

# Install gh if missing
if ! command_exists gh; then
    echo "GitHub CLI not found. Installing via apt (requires sudo)…"
    type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)
    sudo mkdir -p -m 755 /etc/apt/keyrings
    out=$(mktemp) && wget -nv -O "$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg
    cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    sudo mkdir -p -m 755 /etc/apt/sources.list.d
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
    sudo apt update
    sudo apt install gh -y
    echo "GitHub CLI installed successfully."
else
    echo "GitHub CLI already installed."
fi

# Authenticate
if ! gh auth status >/dev/null 2>&1; then
    echo "GitHub CLI not authenticated. Launching gh auth login…"
    gh auth login
else
    echo "GitHub CLI already authenticated."
fi

# Validate local repo
if [[ ! -d "$OLD_REPO_DIR" ]]; then echo "Error: $OLD_REPO_DIR does not exist" >&2; exit 1; fi
if [[ ! -d "$OLD_REPO_DIR/.git" ]]; then echo "Error: $OLD_REPO_DIR is not a Git repository" >&2; exit 1; fi

# Function to check if remote exists
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
        echo "→ Attempting to rename $owner/$old_repo_name to $NEW_REPO_NAME…"
        if gh repo rename -R "$owner/$old_repo_name" "$NEW_REPO_NAME" -y >/dev/null 2>&1; then
            echo "✓ Remote repository renamed"
        else
            echo "! Rename failed. Creating public repository $owner/$NEW_REPO_NAME…"
            if gh repo create "$owner/$NEW_REPO_NAME" --public --confirm >/dev/null 2>&1; then
                echo "✓ New public repository created"
            else
                echo "! Unable to rename or create repository."
            fi
        fi
    else
        echo "✓ Local repository name already $NEW_REPO_NAME. Checking remote existence…"
        if remote_exists "$owner" "$NEW_REPO_NAME"; then
            echo "✓ Remote repository exists"
        else
            echo "! Remote repository does not exist. Creating public repository…"
            if gh repo create "$owner/$NEW_REPO_NAME" --public --confirm >/dev/null 2>&1; then
                echo "✓ New public repository created"
            else
                echo "! Unable to create repository."
            fi
        fi
    fi

    # Ensure remote is public
    echo "→ Setting repository visibility to public…"
    gh repo edit "$owner/$NEW_REPO_NAME" --visibility public --accept-visibility-change-consequences >/dev/null 2>&1 || true

    # Update origin remote
    local new_url="git@$host:$owner/$NEW_REPO_NAME.git"
    echo "→ Updating local origin remote to $new_url …"
    git remote set-url origin "$new_url"
    echo "✓ origin remote updated"

    # Rename directory
    local parent="$(dirname "$repo_dir")"
    local new_path="$parent/$NEW_REPO_NAME"
    if [[ "$repo_dir" != "$new_path" ]]; then
        if [[ -d "$new_path" ]]; then
            echo "! $new_path exists. Skipping directory rename."
        else
            echo "→ Renaming directory $(basename "$repo_dir") to $NEW_REPO_NAME …"
            cd "$parent"
            mv "$(basename "$repo_dir")" "$NEW_REPO_NAME"
            echo "✓ Directory renamed to $new_path"
            repo_dir="$new_path"
            cd "$repo_dir"
        fi
    fi

    # Push branch and tags
    local branch
    branch=$(git symbolic-ref --short HEAD || echo "main")
    echo "→ Pushing $branch and tags to new remote …"
    if git push origin "$branch" --follow-tags; then
        echo "✓ Push successful"
    else
        echo "! Push failed."
    fi

    echo "Done."
}

rename_and_update "$OLD_REPO_DIR"
