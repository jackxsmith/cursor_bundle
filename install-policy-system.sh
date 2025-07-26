#!/bin/bash
# Install Policy Compliance System

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly GIT_DIR="$(git rev-parse --git-dir)"
readonly HOOKS_DIR="$GIT_DIR/hooks"

echo "Installing Policy Compliance System..."

# Make policy script executable
chmod +x "$SCRIPT_DIR/policy-compliance.sh"

# Create logs directory
mkdir -p "$SCRIPT_DIR/logs/policy-compliance"

# Install pre-push hook
cat > "$HOOKS_DIR/pre-push" << 'EOF'
#!/bin/bash
# Pre-push hook for policy compliance

echo "Running policy compliance check..."

# Run the policy compliance script
if ! "$PWD/policy-compliance.sh"; then
    echo "❌ Policy compliance check failed!"
    echo "To bypass (not recommended): git push --no-verify"
    exit 1
fi

echo "✅ Policy compliance check passed"
EOF

chmod +x "$HOOKS_DIR/pre-push"

# Install pre-commit hook for basic checks
cat > "$HOOKS_DIR/pre-commit" << 'EOF'
#!/bin/bash
# Pre-commit hook for basic validation

echo "Running pre-commit policy checks..."

# Check for large files
max_size=$((50 * 1024 * 1024))  # 50MB
while IFS= read -r file; do
    if [ -f "$file" ]; then
        size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
        if [ "$size" -gt "$max_size" ]; then
            echo "❌ File '$file' exceeds size limit (50MB)"
            exit 1
        fi
    fi
done < <(git diff --cached --name-only)

# Quick secret check on staged files
patterns=(
    "ghp_[a-zA-Z0-9]{36}"
    "ghs_[a-zA-Z0-9]{36}"
    "AKIA[0-9A-Z]{16}"
)

for pattern in "${patterns[@]}"; do
    if git diff --cached | grep -E "$pattern" > /dev/null 2>&1; then
        echo "❌ Potential secret detected in staged changes"
        echo "Pattern: $pattern"
        exit 1
    fi
done

echo "✅ Pre-commit checks passed"
EOF

chmod +x "$HOOKS_DIR/pre-commit"

echo ""
echo "✅ Policy Compliance System installed successfully!"
echo ""
echo "Features:"
echo "  - Secret scanning for common patterns"
echo "  - Branch protection validation"
echo "  - File permission checks"
echo "  - Sensitive file detection"
echo "  - Detailed logging and audit trail"
echo ""
echo "To run manually: ./policy-compliance.sh"
echo "Logs location: ./logs/policy-compliance/"
echo ""
echo "To bypass hooks (not recommended): use --no-verify flag"