#!/bin/bash
# This script automates the installation of GitHub CLI on Debian/Ubuntu systems,
# prompts the user to authenticate, then renames a GitHub repository and local
# directory from cursor_bundle_v6.9.32 to cursor_bundle via the existing
# update_remote_to_cursor_bundle.sh script.
#
# NOTE: This script will prompt for sudo access during package installation
# and for GitHub authentication via `gh auth login`. These steps cannot be fully
# automated without user interaction. Use at your own risk.

set -euo pipefail

OLD_REPO_DIR="${1:-$HOME/Downloads/cursor_bundle_v6.9.32}"
NEW_REPO_NAME="cursor_bundle"

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Step 1: Install GitHub CLI if not already installed
if ! command_exists gh; then
    echo "GitHub CLI not found. Installing via apt (requires sudo)…"
    # Ensure wget is installed
    type -p wget >/dev/null || (sudo apt update && sudo apt install wget -y)

    # Add GitHub CLI's GPG key and repository (based on docs)
    sudo mkdir -p -m 755 /etc/apt/keyrings
    out=$(mktemp) && wget -nv -O "$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg
    cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
    sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
    sudo mkdir -p -m 755 /etc/apt/sources.list.d
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null

    # Update package lists and install gh
    sudo apt update
    sudo apt install gh -y
    echo "GitHub CLI installed successfully."
else
    echo "GitHub CLI already installed."
fi

# Step 2: Authenticate with GitHub CLI if not already authenticated
if ! gh auth status >/dev/null 2>&1; then
    echo "GitHub CLI is not authenticated. Launching 'gh auth login'…"
    # This command will open an interactive prompt for authentication
    gh auth login
else
    echo "GitHub CLI already authenticated."
fi

# Step 3: Run update_remote_to_cursor_bundle.sh to rename repo and directory
SCRIPT_DIR="$(dirname "$0")"
UPDATE_SCRIPT="$SCRIPT_DIR/update_remote_to_cursor_bundle.sh"

if [[ ! -x "$UPDATE_SCRIPT" ]]; then
    echo "Error: update_remote_to_cursor_bundle.sh not found or not executable in $SCRIPT_DIR"
    exit 1
fi

# Execute the update script with the provided directory
bash "$UPDATE_SCRIPT" "$OLD_REPO_DIR"
