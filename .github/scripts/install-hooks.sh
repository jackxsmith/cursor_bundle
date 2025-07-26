#!/bin/bash
# Install Git hooks for policy compliance

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$SCRIPT_DIR/../hooks"
GIT_DIR="$(git rev-parse --git-dir)"
GIT_HOOKS_DIR="$GIT_DIR/hooks"

echo "Installing Git hooks..."

# Create hooks directory if it doesn't exist
mkdir -p "$GIT_HOOKS_DIR"

# Install pre-push hook
if [ -f "$HOOKS_DIR/pre-push-validate.sh" ]; then
    echo "Installing pre-push hook..."
    ln -sf "$HOOKS_DIR/pre-push-validate.sh" "$GIT_HOOKS_DIR/pre-push"
    chmod +x "$GIT_HOOKS_DIR/pre-push"
    echo "✅ Pre-push hook installed"
fi

# Create a simple pre-commit hook for basic checks
cat > "$GIT_HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash
# Pre-commit hook for basic validation

# Check for common issues
echo "Running pre-commit checks..."

# No trailing whitespace
if git diff --cached --check; then
    echo "✅ No trailing whitespace found"
else
    echo "❌ Trailing whitespace detected. Please fix before committing."
    exit 1
fi

# Check for large files (>50MB)
while IFS= read -r file; do
    if [ -f "$file" ]; then
        size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
        if [ "$size" -gt 52428800 ]; then
            echo "❌ File '$file' is larger than 50MB"
            exit 1
        fi
    fi
done < <(git diff --cached --name-only)

echo "✅ Pre-commit checks passed"
EOF

chmod +x "$GIT_HOOKS_DIR/pre-commit"
echo "✅ Pre-commit hook installed"

echo ""
echo "Git hooks installed successfully!"
echo "These hooks will help prevent:"
echo "  - Secrets in commits"
echo "  - Invalid branch names"
echo "  - Large files"
echo "  - Trailing whitespace"
echo ""
echo "To bypass hooks (not recommended): use --no-verify flag"