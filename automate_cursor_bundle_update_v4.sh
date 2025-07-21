#!/bin/bash
# This script automates installation and authentication of GitHub CLI and renames
# or creates a public GitHub repository named cursor_bundle. It updates the
# local repository and pushes changes. Designed for Debian/Ubuntu.

set -euo pipefail

OLD_REPO_DIR="${1:-$HOME/Downloads/cursor_bundle_v6.9.32}"
NEW_REPO_NAME="cursor_bundle"

# Check for command existence
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

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

# Authenticate gh if needed
if ! gh auth status >/dev/null 2>&1; then
    echo "GitHub CLI is not authenticated. Launching gh auth login…"
    gh auth login
else
    echo "GitHub CLI already authenticated."
fi

# Validate local repo
if [[ ! -d "$OLD_REPO_DIR" ]]; then
    echo "Error: $OLD_REPO_DIR does not exist" >&2
    exit 1
fi
if [[ ! -d "$OLD_REPO_DIR/.git" ]]; then
    echo "Error: $OLD_REPO_DIR is not a Git repository" >&2
    exit 1
fi

rename_and_update() {
    local repo_dir="$1"
    cd "$repo_dir"
    echo "→ Working in $(pwd)"

    local origin_url
    origin_url=$(git remote get-url origin)
    local host owner old_repo_name
    if [[ "$origin_url" =~ ^git@([^:]+):([^/]+)/([^/]+)\.git$ ]]; then
        host="${BASH_REMATCH[1]}"
        owner="${BASH_REMATCH[2]}"
        old_repo_name="${BASH_REMATCH[3]}"
    elif [[ "$origin_url" =~ ^https://([^/]+)/([^/]+)/([^/]+)\.git$ ]]; then
        host="${BASH_REMATCH[1]}"
        owner="${BASH_REMATCH[2]}"
        old_repo_name="${BASH_REMATCH[3]}"
    else
        echo "Error: Could not parse origin URL: $origin_url" >&2
        return 1
    fi

    remote_exists() {
        gh repo view "$owner/$NEW_REPO_NAME" >/dev/null 2>&1
    }

    if [[ "$old_repo_name" != "$NEW_REPO_NAME" ]]; then
        echo "→ Attempting to rename GitHub repository $owner/$old_repo_name → $NEW_REPO_NAME…"
        if gh repo rename -R "$owner/$old_repo_name" "$NEW_REPO_NAME" -y >/dev/null 2>&1; then
            echo "✓ Remote repository renamed to $owner/$NEW_REPO_NAME"
        else
            echo "! gh repo rename failed. Creating new public repository $owner/$NEW_REPO_NAME…"
            if gh repo create "$owner/$NEW_REPO_NAME" --public --confirm >/dev/null 2>&1; then
                echo "✓ New public repository $owner/$NEW_REPO_NAME created"
            else
                echo "! Unable to rename or create remote repository."
            fi
        fi
    else
        echo "✓ Local repository already named $NEW_REPO_NAME. Checking if remote exists…"
        if remote_exists; then
            echo "✓ Remote repository $owner/$NEW_REPO_NAME exists."
        else
            echo "! Remote repository $owner/$NEW_REPO_NAME does not exist. Creating it as public…"
            if gh repo create "$owner/$NEW_REPO_NAME" --public --confirm >/dev/null 2>&1; then
                echo "✓ New public repository $owner/$NEW_REPO_NAME created"
            else
                echo "! Unable to create remote repository."
            fi
        fi
    fi

    # Update origin URL
    local new_url="git@$host:$owner/$NEW_REPO_NAME.git"
    echo "→ Updating local origin remote to $new_url …"
    git remote set-url origin "$new_url"
    echo "✓ origin remote updated to $new_url"

    # Rename directory
    local parent="$(dirname "$repo_dir")"
    local new_path="$parent/$NEW_REPO_NAME"
    if [[ "$repo_dir" != "$new_path" ]]; then
        if [[ -d "$new_path" ]]; then
            echo "! $new_path already exists. Skipping directory rename."
        else
            echo "→ Renaming local directory $(basename "$repo_dir") → $NEW_REPO_NAME …"
            cd "$parent"
            mv "$(basename "$repo_dir")" "$NEW_REPO_NAME"
            echo "✓ Local directory renamed to $new_path"
            repo_dir="$new_path"
            cd "$repo_dir"
        fi
    fi

    # Push branch and tags
    local branch
    branch=$(git symbolic-ref --short HEAD || echo "main")
    echo "→ Pushing $branch and tags to new remote …"
    if git push origin "$branch" --follow-tags; then
        echo "✓ Pushed changes to $owner/$NEW_REPO_NAME on branch $branch"
    else
        echo "! Push failed. Check your access rights and remote existence."
    fi

    echo "Done."
}

rename_and_update "$OLD_REPO_DIR"
