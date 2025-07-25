#!/bin/bash
# Install git hooks for enhanced development workflow

set -e

echo "🪝 Installing Git hooks for Cursor Bundle"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Not in a git repository"
    exit 1
fi

GIT_DIR=$(git rev-parse --git-dir)
HOOKS_DIR="$GIT_DIR/hooks"
SOURCE_HOOKS_DIR=".githooks"

# Create hooks directory if it doesn't exist
mkdir -p "$HOOKS_DIR"

# Function to install a hook
install_hook() {
    local hook_name="$1"
    local source_file="$SOURCE_HOOKS_DIR/$hook_name"
    local target_file="$HOOKS_DIR/$hook_name"
    
    if [ -f "$source_file" ]; then
        echo "📝 Installing $hook_name hook..."
        cp "$source_file" "$target_file"
        chmod +x "$target_file"
        echo "✅ $hook_name hook installed"
    else
        echo "⚠️  $source_file not found, skipping"
    fi
}

# Install available hooks
echo "🔍 Scanning for available hooks..."
if [ -d "$SOURCE_HOOKS_DIR" ]; then
    for hook_file in "$SOURCE_HOOKS_DIR"/*; do
        if [ -f "$hook_file" ]; then
            hook_name=$(basename "$hook_file")
            install_hook "$hook_name"
        fi
    done
else
    echo "❌ No .githooks directory found"
    exit 1
fi

# Set up git config for hooks
echo "⚙️  Configuring git settings..."
git config core.hooksPath ".git/hooks"

# Create hook status file
echo "📊 Creating hook status file..."
echo "# Git Hooks Installation Status" > .git_hooks_status
echo "Installed on: $(date)" >> .git_hooks_status
echo "Repository: $(git remote get-url origin 2>/dev/null || echo 'local')" >> .git_hooks_status
echo "" >> .git_hooks_status
echo "Installed hooks:" >> .git_hooks_status
ls -la "$HOOKS_DIR" | grep -v "^d" | awk '{print "  " $9}' >> .git_hooks_status

echo ""
echo "🎉 Git hooks installation completed!"
echo ""
echo "📋 Installed hooks:"
ls -la "$HOOKS_DIR" | grep -v "^d" | awk '{print "  ✓ " $9}'

echo ""
echo "🔧 Hook functionality:"
echo "  • pre-commit: Code quality checks, secret scanning"
echo "  • post-commit: Build info updates, statistics tracking"
echo ""
echo "💡 To test hooks:"
echo "  git add . && git commit -m 'test: hook validation'"