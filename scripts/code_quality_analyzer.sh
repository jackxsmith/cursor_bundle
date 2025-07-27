#!/usr/bin/env bash
#
# Comprehensive Code Quality Analyzer
# Independent assessment of shell script quality without external dependencies
#

set -euo pipefail
IFS=$'\n\t'

# === QUALITY METRICS ===
declare -A QUALITY_SCORES=()
declare -A QUALITY_ISSUES=()
declare -A QUALITY_SUGGESTIONS=()

# === ANALYSIS FUNCTIONS ===

analyze_bash_script() {
    local file="$1"
    local total_score=100
    local issues=()
    local suggestions=()
    
    echo "=== ANALYZING: $file ==="
    
    # Basic file checks
    if [[ ! -f "$file" ]]; then
        echo "ERROR: File not found: $file"
        return 1
    fi
    
    # 1. Syntax validation
    echo "--- Syntax Validation ---"
    if ! bash -n "$file" 2>/dev/null; then
        issues+=("CRITICAL: Syntax errors found")
        ((total_score -= 30))
        echo "❌ SYNTAX: FAILED"
    else
        echo "✅ SYNTAX: PASSED"
    fi
    
    # 2. Shebang check
    echo "--- Shebang Analysis ---"
    local shebang=$(head -1 "$file")
    if [[ "$shebang" =~ ^#!/usr/bin/env\ bash$ ]] || [[ "$shebang" =~ ^#!/bin/bash$ ]]; then
        echo "✅ SHEBANG: Good ($shebang)"
    elif [[ "$shebang" =~ ^# ]]; then
        issues+=("MINOR: Non-standard shebang: $shebang")
        ((total_score -= 2))
        echo "⚠️ SHEBANG: Non-standard"
    else
        issues+=("MAJOR: Missing or invalid shebang")
        ((total_score -= 10))
        echo "❌ SHEBANG: Missing/Invalid"
    fi
    
    # 3. Error handling
    echo "--- Error Handling Analysis ---"
    local has_set_e=$(grep -c "set -e" "$file" 2>/dev/null || echo "0")
    local has_set_u=$(grep -c "set -u" "$file" 2>/dev/null || echo "0")
    local has_set_pipefail=$(grep -c "set -o pipefail\|set.*pipefail" "$file" 2>/dev/null || echo "0")
    local has_ifs=$(grep -c "IFS=" "$file" 2>/dev/null || echo "0")
    
    local error_handling_score=0
    if [[ $has_set_e -gt 0 ]]; then ((error_handling_score += 25)); fi
    if [[ $has_set_u -gt 0 ]]; then ((error_handling_score += 25)); fi
    if [[ $has_set_pipefail -gt 0 ]]; then ((error_handling_score += 25)); fi
    if [[ $has_ifs -gt 0 ]]; then ((error_handling_score += 25)); fi
    
    if [[ $error_handling_score -eq 100 ]]; then
        echo "✅ ERROR_HANDLING: Excellent (set -euo pipefail + IFS)"
    elif [[ $error_handling_score -ge 75 ]]; then
        echo "✅ ERROR_HANDLING: Good ($error_handling_score/100)"
        suggestions+=("Consider adding missing: set -euo pipefail and IFS setting")
    elif [[ $error_handling_score -ge 50 ]]; then
        echo "⚠️ ERROR_HANDLING: Fair ($error_handling_score/100)"
        issues+=("MODERATE: Incomplete error handling")
        ((total_score -= 10))
    else
        echo "❌ ERROR_HANDLING: Poor ($error_handling_score/100)"
        issues+=("MAJOR: Missing error handling (set -euo pipefail)")
        ((total_score -= 20))
    fi
    
    # 4. Function quality
    echo "--- Function Analysis ---"
    local function_count=$(grep -c "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*(" "$file" 2>/dev/null || echo "0")
    local documented_functions=$(grep -B1 "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*(" "$file" | grep -c "^[[:space:]]*#" 2>/dev/null || echo "0")
    
    echo "Functions found: $function_count"
    echo "Documented functions: $documented_functions"
    
    if [[ $function_count -gt 0 ]]; then
        local doc_percentage=$((documented_functions * 100 / function_count))
        if [[ $doc_percentage -ge 80 ]]; then
            echo "✅ DOCUMENTATION: Excellent ($doc_percentage%)"
        elif [[ $doc_percentage -ge 60 ]]; then
            echo "✅ DOCUMENTATION: Good ($doc_percentage%)"
            suggestions+=("Add documentation for remaining functions")
        elif [[ $doc_percentage -ge 30 ]]; then
            echo "⚠️ DOCUMENTATION: Fair ($doc_percentage%)"
            issues+=("MODERATE: Poor function documentation")
            ((total_score -= 10))
        else
            echo "❌ DOCUMENTATION: Poor ($doc_percentage%)"
            issues+=("MAJOR: Functions lack documentation")
            ((total_score -= 15))
        fi
    fi
    
    # 5. Variable usage
    echo "--- Variable Usage Analysis ---"
    local unquoted_vars=$(grep -c '\$[a-zA-Z_][a-zA-Z0-9_]*[^}]' "$file" 2>/dev/null || echo "0")
    local quoted_vars=$(grep -c '"\$[a-zA-Z_][a-zA-Z0-9_]*"' "$file" 2>/dev/null || echo "0")
    local total_vars=$((unquoted_vars + quoted_vars))
    
    if [[ $total_vars -gt 0 ]]; then
        local quoted_percentage=$((quoted_vars * 100 / total_vars))
        if [[ $quoted_percentage -ge 90 ]]; then
            echo "✅ VARIABLE_QUOTING: Excellent ($quoted_percentage%)"
        elif [[ $quoted_percentage -ge 70 ]]; then
            echo "✅ VARIABLE_QUOTING: Good ($quoted_percentage%)"
            suggestions+=("Quote remaining variable references")
        else
            echo "⚠️ VARIABLE_QUOTING: Needs improvement ($quoted_percentage%)"
            issues+=("MODERATE: Unquoted variable references")
            ((total_score -= 8))
        fi
    fi
    
    # 6. Code complexity
    echo "--- Complexity Analysis ---"
    local lines=$(wc -l < "$file")
    local cyclomatic_complexity=$(grep -c "if\|while\|for\|case\|&&\|||" "$file" 2>/dev/null || echo "0")
    local avg_complexity=$((lines > 0 ? cyclomatic_complexity * 100 / lines : 0))
    
    echo "Lines of code: $lines"
    echo "Cyclomatic complexity: $cyclomatic_complexity"
    echo "Complexity ratio: $avg_complexity per 100 lines"
    
    if [[ $avg_complexity -le 10 ]]; then
        echo "✅ COMPLEXITY: Low (maintainable)"
    elif [[ $avg_complexity -le 20 ]]; then
        echo "✅ COMPLEXITY: Moderate"
        suggestions+=("Consider breaking down complex functions")
    elif [[ $avg_complexity -le 35 ]]; then
        echo "⚠️ COMPLEXITY: High"
        issues+=("MODERATE: High complexity - consider refactoring")
        ((total_score -= 10))
    else
        echo "❌ COMPLEXITY: Very High"
        issues+=("MAJOR: Very high complexity - needs refactoring")
        ((total_score -= 20))
    fi
    
    # 7. Security patterns
    echo "--- Security Analysis ---"
    local security_issues=0
    
    # Check for potential command injection
    if grep -q "eval\|exec.*\$" "$file" 2>/dev/null; then
        issues+=("SECURITY: Potential command injection (eval/exec)")
        ((security_issues++))
        ((total_score -= 15))
    fi
    
    # Check for hardcoded secrets patterns
    if grep -qi "password\|secret\|token.*=" "$file" 2>/dev/null; then
        issues+=("SECURITY: Potential hardcoded secrets")
        ((security_issues++))
        ((total_score -= 10))
    fi
    
    # Check for insecure temp file usage
    if grep -q "/tmp/.*\$\$\|mktemp" "$file" 2>/dev/null; then
        if grep -q "mktemp" "$file" 2>/dev/null; then
            echo "✅ TEMP_FILES: Using mktemp (secure)"
        else
            issues+=("SECURITY: Insecure temp file usage")
            ((security_issues++))
            ((total_score -= 8))
        fi
    fi
    
    if [[ $security_issues -eq 0 ]]; then
        echo "✅ SECURITY: No obvious issues found"
    else
        echo "❌ SECURITY: $security_issues issues found"
    fi
    
    # 8. Best practices
    echo "--- Best Practices Analysis ---"
    local best_practices_score=0
    
    # Check for readonly variables
    if grep -q "readonly\|declare -r" "$file" 2>/dev/null; then
        ((best_practices_score += 20))
        echo "✅ Uses readonly variables"
    else
        suggestions+=("Use 'readonly' for constants")
    fi
    
    # Check for local variables in functions
    if grep -q "local " "$file" 2>/dev/null; then
        ((best_practices_score += 20))
        echo "✅ Uses local variables"
    else
        suggestions+=("Use 'local' for function variables")
    fi
    
    # Check for proper exit codes
    if grep -q "exit [0-9]\|return [0-9]" "$file" 2>/dev/null; then
        ((best_practices_score += 20))
        echo "✅ Uses proper exit codes"
    else
        suggestions+=("Use explicit exit/return codes")
    fi
    
    # Check for error messages to stderr
    if grep -q ">&2" "$file" 2>/dev/null; then
        ((best_practices_score += 20))
        echo "✅ Errors to stderr"
    else
        suggestions+=("Send error messages to stderr (>&2)")
    fi
    
    # Check for help/usage function
    if grep -q "usage\|help.*(" "$file" 2>/dev/null; then
        ((best_practices_score += 20))
        echo "✅ Has usage/help function"
    else
        suggestions+=("Add usage/help function")
    fi
    
    echo "Best practices score: $best_practices_score/100"
    if [[ $best_practices_score -lt 60 ]]; then
        ((total_score -= $((60 - best_practices_score)) / 10))
    fi
    
    # 9. Code organization
    echo "--- Organization Analysis ---"
    local has_header=$(head -10 "$file" | grep -c "^#.*" 2>/dev/null || echo "0")
    local has_sections=$(grep -c "^# ===" "$file" 2>/dev/null || echo "0")
    
    if [[ $has_header -ge 3 && $has_sections -ge 3 ]]; then
        echo "✅ ORGANIZATION: Well organized with headers and sections"
    elif [[ $has_header -ge 2 ]]; then
        echo "✅ ORGANIZATION: Good - has file header"
        suggestions+=("Add section dividers for better organization")
    else
        echo "⚠️ ORGANIZATION: Needs improvement"
        issues+=("MINOR: Missing file header or poor organization")
        ((total_score -= 5))
    fi
    
    # Final score calculation
    [[ $total_score -lt 0 ]] && total_score=0
    [[ $total_score -gt 100 ]] && total_score=100
    
    # Store results
    QUALITY_SCORES["$file"]=$total_score
    QUALITY_ISSUES["$file"]=$(IFS='|'; echo "${issues[*]}")
    QUALITY_SUGGESTIONS["$file"]=$(IFS='|'; echo "${suggestions[*]}")
    
    echo ""
    echo "=== FINAL SCORE: $total_score/100 ==="
    
    if [[ $total_score -ge 90 ]]; then
        echo "🟢 GRADE: EXCELLENT"
    elif [[ $total_score -ge 80 ]]; then
        echo "🟢 GRADE: GOOD"
    elif [[ $total_score -ge 70 ]]; then
        echo "🟡 GRADE: SATISFACTORY"
    elif [[ $total_score -ge 60 ]]; then
        echo "🟡 GRADE: NEEDS IMPROVEMENT"
    else
        echo "🔴 GRADE: POOR"
    fi
    
    echo ""
    if [[ ${#issues[@]} -gt 0 ]]; then
        echo "ISSUES FOUND:"
        printf '  - %s\n' "${issues[@]}"
        echo ""
    fi
    
    if [[ ${#suggestions[@]} -gt 0 ]]; then
        echo "SUGGESTIONS:"
        printf '  - %s\n' "${suggestions[@]}"
        echo ""
    fi
    
    echo "================================================"
    echo ""
}

# Generate summary report
generate_quality_report() {
    echo "=== CODE QUALITY SUMMARY REPORT ==="
    echo "Generated: $(date)"
    echo ""
    
    local total_files=0
    local total_score=0
    local excellent=0
    local good=0
    local satisfactory=0
    local needs_improvement=0
    local poor=0
    
    for file in "${!QUALITY_SCORES[@]}"; do
        local score=${QUALITY_SCORES[$file]}
        ((total_files++))
        ((total_score += score))
        
        if [[ $score -ge 90 ]]; then ((excellent++))
        elif [[ $score -ge 80 ]]; then ((good++))
        elif [[ $score -ge 70 ]]; then ((satisfactory++))
        elif [[ $score -ge 60 ]]; then ((needs_improvement++))
        else ((poor++))
        fi
        
        echo "📁 $(basename "$file"): $score/100"
    done
    
    if [[ $total_files -gt 0 ]]; then
        local avg_score=$((total_score / total_files))
        echo ""
        echo "OVERALL STATISTICS:"
        echo "  Average Score: $avg_score/100"
        echo "  Total Files: $total_files"
        echo "  🟢 Excellent (90+): $excellent"
        echo "  🟢 Good (80-89): $good"
        echo "  🟡 Satisfactory (70-79): $satisfactory"
        echo "  🟡 Needs Improvement (60-69): $needs_improvement"
        echo "  🔴 Poor (<60): $poor"
    fi
    
    echo ""
    echo "=== DETAILED FINDINGS ==="
    for file in "${!QUALITY_ISSUES[@]}"; do
        local issues="${QUALITY_ISSUES[$file]}"
        local suggestions="${QUALITY_SUGGESTIONS[$file]}"
        
        if [[ -n "$issues" || -n "$suggestions" ]]; then
            echo ""
            echo "📁 $(basename "$file"):"
            
            if [[ -n "$issues" ]]; then
                echo "  ISSUES:"
                IFS='|' read -ra issue_array <<< "$issues"
                for issue in "${issue_array[@]}"; do
                    [[ -n "$issue" ]] && echo "    ❌ $issue"
                done
            fi
            
            if [[ -n "$suggestions" ]]; then
                echo "  SUGGESTIONS:"
                IFS='|' read -ra suggestion_array <<< "$suggestions"
                for suggestion in "${suggestion_array[@]}"; do
                    [[ -n "$suggestion" ]] && echo "    💡 $suggestion"
                done
            fi
        fi
    done
}

# Main execution
main() {
    local target_dir="${1:-scripts/lib}"
    
    echo "Starting comprehensive code quality analysis..."
    echo "Target directory: $target_dir"
    echo ""
    
    # Find all shell scripts
    local script_files=()
    while IFS= read -r -d '' file; do
        script_files+=("$file")
    done < <(find "$target_dir" -name "*.sh" -type f -print0 2>/dev/null)
    
    if [[ ${#script_files[@]} -eq 0 ]]; then
        echo "No shell scripts found in $target_dir"
        exit 1
    fi
    
    echo "Found ${#script_files[@]} shell script(s) to analyze"
    echo ""
    
    # Analyze each file
    for file in "${script_files[@]}"; do
        analyze_bash_script "$file"
    done
    
    # Generate summary report
    generate_quality_report
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi