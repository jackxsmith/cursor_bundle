#!/bin/bash
#
# CURSOR BUNDLE v2.0 SETUP SCRIPT
# Ensures proper installation and dependency checking
#

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'

echo -e "${BOLD}=== Cursor Bundle v2.0 Setup ===${NC}"
echo

# Set permissions on all scripts
echo "Setting executable permissions..."
chmod +x "${SCRIPT_DIR}"/*.sh 2>/dev/null || true
chmod +x "${SCRIPT_DIR}"/*.py 2>/dev/null || true
echo -e "${GREEN}✓${NC} Permissions set"

# Check for required files
echo "Checking required files..."
required_files=(
    "02-launcher-improved-v2.sh"
    "03-autoupdater-improved-v2.sh" 
    "04-secure-improved-v2.sh"
    "bump_merged-v2.sh"
    "VERSION"
)

missing_files=0
for file in "${required_files[@]}"; do
    if [[ -f "${SCRIPT_DIR}/${file}" ]]; then
        echo -e "${GREEN}✓${NC} ${file}"
    else
        echo -e "${RED}✗${NC} ${file} (MISSING)"
        ((missing_files++))
    fi
done

if [[ $missing_files -gt 0 ]]; then
    echo -e "${RED}ERROR: ${missing_files} required files are missing${NC}"
    exit 1
fi

# Check for Cursor binary
echo
echo "Checking Cursor IDE binary..."
if [[ -f "${SCRIPT_DIR}/cursor.AppImage" ]]; then
    if [[ -x "${SCRIPT_DIR}/cursor.AppImage" ]]; then
        echo -e "${GREEN}✓${NC} cursor.AppImage found and executable"
    else
        chmod +x "${SCRIPT_DIR}/cursor.AppImage" 2>/dev/null
        echo -e "${YELLOW}✓${NC} cursor.AppImage found (permissions fixed)"
    fi
else
    echo -e "${YELLOW}⚠${NC} cursor.AppImage not found"
    echo "  Download from: https://cursor.sh/"
    echo "  Place in: ${SCRIPT_DIR}/cursor.AppImage"
    echo "  The launcher will work for configuration/status without it"
fi

# Check optional dependencies
echo
echo "Checking optional dependencies..."
deps_ok=0
total_deps=0

check_command() {
    local cmd="$1"
    local desc="$2"
    ((total_deps++))
    
    if command -v "$cmd" >/dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} $cmd ($desc)"
        ((deps_ok++))
    else
        echo -e "${YELLOW}⚠${NC} $cmd ($desc) - optional"
    fi
}

check_command "curl" "for auto-updates"
check_command "jq" "for JSON parsing"
check_command "python3" "for GUI components"
check_command "zenity" "for GUI dialogs"
check_command "git" "for version control"

echo
echo "Dependencies: $deps_ok/$total_deps available"

# Test basic functionality
echo
echo "Testing basic functionality..."
test_errors=0

# Test launcher status
if "${SCRIPT_DIR}/02-launcher-improved-v2.sh" --status >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Launcher status check"
else
    echo -e "${RED}✗${NC} Launcher status check failed"
    ((test_errors++))
fi

# Test version checking
if "${SCRIPT_DIR}/03-autoupdater-improved-v2.sh" --version >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Auto-updater version check"
else
    echo -e "${RED}✗${NC} Auto-updater version check failed"
    ((test_errors++))
fi

if [[ $test_errors -eq 0 ]]; then
    echo -e "${GREEN}✓${NC} All basic tests passed"
else
    echo -e "${RED}✗${NC} $test_errors tests failed"
fi

# Create desktop directories
echo
echo "Setting up configuration directories..."
mkdir -p "${HOME}/.config/cursor-launcher" 2>/dev/null || true
mkdir -p "${HOME}/.cache/cursor-launcher" 2>/dev/null || true
echo -e "${GREEN}✓${NC} Configuration directories created"

# Summary
echo
echo -e "${BOLD}=== Setup Summary ===${NC}"

if [[ $missing_files -eq 0 && $test_errors -eq 0 ]]; then
    echo -e "${GREEN}✅ Setup completed successfully!${NC}"
    echo
    echo "Next steps:"
    echo "1. Download Cursor IDE from https://cursor.sh/ (if not already done)"
    echo "2. Place as cursor.AppImage in this directory"
    echo "3. Run: ./02-launcher-improved-v2.sh"
    echo
    echo "Available commands:"
    echo "  ./02-launcher-improved-v2.sh --status    # Show status"
    echo "  ./03-autoupdater-improved-v2.sh check    # Check for updates"
    echo "  ./04-secure-improved-v2.sh status        # Security status"
    echo
else
    echo -e "${RED}❌ Setup completed with issues${NC}"
    echo "Please resolve the errors above before using the bundle"
    exit 1
fi