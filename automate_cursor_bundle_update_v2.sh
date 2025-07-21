#!/bin/bash
# This script automates installation of GitHub CLI (if needed), authentication,
# renaming a GitHub repository and local directory from cursor_bundle_v6.9.32 to
# cursor_bundle, updating Git remotes, and pushing the current branch and tags.
#
# It is intended for Debian/Ubuntu systems with apt. For other distributions,
# modify the installation section accordingly.

set -euo pipefail

OLD_REPO_DIR="${1:-$HOME/Downloads/cursor_bundle_v6.9.32}"
NEW_REPO_NAME="cursor_bundle"

# Utility: check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Step 1: Install GitHub CLI if missing
if ! command_exists gh; then
    echo "GitHub CLI not found. Installing via apt (requires sudo)…"
    # Ensure wget is available
    type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)
    # Add GitHub CLI package repository and key
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

# Step 2: Authenticate if needed
if ! gh auth status >/dev/null 2>&1; then
    echo "GitHub CLI is not authenticated. Launching gh auth login…"
    gh auth login
else
    echo "GitHub CLI already authenticated."
fi

# Step 3: Validate the provided repository directory
if [[ ! -d "$OLD_REPO_DIR" ]]; then
    echo "Error: $OLD_REPO_DIR does not exist" >&2
    exit 1
fi
if [[ ! -d "$OLD_REPO_DIR/.git" ]]; then
    echo "Error: $OLD_REPO_DIR is not a Git repository" >&2
    exit 1
fi

# Step 4: Rename the remote repository and update local configuration
rename_and_update() {
    local repo_dir="$1"
    cd "$repo_dir"
    echo "→ Working in $(pwd)"

    # Determine remote origin
    local origin_url
    origin_url=$(git remote get-url origin)
    # Parse remote owner and repo name
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

    # Skip rename if names already match
    if [[ "$old_repo_name" == "$NEW_REPO_NAME" ]]; then
        echo "✓ Repository already named $NEW_REPO_NAME. Updating remote origin URL if needed…"
    else
        # Attempt to rename via gh
        echo "→ Attempting to rename GitHub repository $owner/$old_repo_name → $NEW_REPO_NAME using gh…"
        if gh repo rename -R "$owner/$old_repo_name" "$NEW_REPO_NAME" -y >/dev/null 2>&1; then
            echo "✓ Remote repository renamed to $owner/$NEW_REPO_NAME"
        else
            echo "! gh repo rename failed. Attempting to create new repository $owner/$NEW_REPO_NAME…"
            if gh repo create "$owner/$NEW_REPO_NAME" --private --confirm >/dev/null 2>&1; then
                echo "✓ New repository $owner/$NEW_REPO_NAME created"
            else
                echo "! Failed to rename or create the remote repository. Please check your permissions."
            fi
        fi
    fi

    # Update origin URL
    local new_remote_url="git@$host:$owner/$NEW_REPO_NAME.git"
    echo "→ Updating local origin remote to $new_remote_url …"
    git remote set-url origin "$new_remote_url"
    echo "✓ origin remote updated to $new_remote_url"

    # Rename directory if needed
    local parent_dir="$(dirname "$repo_dir")"
    local new_dir_path="$parent_dir/$NEW_REPO_NAME"
    if [[ "$repo_dir" != "$new_dir_path" ]]; then
        if [[ -d "$new_dir_path" ]]; then
            echo "! Directory $new_dir_path already exists. Skipping directory rename."
        else
            echo "→ Renaming local directory $(basename "$repo_dir") → $NEW_REPO_NAME …"
            cd "$parent_dir"
            mv "$(basename "$repo_dir")" "$NEW_REPO_NAME"
            echo "✓ Local directory renamed to $new_dir_path"
            repo_dir="$new_dir_path"
            cd "$repo_dir"
        fi
    fi

    # Push current branch and tags to new remote
    local branch
    branch=$(git symbolic-ref --short HEAD || echo "main")
    echo "→ Pushing $branch and tags to new remote …"
    if git push origin "$branch" --follow-tags; then
        echo "✓ Pushed changes to $owner/$NEW_REPO_NAME.git on branch $branch"
    else
        echo "! Push failed. Please check your access rights and ensure the remote exists."
    fi

    echo "Done. Local and remote repository names are synchronized."
}

rename_and_update "$OLD_REPO_DIR"
