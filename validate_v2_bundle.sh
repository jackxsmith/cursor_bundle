#!/bin/bash
# Validate v2 Bundle - Ensure everything works

echo "=== Cursor Bundle v2 Validation ==="
echo

# Check all v2 scripts exist
echo "Checking v2 scripts..."
missing=0
for script in 02-launcher 03-autoupdater 04-secure 05-secureplus 06-launcherplus 07-tkinter 09-zenity 10-select 11-preinstall 12-postinstall 13-posttest 14-install 15-docker 16-tracker 17-policycheck 22-test-cursor-suite; do
    if [[ -f "${script}-improved-v2.sh" ]] || [[ -f "${script}-improved-v2.py" ]]; then
        echo "✓ ${script} found"
    else
        echo "✗ ${script} MISSING"
        ((missing++))
    fi
done

echo
echo "Checking critical files..."
[[ -f "bump_merged-v2.sh" ]] && echo "✓ bump_merged-v2.sh found" || { echo "✗ bump_merged-v2.sh MISSING"; ((missing++)); }
[[ -f "VERSION" ]] && echo "✓ VERSION found" || { echo "✗ VERSION MISSING"; ((missing++)); }

echo
echo "Checking syntax..."
errors=0
for script in *-v2.sh bump_merged-v2.sh; do
    if [[ -f "$script" ]]; then
        if bash -n "$script" 2>/dev/null; then
            echo "✓ $script syntax OK"
        else
            echo "✗ $script syntax ERROR"
            ((errors++))
        fi
    fi
done

echo
echo "Checking Python scripts..."
for script in *-v2.py; do
    if [[ -f "$script" ]]; then
        if python3 -m py_compile "$script" 2>/dev/null; then
            echo "✓ $script compiles OK"
        else
            echo "✗ $script compile ERROR"
            ((errors++))
        fi
    fi
done

echo
echo "Checking line counts..."
violations=0
for file in *-v2.* bump_merged-v2.sh; do
    if [[ -f "$file" ]]; then
        lines=$(wc -l < "$file")
        if [[ $lines -gt 1000 ]]; then
            echo "✗ $file: $lines lines (POLICY VIOLATION)"
            ((violations++))
        else
            echo "✓ $file: $lines lines (compliant)"
        fi
    fi
done

echo
echo "=== Validation Summary ==="
echo "Missing files: $missing"
echo "Syntax errors: $errors"
echo "Policy violations: $violations"
echo
if [[ $missing -eq 0 && $errors -eq 0 && $violations -eq 0 ]]; then
    echo "✅ VALIDATION PASSED - Bundle is ready for use!"
    exit 0
else
    echo "❌ VALIDATION FAILED - Please fix issues before distribution"
    exit 1
fi