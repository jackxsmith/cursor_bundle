#!/usr/bin/env bash
#
# Multi-Layer Code Analysis Framework
# Comprehensive bug detection using multiple complementary tools
# Defense-in-depth approach for code quality assurance
#

set -euo pipefail
IFS=$'\n\t'

# Source the professional error checking framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/lib/professional_error_checking.sh" ]]; then
    source "$SCRIPT_DIR/lib/professional_error_checking.sh"
    setup_error_trap "analysis_cleanup"
else
    echo "ERROR: Professional error checking framework not found" >&2
    exit 1
fi

# === CONFIGURATION ===
readonly ANALYSIS_VERSION="1.0.0"
readonly PROJECT_ROOT="$(cd "$(dirname "$SCRIPT_DIR")" && pwd)"
readonly ANALYSIS_RESULTS_DIR="$PROJECT_ROOT/analysis-results"
readonly ANALYSIS_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Analysis configuration
declare -g ENABLE_SHELLCHECK=true
declare -g ENABLE_BASHATE=true
declare -g ENABLE_CUSTOM_PATTERNS=true
declare -g ENABLE_SECURITY_SCAN=true
declare -g ENABLE_COMPLEXITY_ANALYSIS=true
declare -g ENABLE_DEPENDENCY_CHECK=true
declare -g ENABLE_STYLE_CHECK=true
declare -g ENABLE_PERFORMANCE_ANALYSIS=true

# Results tracking
declare -A TOOL_RESULTS=()
declare -A ISSUE_COUNTS=()
declare -A TOOL_EXECUTION_TIMES=()
declare -i TOTAL_ISSUES=0
declare -i CRITICAL_ISSUES=0
declare -i HIGH_ISSUES=0
declare -i MEDIUM_ISSUES=0
declare -i LOW_ISSUES=0

# === CLEANUP ===
analysis_cleanup() {
    log_framework "INFO" "Performing analysis cleanup" "analysis_cleanup"
    
    # Clean up temporary files
    find "$ANALYSIS_RESULTS_DIR" -name "*.tmp" -delete 2>/dev/null || true
    
    # Generate final comprehensive report
    generate_comprehensive_report
}

# === TOOL MANAGEMENT ===
check_analysis_tool() {
    local tool="$1"
    local required="${2:-false}"
    local install_hint="${3:-}"
    
    if command -v "$tool" >/dev/null 2>&1; then
        log_framework "DEBUG" "Analysis tool available: $tool" "check_analysis_tool"
        return 0
    else
        if [[ "$required" == "true" ]]; then
            log_framework "ERROR" "Required analysis tool not found: $tool" "check_analysis_tool"
            [[ -n "$install_hint" ]] && log_framework "INFO" "Install hint: $install_hint" "check_analysis_tool"
            return 1
        else
            log_framework "WARN" "Optional analysis tool not found: $tool" "check_analysis_tool"
            [[ -n "$install_hint" ]] && log_framework "INFO" "Install hint: $install_hint" "check_analysis_tool"
            return 1
        fi
    fi
}

install_analysis_tools() {
    log_framework "INFO" "Checking and installing analysis tools" "install_analysis_tools"
    
    # Create a temporary install script
    local install_script="$ANALYSIS_RESULTS_DIR/install_tools.sh"
    cat > "$install_script" << 'EOF'
#!/bin/bash
# Auto-installer for code analysis tools

install_shellcheck() {
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update && sudo apt-get install -y shellcheck
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y ShellCheck
    elif command -v brew >/dev/null 2>&1; then
        brew install shellcheck
    else
        echo "Please install shellcheck manually"
        return 1
    fi
}

install_bashate() {
    if command -v pip3 >/dev/null 2>&1; then
        pip3 install --user bashate
    elif command -v pip >/dev/null 2>&1; then
        pip install --user bashate
    else
        echo "Please install bashate manually: pip install bashate"
        return 1
    fi
}

# Check and install tools
echo "Checking analysis tools..."

if ! command -v shellcheck >/dev/null 2>&1; then
    echo "Installing shellcheck..."
    install_shellcheck
fi

if ! command -v bashate >/dev/null 2>&1; then
    echo "Installing bashate..."
    install_bashate
fi

echo "Tool installation completed"
EOF
    
    chmod +x "$install_script"
    
    # Only run if user confirms
    read -p "Install missing analysis tools? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        "$install_script" || log_framework "WARN" "Some tools failed to install" "install_analysis_tools"
    fi
    
    rm -f "$install_script"
}

# === LAYER 1: SHELLCHECK ANALYSIS ===
run_shellcheck_analysis() {
    if [[ "$ENABLE_SHELLCHECK" != "true" ]]; then
        return 0
    fi
    
    log_framework "INFO" "Running ShellCheck analysis (Layer 1)" "run_shellcheck_analysis"
    
    if ! check_analysis_tool "shellcheck" false "apt-get install shellcheck OR brew install shellcheck"; then
        log_framework "WARN" "Skipping ShellCheck analysis - tool not available" "run_shellcheck_analysis"
        return 0
    fi
    
    local start_time=$(date +%s.%N)
    local shellcheck_output="$ANALYSIS_RESULTS_DIR/shellcheck_results_$ANALYSIS_TIMESTAMP.txt"
    local issue_count=0
    
    # Find all shell scripts
    local shell_scripts
    mapfile -t shell_scripts < <(find "$PROJECT_ROOT" -name "*.sh" -type f 2>/dev/null)
    
    if [[ ${#shell_scripts[@]} -eq 0 ]]; then
        log_framework "WARN" "No shell scripts found for ShellCheck analysis" "run_shellcheck_analysis"
        return 0
    fi
    
    log_framework "INFO" "Analyzing ${#shell_scripts[@]} shell scripts with ShellCheck" "run_shellcheck_analysis"
    
    {
        echo "# ShellCheck Analysis Report"
        echo "# Generated: $(date -Iseconds)"
        echo "# Scripts analyzed: ${#shell_scripts[@]}"
        echo
    } > "$shellcheck_output"
    
    for script in "${shell_scripts[@]}"; do
        echo "=== Analyzing: $script ===" >> "$shellcheck_output"
        
        local script_issues=0
        if shellcheck -f gcc "$script" >> "$shellcheck_output" 2>&1; then
            echo "No issues found" >> "$shellcheck_output"
        else
            script_issues=$(shellcheck -f gcc "$script" 2>&1 | wc -l)
            ((issue_count += script_issues))
        fi
        
        echo "Issues found: $script_issues" >> "$shellcheck_output"
        echo >> "$shellcheck_output"
    done
    
    local end_time=$(date +%s.%N)
    local execution_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    
    TOOL_RESULTS["shellcheck"]="$shellcheck_output"
    ISSUE_COUNTS["shellcheck"]="$issue_count"
    TOOL_EXECUTION_TIMES["shellcheck"]="$execution_time"
    
    ((TOTAL_ISSUES += issue_count))
    
    log_framework "INFO" "ShellCheck analysis completed: $issue_count issues found (${execution_time}s)" "run_shellcheck_analysis"
}

# === LAYER 2: BASHATE ANALYSIS ===
run_bashate_analysis() {
    if [[ "$ENABLE_BASHATE" != "true" ]]; then
        return 0
    fi
    
    log_framework "INFO" "Running Bashate analysis (Layer 2)" "run_bashate_analysis"
    
    if ! check_analysis_tool "bashate" false "pip install bashate"; then
        log_framework "WARN" "Skipping Bashate analysis - tool not available" "run_bashate_analysis"
        return 0
    fi
    
    local start_time=$(date +%s.%N)
    local bashate_output="$ANALYSIS_RESULTS_DIR/bashate_results_$ANALYSIS_TIMESTAMP.txt"
    local issue_count=0
    
    # Find all shell scripts
    local shell_scripts
    mapfile -t shell_scripts < <(find "$PROJECT_ROOT" -name "*.sh" -type f 2>/dev/null)
    
    log_framework "INFO" "Analyzing ${#shell_scripts[@]} shell scripts with Bashate" "run_bashate_analysis"
    
    {
        echo "# Bashate Analysis Report"
        echo "# Generated: $(date -Iseconds)"
        echo "# Scripts analyzed: ${#shell_scripts[@]}"
        echo
    } > "$bashate_output"
    
    for script in "${shell_scripts[@]}"; do
        echo "=== Analyzing: $script ===" >> "$bashate_output"
        
        local script_issues=0
        if bashate "$script" >> "$bashate_output" 2>&1; then
            echo "No issues found" >> "$bashate_output"
        else
            script_issues=$(bashate "$script" 2>&1 | wc -l)
            ((issue_count += script_issues))
        fi
        
        echo "Issues found: $script_issues" >> "$bashate_output"
        echo >> "$bashate_output"
    done
    
    local end_time=$(date +%s.%N)
    local execution_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    
    TOOL_RESULTS["bashate"]="$bashate_output"
    ISSUE_COUNTS["bashate"]="$issue_count"
    TOOL_EXECUTION_TIMES["bashate"]="$execution_time"
    
    ((TOTAL_ISSUES += issue_count))
    
    log_framework "INFO" "Bashate analysis completed: $issue_count issues found (${execution_time}s)" "run_bashate_analysis"
}

# === LAYER 3: CUSTOM PATTERN ANALYSIS ===
run_custom_pattern_analysis() {
    if [[ "$ENABLE_CUSTOM_PATTERNS" != "true" ]]; then
        return 0
    fi
    
    log_framework "INFO" "Running custom pattern analysis (Layer 3)" "run_custom_pattern_analysis"
    
    local start_time=$(date +%s.%N)
    local pattern_output="$ANALYSIS_RESULTS_DIR/custom_patterns_$ANALYSIS_TIMESTAMP.txt"
    local issue_count=0
    
    {
        echo "# Custom Pattern Analysis Report"
        echo "# Generated: $(date -Iseconds)"
        echo "# Patterns: Bug-prone code patterns, anti-patterns, and best practices"
        echo
    } > "$pattern_output"
    
    # Define problematic patterns
    local patterns=(
        # Dangerous patterns
        "rm -rf \$.*:CRITICAL:Dangerous rm command with variable"
        "eval.*\$.*:HIGH:Dangerous eval with variable"
        "bash -c.*\$.*:HIGH:Dangerous bash -c with variable"
        "\$\{.*:-\}.*rm:HIGH:Potential dangerous operation with default value"
        
        # Error handling issues
        "set \+e:MEDIUM:Error handling disabled"
        "2>/dev/null.*||.*true:LOW:Error suppression pattern"
        "command.*||.*echo:LOW:Command without proper error handling"
        
        # Security issues
        "curl.*http://:MEDIUM:Insecure HTTP instead of HTTPS"
        "wget.*http://:MEDIUM:Insecure HTTP instead of HTTPS"
        "password=.*:HIGH:Hardcoded password"
        "secret=.*:HIGH:Hardcoded secret"
        "api[_-]?key=.*:HIGH:Hardcoded API key"
        
        # Best practice violations
        "\[\[.*=.*\]\]:LOW:Use == instead of = in [[ ]]"
        "if.*\[.*\]:LOW:Prefer [[ ]] over [ ]"
        "function.*\(\):LOW:Prefer func() over function func()"
        "\`.*\`:LOW:Prefer \$() over backticks"
        
        # Performance issues
        "cat.*|.*grep:LOW:Useless use of cat with grep"
        "grep.*|.*wc -l:LOW:Consider grep -c instead"
        "find.*-exec.*rm:MEDIUM:Consider find -delete"
        
        # Reliability issues
        "cd.*;:HIGH:Unsafe cd without error checking"
        "mkdir.*&&:MEDIUM:Consider mkdir -p"
        "test.*-f.*&&:LOW:Consider [[ -f ]] syntax"
        
        # Maintainability issues
        "TODO:INFO:TODO comment found"
        "FIXME:MEDIUM:FIXME comment found"
        "HACK:HIGH:HACK comment found"
        "XXX:HIGH:XXX comment found"
    )
    
    # Analyze all script files
    local all_files
    mapfile -t all_files < <(find "$PROJECT_ROOT" -name "*.sh" -o -name "*.py" -type f 2>/dev/null)
    
    log_framework "INFO" "Analyzing ${#all_files[@]} files for custom patterns" "run_custom_pattern_analysis"
    
    for file in "${all_files[@]}"; do
        local file_issues=0
        echo "=== Analyzing: $file ===" >> "$pattern_output"
        
        for pattern_def in "${patterns[@]}"; do
            local pattern="${pattern_def%%:*}"
            local severity_desc="${pattern_def#*:}"
            local severity="${severity_desc%%:*}"
            local description="${severity_desc#*:}"
            
            local matches
            matches=$(grep -n -E "$pattern" "$file" 2>/dev/null || true)
            
            if [[ -n "$matches" ]]; then
                echo "[$severity] $description:" >> "$pattern_output"
                echo "$matches" | sed 's/^/  /' >> "$pattern_output"
                
                local match_count
                match_count=$(echo "$matches" | wc -l)
                ((file_issues += match_count))
                
                # Count by severity
                case "$severity" in
                    CRITICAL) ((CRITICAL_ISSUES += match_count)) ;;
                    HIGH) ((HIGH_ISSUES += match_count)) ;;
                    MEDIUM) ((MEDIUM_ISSUES += match_count)) ;;
                    LOW) ((LOW_ISSUES += match_count)) ;;
                esac
            fi
        done
        
        echo "Issues found: $file_issues" >> "$pattern_output"
        echo >> "$pattern_output"
        ((issue_count += file_issues))
    done
    
    local end_time=$(date +%s.%N)
    local execution_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    
    TOOL_RESULTS["custom_patterns"]="$pattern_output"
    ISSUE_COUNTS["custom_patterns"]="$issue_count"
    TOOL_EXECUTION_TIMES["custom_patterns"]="$execution_time"
    
    ((TOTAL_ISSUES += issue_count))
    
    log_framework "INFO" "Custom pattern analysis completed: $issue_count issues found (${execution_time}s)" "run_custom_pattern_analysis"
}

# === LAYER 4: SECURITY ANALYSIS ===
run_security_analysis() {
    if [[ "$ENABLE_SECURITY_SCAN" != "true" ]]; then
        return 0
    fi
    
    log_framework "INFO" "Running security analysis (Layer 4)" "run_security_analysis"
    
    local start_time=$(date +%s.%N)
    local security_output="$ANALYSIS_RESULTS_DIR/security_analysis_$ANALYSIS_TIMESTAMP.txt"
    local issue_count=0
    
    {
        echo "# Security Analysis Report"
        echo "# Generated: $(date -Iseconds)"
        echo "# Focus: Security vulnerabilities and unsafe practices"
        echo
    } > "$security_output"
    
    # Security-specific patterns
    local security_patterns=(
        # Command injection
        "system.*\$.*:CRITICAL:Potential command injection via system()"
        "exec.*\$.*:CRITICAL:Potential command injection via exec()"
        "popen.*\$.*:HIGH:Potential command injection via popen()"
        "os\.system.*\$.*:CRITICAL:Python command injection via os.system()"
        "subprocess.*shell=True.*\$.*:HIGH:Python shell injection risk"
        
        # Path traversal
        "\.\./:HIGH:Potential path traversal"
        "\.\.\\\\:HIGH:Potential path traversal (Windows)"
        "\$\{.*\}/\.\.:HIGH:Potential path traversal with variable"
        
        # File permissions
        "chmod 777:HIGH:Overly permissive file permissions"
        "chmod.*777:HIGH:Overly permissive file permissions"
        "umask 000:HIGH:Overly permissive umask"
        
        # Network security
        "curl.*-k:MEDIUM:Insecure CURL with certificate verification disabled"
        "wget.*--no-check-certificate:MEDIUM:Insecure wget with certificate verification disabled"
        "ssl_verify.*false:MEDIUM:SSL verification disabled"
        "verify.*false:MEDIUM:Potential certificate verification disabled"
        
        # Temporary files
        "/tmp/.*\$.*:MEDIUM:Predictable temporary file path"
        "mktemp.*XXXX:LOW:Weak temporary file randomness"
        
        # Environment variables
        "export.*PASSWORD:HIGH:Password in environment variable"
        "export.*SECRET:HIGH:Secret in environment variable"
        "export.*KEY:MEDIUM:Potential key in environment variable"
        
        # Logging sensitive data
        "echo.*password:MEDIUM:Password potentially logged"
        "print.*password:MEDIUM:Password potentially logged"
        "log.*password:MEDIUM:Password potentially logged"
    )
    
    local all_files
    mapfile -t all_files < <(find "$PROJECT_ROOT" -name "*.sh" -o -name "*.py" -type f 2>/dev/null)
    
    log_framework "INFO" "Security scanning ${#all_files[@]} files" "run_security_analysis"
    
    for file in "${all_files[@]}"; do
        local file_issues=0
        echo "=== Security scan: $file ===" >> "$security_output"
        
        for pattern_def in "${security_patterns[@]}"; do
            local pattern="${pattern_def%%:*}"
            local severity_desc="${pattern_def#*:}"
            local severity="${severity_desc%%:*}"
            local description="${severity_desc#*:}"
            
            local matches
            matches=$(grep -n -i -E "$pattern" "$file" 2>/dev/null || true)
            
            if [[ -n "$matches" ]]; then
                echo "[$severity] $description:" >> "$security_output"
                echo "$matches" | sed 's/^/  /' >> "$security_output"
                
                local match_count
                match_count=$(echo "$matches" | wc -l)
                ((file_issues += match_count))
                
                case "$severity" in
                    CRITICAL) ((CRITICAL_ISSUES += match_count)) ;;
                    HIGH) ((HIGH_ISSUES += match_count)) ;;
                    MEDIUM) ((MEDIUM_ISSUES += match_count)) ;;
                    LOW) ((LOW_ISSUES += match_count)) ;;
                esac
            fi
        done
        
        echo "Security issues found: $file_issues" >> "$security_output"
        echo >> "$security_output"
        ((issue_count += file_issues))
    done
    
    local end_time=$(date +%s.%N)
    local execution_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    
    TOOL_RESULTS["security"]="$security_output"
    ISSUE_COUNTS["security"]="$issue_count"
    TOOL_EXECUTION_TIMES["security"]="$execution_time"
    
    ((TOTAL_ISSUES += issue_count))
    
    log_framework "INFO" "Security analysis completed: $issue_count issues found (${execution_time}s)" "run_security_analysis"
}

# === LAYER 5: COMPLEXITY ANALYSIS ===
run_complexity_analysis() {
    if [[ "$ENABLE_COMPLEXITY_ANALYSIS" != "true" ]]; then
        return 0
    fi
    
    log_framework "INFO" "Running complexity analysis (Layer 5)" "run_complexity_analysis"
    
    local start_time=$(date +%s.%N)
    local complexity_output="$ANALYSIS_RESULTS_DIR/complexity_analysis_$ANALYSIS_TIMESTAMP.txt"
    local issue_count=0
    
    {
        echo "# Complexity Analysis Report"
        echo "# Generated: $(date -Iseconds)"
        echo "# Focus: Code complexity, maintainability, and readability"
        echo
    } > "$complexity_output"
    
    local shell_scripts
    mapfile -t shell_scripts < <(find "$PROJECT_ROOT" -name "*.sh" -type f 2>/dev/null)
    
    log_framework "INFO" "Analyzing complexity of ${#shell_scripts[@]} shell scripts" "run_complexity_analysis"
    
    for script in "${shell_scripts[@]}"; do
        echo "=== Complexity analysis: $script ===" >> "$complexity_output"
        
        # Calculate various complexity metrics
        local lines_of_code
        lines_of_code=$(grep -c -v "^\s*#\|^\s*$" "$script" 2>/dev/null || echo "0")
        
        local function_count
        function_count=$(grep -c "^[a-zA-Z_][a-zA-Z0-9_]*\s*()" "$script" 2>/dev/null || echo "0")
        
        local if_statements
        if_statements=$(grep -c "^\s*if\s" "$script" 2>/dev/null || echo "0")
        
        local for_loops
        for_loops=$(grep -c "^\s*for\s" "$script" 2>/dev/null || echo "0")
        
        local while_loops
        while_loops=$(grep -c "^\s*while\s" "$script" 2>/dev/null || echo "0")
        
        local nested_depth
        nested_depth=$(awk '{
            depth = 0
            max_depth = 0
            for(i=1; i<=length($0); i++) {
                char = substr($0, i, 1)
                if(char == "{") depth++
                else if(char == "}") depth--
                if(depth > max_depth) max_depth = depth
            }
            if(max_depth > global_max) global_max = max_depth
        } END { print global_max+0 }' "$script" 2>/dev/null || echo "0")
        
        local complexity_score=$((lines_of_code + function_count * 5 + if_statements * 2 + for_loops * 3 + while_loops * 3 + nested_depth * 10))
        
        # Report metrics
        echo "Lines of code: $lines_of_code" >> "$complexity_output"
        echo "Functions: $function_count" >> "$complexity_output"
        echo "If statements: $if_statements" >> "$complexity_output"
        echo "For loops: $for_loops" >> "$complexity_output"
        echo "While loops: $while_loops" >> "$complexity_output"
        echo "Max nesting depth: $nested_depth" >> "$complexity_output"
        echo "Complexity score: $complexity_score" >> "$complexity_output"
        
        # Flag high complexity
        local file_issues=0
        if [[ $lines_of_code -gt 500 ]]; then
            echo "[MEDIUM] File too long: $lines_of_code lines (consider splitting)" >> "$complexity_output"
            ((file_issues++))
        fi
        
        if [[ $function_count -gt 20 ]]; then
            echo "[MEDIUM] Too many functions: $function_count (consider refactoring)" >> "$complexity_output"
            ((file_issues++))
        fi
        
        if [[ $nested_depth -gt 5 ]]; then
            echo "[HIGH] Deep nesting detected: $nested_depth levels (consider refactoring)" >> "$complexity_output"
            ((file_issues++))
        fi
        
        if [[ $complexity_score -gt 1000 ]]; then
            echo "[HIGH] High complexity score: $complexity_score (consider simplification)" >> "$complexity_output"
            ((file_issues++))
        fi
        
        echo "Complexity issues: $file_issues" >> "$complexity_output"
        echo >> "$complexity_output"
        ((issue_count += file_issues))
    done
    
    local end_time=$(date +%s.%N)
    local execution_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    
    TOOL_RESULTS["complexity"]="$complexity_output"
    ISSUE_COUNTS["complexity"]="$issue_count"
    TOOL_EXECUTION_TIMES["complexity"]="$execution_time"
    
    ((TOTAL_ISSUES += issue_count))
    
    log_framework "INFO" "Complexity analysis completed: $issue_count issues found (${execution_time}s)" "run_complexity_analysis"
}

# === LAYER 6: STYLE AND CONVENTION ANALYSIS ===
run_style_analysis() {
    if [[ "$ENABLE_STYLE_CHECK" != "true" ]]; then
        return 0
    fi
    
    log_framework "INFO" "Running style and convention analysis (Layer 6)" "run_style_analysis"
    
    local start_time=$(date +%s.%N)
    local style_output="$ANALYSIS_RESULTS_DIR/style_analysis_$ANALYSIS_TIMESTAMP.txt"
    local issue_count=0
    
    {
        echo "# Style and Convention Analysis Report"
        echo "# Generated: $(date -Iseconds)"
        echo "# Focus: Coding style, naming conventions, and best practices"
        echo
    } > "$style_output"
    
    local shell_scripts
    mapfile -t shell_scripts < <(find "$PROJECT_ROOT" -name "*.sh" -type f 2>/dev/null)
    
    log_framework "INFO" "Analyzing style of ${#shell_scripts[@]} shell scripts" "run_style_analysis"
    
    for script in "${shell_scripts[@]}"; do
        echo "=== Style analysis: $script ===" >> "$style_output"
        local file_issues=0
        
        # Check for shebang
        if ! head -1 "$script" | grep -q "^#!/"; then
            echo "[MEDIUM] Missing shebang line" >> "$style_output"
            ((file_issues++))
        fi
        
        # Check for proper error handling setup
        if ! grep -q "set -e" "$script"; then
            echo "[MEDIUM] Missing 'set -e' for error handling" >> "$style_output"
            ((file_issues++))
        fi
        
        # Check for IFS setting
        if ! grep -q "IFS=" "$script"; then
            echo "[LOW] Missing IFS setting for safety" >> "$style_output"
            ((file_issues++))
        fi
        
        # Check indentation consistency
        local tab_lines
        tab_lines=$(grep -c "^[[:space:]]*\t" "$script" 2>/dev/null || echo "0")
        local space_lines
        space_lines=$(grep -c "^    " "$script" 2>/dev/null || echo "0")
        
        if [[ $tab_lines -gt 0 ]] && [[ $space_lines -gt 0 ]]; then
            echo "[LOW] Mixed indentation (tabs and spaces)" >> "$style_output"
            ((file_issues++))
        fi
        
        # Check for long lines
        local long_lines
        long_lines=$(awk 'length > 120 { count++ } END { print count+0 }' "$script")
        if [[ $long_lines -gt 0 ]]; then
            echo "[LOW] $long_lines lines exceed 120 characters" >> "$style_output"
            ((file_issues++))
        fi
        
        # Check variable naming
        local bad_vars
        bad_vars=$(grep -o '\$[A-Z][A-Z_]*[a-z]' "$script" 2>/dev/null | wc -l || echo "0")
        if [[ $bad_vars -gt 0 ]]; then
            echo "[LOW] Inconsistent variable naming (mixed case)" >> "$style_output"
            ((file_issues++))
        fi
        
        # Check for hardcoded paths
        local hardcoded_paths
        hardcoded_paths=$(grep -c "/usr/\|/opt/\|/home/" "$script" 2>/dev/null || echo "0")
        if [[ $hardcoded_paths -gt 2 ]]; then
            echo "[MEDIUM] Many hardcoded paths found ($hardcoded_paths)" >> "$style_output"
            ((file_issues++))
        fi
        
        echo "Style issues found: $file_issues" >> "$style_output"
        echo >> "$style_output"
        ((issue_count += file_issues))
    done
    
    local end_time=$(date +%s.%N)
    local execution_time=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    
    TOOL_RESULTS["style"]="$style_output"
    ISSUE_COUNTS["style"]="$issue_count"
    TOOL_EXECUTION_TIMES["style"]="$execution_time"
    
    ((TOTAL_ISSUES += issue_count))
    
    log_framework "INFO" "Style analysis completed: $issue_count issues found (${execution_time}s)" "run_style_analysis"
}

# === COMPREHENSIVE REPORTING ===
generate_comprehensive_report() {
    local main_report="$ANALYSIS_RESULTS_DIR/comprehensive_analysis_report_$ANALYSIS_TIMESTAMP.html"
    
    log_framework "INFO" "Generating comprehensive analysis report" "generate_comprehensive_report"
    
    cat > "$main_report" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Multi-Layer Code Analysis Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { background: #2c3e50; color: white; padding: 20px; border-radius: 10px; margin-bottom: 20px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-bottom: 30px; }
        .metric { background: #ecf0f1; padding: 15px; border-radius: 8px; text-align: center; }
        .metric-value { font-size: 2em; font-weight: bold; color: #2c3e50; }
        .metric-label { font-size: 0.9em; color: #7f8c8d; margin-top: 5px; }
        .critical { background: #e74c3c; color: white; }
        .high { background: #f39c12; color: white; }
        .medium { background: #f1c40f; color: white; }
        .low { background: #27ae60; color: white; }
        .tool-results { margin-bottom: 30px; }
        .tool { background: #ffffff; border: 1px solid #bdc3c7; border-radius: 8px; margin-bottom: 15px; }
        .tool-header { background: #34495e; color: white; padding: 15px; border-radius: 8px 8px 0 0; cursor: pointer; }
        .tool-content { padding: 15px; display: none; }
        .tool-summary { display: flex; justify-content: space-between; align-items: center; }
        .recommendations { background: #3498db; color: white; padding: 20px; border-radius: 10px; margin-top: 30px; }
        .footer { text-align: center; color: #7f8c8d; margin-top: 30px; padding-top: 20px; border-top: 1px solid #bdc3c7; }
    </style>
    <script>
        function toggleTool(id) {
            var content = document.getElementById(id);
            content.style.display = content.style.display === 'none' ? 'block' : 'none';
        }
    </script>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Multi-Layer Code Analysis Report</h1>
            <p>Generated: $(date -Iseconds) | Version: $ANALYSIS_VERSION</p>
            <p>Project: $(basename "$PROJECT_ROOT") | Total Files Analyzed: $(find "$PROJECT_ROOT" -name "*.sh" -o -name "*.py" | wc -l)</p>
        </div>
        
        <div class="summary">
            <div class="metric">
                <div class="metric-value">$TOTAL_ISSUES</div>
                <div class="metric-label">Total Issues</div>
            </div>
            <div class="metric critical">
                <div class="metric-value">$CRITICAL_ISSUES</div>
                <div class="metric-label">Critical</div>
            </div>
            <div class="metric high">
                <div class="metric-value">$HIGH_ISSUES</div>
                <div class="metric-label">High</div>
            </div>
            <div class="metric medium">
                <div class="metric-value">$MEDIUM_ISSUES</div>
                <div class="metric-label">Medium</div>
            </div>
            <div class="metric low">
                <div class="metric-value">$LOW_ISSUES</div>
                <div class="metric-label">Low</div>
            </div>
        </div>
        
        <div class="tool-results">
            <h2>Analysis Tools Results</h2>
EOF
    
    # Add tool results
    for tool in "${!TOOL_RESULTS[@]}"; do
        local result_file="${TOOL_RESULTS[$tool]}"
        local issue_count="${ISSUE_COUNTS[$tool]}"
        local exec_time="${TOOL_EXECUTION_TIMES[$tool]}"
        
        cat >> "$main_report" << EOF
            <div class="tool">
                <div class="tool-header" onclick="toggleTool('${tool}_content')">
                    <div class="tool-summary">
                        <span>$tool Analysis</span>
                        <span>$issue_count issues | ${exec_time}s</span>
                    </div>
                </div>
                <div id="${tool}_content" class="tool-content">
                    <pre>$(cat "$result_file" 2>/dev/null | head -50)</pre>
                    <p><a href="$(basename "$result_file")">View full report</a></p>
                </div>
            </div>
EOF
    done
    
    cat >> "$main_report" << EOF
        </div>
        
        <div class="recommendations">
            <h2>Recommendations</h2>
            <ol>
                <li><strong>Critical Issues</strong>: Address immediately - these may cause security vulnerabilities or system failures</li>
                <li><strong>High Issues</strong>: Fix in current sprint - these affect reliability and security</li>
                <li><strong>Medium Issues</strong>: Plan for next release - these improve maintainability and performance</li>
                <li><strong>Low Issues</strong>: Address during refactoring - these enhance code quality and consistency</li>
            </ol>
            <p><strong>Defense-in-Depth Validation</strong>: This report uses multiple analysis tools to catch different types of issues. Each tool complements the others to provide comprehensive coverage.</p>
        </div>
        
        <div class="footer">
            <p>Multi-Layer Code Analysis Framework v$ANALYSIS_VERSION</p>
            <p>Total analysis time: $(echo "${TOOL_EXECUTION_TIMES[@]}" | tr ' ' '\n' | awk '{sum+=$1} END {print sum}')s</p>
        </div>
    </div>
</body>
</html>
EOF
    
    # Generate text summary for console
    cat << EOF

=== MULTI-LAYER CODE ANALYSIS SUMMARY ===
Total Issues Found: $TOTAL_ISSUES
├── Critical: $CRITICAL_ISSUES
├── High: $HIGH_ISSUES  
├── Medium: $MEDIUM_ISSUES
└── Low: $LOW_ISSUES

Tool Results:
EOF
    
    for tool in "${!ISSUE_COUNTS[@]}"; do
        printf "├── %-15s: %3d issues (%ss)\n" "$tool" "${ISSUE_COUNTS[$tool]}" "${TOOL_EXECUTION_TIMES[$tool]}"
    done
    
    echo
    echo "Comprehensive Report: $main_report"
    echo "Individual Reports: $ANALYSIS_RESULTS_DIR/"
    echo
    
    log_framework "INFO" "Comprehensive analysis report generated: $main_report" "generate_comprehensive_report"
}

# === MAIN EXECUTION ===
show_usage() {
    cat << EOF
Multi-Layer Code Analysis Framework v$ANALYSIS_VERSION

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --install-tools     Install missing analysis tools
    --layer=N           Run specific layer (1-6)
    --disable-layer=N   Disable specific layer
    --quick             Quick analysis (disable slow tools)
    --comprehensive     Full comprehensive analysis
    --help, -h          Show this help

ANALYSIS LAYERS:
    Layer 1: ShellCheck - Shell script linting
    Layer 2: Bashate - Bash style checking
    Layer 3: Custom Patterns - Project-specific patterns
    Layer 4: Security Analysis - Security vulnerability scanning
    Layer 5: Complexity Analysis - Code complexity metrics
    Layer 6: Style Analysis - Coding style and conventions

EXAMPLES:
    $0                          # Run all layers
    $0 --comprehensive          # Full analysis with all options
    $0 --layer=1 --layer=4      # Run only ShellCheck and Security
    $0 --disable-layer=5        # Skip complexity analysis
    $0 --quick                  # Quick analysis (essential layers only)

EOF
}

main() {
    local specific_layers=()
    local disabled_layers=()
    local install_tools_requested=false
    local quick_mode=false
    local comprehensive_mode=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --install-tools)
                install_tools_requested=true
                ;;
            --layer=*)
                specific_layers+=("${1#*=}")
                ;;
            --disable-layer=*)
                disabled_layers+=("${1#*=}")
                ;;
            --quick)
                quick_mode=true
                ;;
            --comprehensive)
                comprehensive_mode=true
                ;;
            --help|-h)
                show_usage
                exit 0
                ;;
            *)
                log_framework "ERROR" "Unknown option: $1" "main"
                show_usage
                exit 1
                ;;
        esac
        shift
    done
    
    log_framework "INFO" "Starting Multi-Layer Code Analysis v$ANALYSIS_VERSION"
    
    # Create results directory
    mkdir -p "$ANALYSIS_RESULTS_DIR"
    
    # Install tools if requested
    if [[ "$install_tools_requested" == "true" ]]; then
        install_analysis_tools
    fi
    
    # Configure analysis based on mode
    if [[ "$quick_mode" == "true" ]]; then
        ENABLE_COMPLEXITY_ANALYSIS=false
        ENABLE_STYLE_CHECK=false
        log_framework "INFO" "Quick mode enabled - running essential layers only"
    fi
    
    if [[ "$comprehensive_mode" == "true" ]]; then
        # Enable all layers
        ENABLE_SHELLCHECK=true
        ENABLE_BASHATE=true
        ENABLE_CUSTOM_PATTERNS=true
        ENABLE_SECURITY_SCAN=true
        ENABLE_COMPLEXITY_ANALYSIS=true
        ENABLE_STYLE_CHECK=true
        log_framework "INFO" "Comprehensive mode enabled - running all layers"
    fi
    
    # Handle specific layer selection
    if [[ ${#specific_layers[@]} -gt 0 ]]; then
        # Disable all layers first
        ENABLE_SHELLCHECK=false
        ENABLE_BASHATE=false
        ENABLE_CUSTOM_PATTERNS=false
        ENABLE_SECURITY_SCAN=false
        ENABLE_COMPLEXITY_ANALYSIS=false
        ENABLE_STYLE_CHECK=false
        
        # Enable selected layers
        for layer in "${specific_layers[@]}"; do
            case "$layer" in
                1) ENABLE_SHELLCHECK=true ;;
                2) ENABLE_BASHATE=true ;;
                3) ENABLE_CUSTOM_PATTERNS=true ;;
                4) ENABLE_SECURITY_SCAN=true ;;
                5) ENABLE_COMPLEXITY_ANALYSIS=true ;;
                6) ENABLE_STYLE_CHECK=true ;;
                *) log_framework "WARN" "Invalid layer number: $layer" "main" ;;
            esac
        done
    fi
    
    # Handle disabled layers
    for layer in "${disabled_layers[@]}"; do
        case "$layer" in
            1) ENABLE_SHELLCHECK=false ;;
            2) ENABLE_BASHATE=false ;;
            3) ENABLE_CUSTOM_PATTERNS=false ;;
            4) ENABLE_SECURITY_SCAN=false ;;
            5) ENABLE_COMPLEXITY_ANALYSIS=false ;;
            6) ENABLE_STYLE_CHECK=false ;;
            *) log_framework "WARN" "Invalid layer number: $layer" "main" ;;
        esac
    done
    
    # Run analysis layers
    log_framework "INFO" "Beginning multi-layer code analysis"
    
    run_shellcheck_analysis
    run_bashate_analysis
    run_custom_pattern_analysis
    run_security_analysis
    run_complexity_analysis
    run_style_analysis
    
    # Generate comprehensive report
    generate_comprehensive_report
    
    # Exit with appropriate code
    if [[ $CRITICAL_ISSUES -gt 0 ]]; then
        log_framework "ERROR" "Analysis completed with $CRITICAL_ISSUES critical issues"
        exit 2
    elif [[ $HIGH_ISSUES -gt 0 ]]; then
        log_framework "WARN" "Analysis completed with $HIGH_ISSUES high priority issues"
        exit 1
    else
        log_framework "INFO" "Analysis completed successfully"
        exit 0
    fi
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi