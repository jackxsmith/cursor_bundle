#!/usr/bin/env bash
#
# CURSOR IDE ENTERPRISE CODE TRACKER v2.0 - Professional Edition
# Professional code analysis and tracking system with policy compliance
#
# Features:
# - Professional function and dependency analysis
# - Strong error handling with self-correction
# - Comprehensive quality metrics and reporting
# - Security vulnerability scanning
# - Performance-optimized analysis engine
# - Professional HTML/JSON/CSV reporting
#

set -euo pipefail
IFS=$'\n\t'

# === CONFIGURATION ===
readonly SCRIPT_VERSION="2.0-professional"
readonly SCRIPT_NAME="$(basename "${0}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Application Configuration
readonly CURSOR_VERSION="$(cat "${SCRIPT_DIR}/VERSION" 2>/dev/null || echo "unknown")"
readonly TARGET_DIR="${1:-$SCRIPT_DIR}"

# Directory Structure
readonly BASE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/cursor-tracker"
readonly LOG_DIR="$BASE_DIR/logs"
readonly CONFIG_DIR="$BASE_DIR/config"
readonly REPORTS_DIR="$BASE_DIR/reports"
readonly CACHE_DIR="$BASE_DIR/cache"

# Log Files
readonly MAIN_LOG="$LOG_DIR/tracker_${TIMESTAMP}.log"
readonly ERROR_LOG="$LOG_DIR/tracker_error_${TIMESTAMP}.log"

# Report Files
readonly HTML_REPORT="$REPORTS_DIR/analysis_report_${TIMESTAMP}.html"
readonly JSON_REPORT="$REPORTS_DIR/analysis_report_${TIMESTAMP}.json"
readonly CSV_REPORT="$REPORTS_DIR/metrics_${TIMESTAMP}.csv"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'

# Analysis State Variables
declare -g DRY_RUN=false
declare -g QUIET_MODE=false
declare -g DEBUG_MODE=false

# Data Structures
declare -A FUNCTION_MAP=()
declare -A DEPENDENCY_MAP=()
declare -A FILE_METRICS=()
declare -A QUALITY_METRICS=(
    ["lines_of_code"]=0
    ["function_count"]=0
    ["security_issues"]=0
    ["quality_score"]=100
)
declare -a SOURCE_FILES=()
declare -a ANALYSIS_RESULTS=()

# === LOGGING AND ERROR HANDLING ===
log() {
    local level="$1"
    local message="$2"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Ensure log directory exists
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    
    # Write to log files with error handling
    {
        echo "[$timestamp] [$level] $message" >> "$MAIN_LOG"
    } 2>/dev/null || true
    
    # Console output with colors
    case "$level" in
        "CRITICAL"|"ERROR") 
            echo -e "${RED}[$level]${NC} $message" >&2
            echo "[$timestamp] [$level] $message" >> "$ERROR_LOG" 2>/dev/null || true
            ;;
        "WARN") 
            echo -e "${YELLOW}[WARN]${NC} $message" >&2
            ;;
        "PASS"|"SUCCESS") 
            echo -e "${GREEN}[✓]${NC} $message"
            ;;
        "INFO") 
            [[ "$QUIET_MODE" != "true" ]] && echo -e "${BLUE}[INFO]${NC} $message"
            ;;
        "DEBUG") 
            [[ "$DEBUG_MODE" == "true" ]] && echo -e "[DEBUG] $message"
            ;;
    esac
}

# Professional error handler with self-correction
error_handler() {
    local line_no="$1"
    local bash_command="$2"
    local exit_code="$3"
    
    log "ERROR" "Command failed at line $line_no: $bash_command (exit code: $exit_code)"
    
    # Self-correction attempts
    case "$bash_command" in
        *mkdir*)
            log "INFO" "Attempting to create missing directories..."
            ensure_directories
            ;;
        *find*)
            log "INFO" "File discovery failed, checking directory permissions..."
            if [[ ! -r "$TARGET_DIR" ]]; then
                log "ERROR" "Target directory is not readable: $TARGET_DIR"
                return 1
            fi
            ;;
        *wc*)
            log "INFO" "File processing failed, checking file accessibility..."
            # Continue with next file
            return 0
            ;;
    esac
}

# === INITIALIZATION ===
ensure_directories() {
    local dirs=("$BASE_DIR" "$LOG_DIR" "$CONFIG_DIR" "$REPORTS_DIR" "$CACHE_DIR")
    
    for dir in "${dirs[@]}"; do
        if ! mkdir -p "$dir" 2>/dev/null; then
            log "ERROR" "Failed to create directory: $dir"
            return 1
        fi
    done
    
    log "DEBUG" "Directory structure created successfully"
    return 0
}

initialize_tracker() {
    log "INFO" "Initializing Code Tracker v$SCRIPT_VERSION"
    
    # Set error handler
    trap 'error_handler ${LINENO} "$BASH_COMMAND" $?' ERR
    
    # Create directories
    ensure_directories || {
        log "CRITICAL" "Failed to initialize directory structure"
        return 1
    }
    
    # Log rotation
    find "$LOG_DIR" -name "tracker_*.log" -mtime +7 -delete 2>/dev/null || true
    
    log "PASS" "Code Tracker initialization completed"
    return 0
}

# === FILE DISCOVERY ===
discover_source_files() {
    log "INFO" "Discovering source files in: $TARGET_DIR"
    
    local file_count=0
    SOURCE_FILES=()
    
    # Discover shell scripts
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]] && [[ -r "$file" ]]; then
            SOURCE_FILES+=("$file")
            ((file_count++))
        fi
    done < <(find "$TARGET_DIR" -maxdepth 2 -type f -name "*.sh" -print0 2>/dev/null || true)
    
    # Discover Python files
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]] && [[ -r "$file" ]]; then
            SOURCE_FILES+=("$file")
            ((file_count++))
        fi
    done < <(find "$TARGET_DIR" -maxdepth 2 -type f -name "*.py" -print0 2>/dev/null || true)
    
    if [[ $file_count -eq 0 ]]; then
        log "WARN" "No source files found in target directory"
        return 1
    fi
    
    log "PASS" "Discovered $file_count source files"
    return 0
}

# === FILE ANALYSIS ===
analyze_file_metrics() {
    local file="$1"
    local file_name="$(basename "$file")"
    
    log "DEBUG" "Analyzing file metrics: $file_name"
    
    # Basic file metrics with error handling
    local line_count=0
    local code_lines=0
    local function_count=0
    
    if [[ -r "$file" ]]; then
        line_count=$(wc -l < "$file" 2>/dev/null || echo "0")
        local comment_lines=$(grep -c '^[[:space:]]*#' "$file" 2>/dev/null || echo "0")
        local blank_lines=$(grep -c '^[[:space:]]*$' "$file" 2>/dev/null || echo "0")
        code_lines=$((line_count - comment_lines - blank_lines))
        function_count=$(grep -c '^[[:space:]]*[a-zA-Z0-9_]*[[:space:]]*()' "$file" 2>/dev/null || echo "0")
    fi
    
    # Store metrics
    FILE_METRICS["$file_name"]="lines:$line_count,code:$code_lines,functions:$function_count"
    
    # Update global metrics
    QUALITY_METRICS["lines_of_code"]=$((QUALITY_METRICS["lines_of_code"] + code_lines))
    QUALITY_METRICS["function_count"]=$((QUALITY_METRICS["function_count"] + function_count))
    
    log "DEBUG" "File metrics: $file_name - Lines: $line_count, Code: $code_lines, Functions: $function_count"
}

# === FUNCTION ANALYSIS ===
analyze_functions() {
    log "INFO" "Analyzing function definitions and usage"
    
    local total_functions=0
    FUNCTION_MAP=()
    
    for file in "${SOURCE_FILES[@]}"; do
        local file_name="$(basename "$file")"
        local file_functions=0
        
        # Extract function definitions with error handling
        while IFS= read -r line; do
            # Bash function pattern
            if [[ $line =~ ^[[:space:]]*([a-zA-Z0-9_]+)[[:space:]]*\(\)[[:space:]]*\{ ]]; then
                local func_name="${BASH_REMATCH[1]}"
                FUNCTION_MAP["$func_name"]+="$file_name "
                ((file_functions++))
                ((total_functions++))
            fi
            
            # Python function pattern
            if [[ $line =~ ^[[:space:]]*def[[:space:]]+([a-zA-Z0-9_]+)[[:space:]]*\( ]]; then
                local func_name="${BASH_REMATCH[1]}"
                FUNCTION_MAP["$func_name"]+="$file_name "
                ((file_functions++))
                ((total_functions++))
            fi
        done < "$file" 2>/dev/null || {
            log "WARN" "Could not read file for function analysis: $file_name"
            continue
        }
        
        analyze_file_metrics "$file"
        
        log "DEBUG" "Functions in $file_name: $file_functions"
    done
    
    log "PASS" "Function analysis completed: $total_functions functions discovered"
    return 0
}

# === DEPENDENCY ANALYSIS ===
analyze_dependencies() {
    log "INFO" "Analyzing dependencies and imports"
    
    local total_dependencies=0
    DEPENDENCY_MAP=()
    
    for file in "${SOURCE_FILES[@]}"; do
        local file_name="$(basename "$file")"
        local file_deps=()
        
        # Analyze shell script dependencies
        if [[ "$file" == *.sh ]] || [[ "$file" == *.bash ]]; then
            # Source/include dependencies
            while IFS= read -r line; do
                if [[ $line =~ source[[:space:]]+([^[:space:]]+) ]] || [[ $line =~ \.[[:space:]]+([^[:space:]]+) ]]; then
                    local dep="${BASH_REMATCH[1]}"
                    file_deps+=("$dep")
                    ((total_dependencies++))
                fi
            done < "$file" 2>/dev/null || true
            
            # Command dependencies
            local commands=($(grep -o '\<[a-zA-Z][a-zA-Z0-9_-]*\>' "$file" 2>/dev/null | grep -E '^(curl|wget|git|python|node)$' | sort -u || true))
            for cmd in "${commands[@]}"; do
                file_deps+=("cmd:$cmd")
                ((total_dependencies++))
            done
        fi
        
        # Analyze Python dependencies
        if [[ "$file" == *.py ]]; then
            while IFS= read -r line; do
                if [[ $line =~ ^[[:space:]]*import[[:space:]]+([a-zA-Z0-9_.]+) ]] || [[ $line =~ ^[[:space:]]*from[[:space:]]+([a-zA-Z0-9_.]+)[[:space:]]+import ]]; then
                    local dep="${BASH_REMATCH[1]}"
                    file_deps+=("py:$dep")
                    ((total_dependencies++))
                fi
            done < "$file" 2>/dev/null || true
        fi
        
        # Store dependencies
        if [[ ${#file_deps[@]} -gt 0 ]]; then
            DEPENDENCY_MAP["$file_name"]="${file_deps[*]}"
        fi
        
        log "DEBUG" "Dependencies in $file_name: ${#file_deps[@]}"
    done
    
    log "PASS" "Dependency analysis completed: $total_dependencies dependencies"
    return 0
}

# === SECURITY ANALYSIS ===
analyze_security() {
    log "INFO" "Performing security vulnerability analysis"
    
    local total_issues=0
    
    for file in "${SOURCE_FILES[@]}"; do
        local file_name="$(basename "$file")"
        local file_issues=0
        
        # Check for common security issues
        local security_patterns=(
            'eval[[:space:]]*.*\$'
            'exec[[:space:]]*.*\$'
            '\$\('
            '`[^`]*`'
            'rm[[:space:]]*-rf[[:space:]]*\$'
            'chmod[[:space:]]*777'
        )
        
        for pattern in "${security_patterns[@]}"; do
            local matches=$(grep -c "$pattern" "$file" 2>/dev/null || echo "0")
            if [[ $matches -gt 0 ]]; then
                ((file_issues += matches))
                ANALYSIS_RESULTS+=("SECURITY_ISSUE:$file_name:$pattern:$matches")
            fi
        done
        
        total_issues=$((total_issues + file_issues))
        
        if [[ $file_issues -gt 0 ]]; then
            log "DEBUG" "Security issues in $file_name: $file_issues"
        fi
    done
    
    QUALITY_METRICS["security_issues"]=$total_issues
    
    if [[ $total_issues -eq 0 ]]; then
        log "PASS" "No security vulnerabilities detected"
    else
        log "WARN" "Found $total_issues potential security issues"
    fi
    
    return 0
}

# === QUALITY ANALYSIS ===
calculate_quality_score() {
    log "INFO" "Calculating overall quality score"
    
    local quality_score=100
    local total_files=${#SOURCE_FILES[@]}
    
    # Reduce score for security issues
    if [[ ${QUALITY_METRICS["security_issues"]} -gt 0 ]]; then
        quality_score=$((quality_score - QUALITY_METRICS["security_issues"] * 10))
    fi
    
    # Reduce score for very large files
    local large_files=0
    for file in "${SOURCE_FILES[@]}"; do
        local line_count=$(wc -l < "$file" 2>/dev/null || echo "0")
        if [[ $line_count -gt 1000 ]]; then
            ((large_files++))
        fi
    done
    
    if [[ $large_files -gt 0 ]]; then
        quality_score=$((quality_score - large_files * 5))
        ANALYSIS_RESULTS+=("LARGE_FILES:$large_files files exceed 1000 lines")
    fi
    
    # Ensure score doesn't go below 0
    if [[ $quality_score -lt 0 ]]; then
        quality_score=0
    fi
    
    QUALITY_METRICS["quality_score"]=$quality_score
    
    local grade="F"
    if [[ $quality_score -ge 90 ]]; then
        grade="A"
    elif [[ $quality_score -ge 80 ]]; then
        grade="B"
    elif [[ $quality_score -ge 70 ]]; then
        grade="C"
    elif [[ $quality_score -ge 60 ]]; then
        grade="D"
    fi
    
    log "INFO" "Overall quality score: $quality_score/100 (Grade: $grade)"
    return 0
}

# === REPORTING ===
generate_html_report() {
    log "INFO" "Generating HTML analysis report"
    
    cat > "$HTML_REPORT" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Code Analysis Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1000px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; }
        .header { text-align: center; margin-bottom: 30px; padding-bottom: 15px; border-bottom: 2px solid #e0e0e0; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin-bottom: 30px; }
        .metric-card { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 15px; border-radius: 8px; text-align: center; }
        .metric-number { font-size: 2em; font-weight: bold; margin: 10px 0; }
        .section { margin-bottom: 25px; }
        .section h2 { color: #333; border-bottom: 1px solid #ccc; padding-bottom: 8px; }
        .quality-score { font-size: 2.5em; font-weight: bold; text-align: center; margin: 20px 0; }
        .grade-a { color: #27ae60; }
        .grade-b { color: #2ecc71; }
        .grade-c { color: #f39c12; }
        .grade-d { color: #e67e22; }
        .grade-f { color: #e74c3c; }
        .function-list { background: #f8f9fa; padding: 15px; border-radius: 5px; }
        .function-item { padding: 8px 0; border-bottom: 1px solid #dee2e6; }
        .issue-item { padding: 5px 0; color: #e74c3c; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Code Analysis Report</h1>
            <p>Generated: $(date '+%Y-%m-%d %H:%M:%S')</p>
            <p>Target: $TARGET_DIR</p>
        </div>
        
        <div class="section">
            <h2>Quality Score</h2>
            <div class="quality-score grade-$(echo ${QUALITY_METRICS[quality_score]} | awk '{if($1>=90) print "a"; else if($1>=80) print "b"; else if($1>=70) print "c"; else if($1>=60) print "d"; else print "f"}')">${QUALITY_METRICS[quality_score]}/100</div>
        </div>
        
        <div class="metrics">
            <div class="metric-card">
                <h3>Files Analyzed</h3>
                <div class="metric-number">${#SOURCE_FILES[@]}</div>
            </div>
            <div class="metric-card">
                <h3>Functions</h3>
                <div class="metric-number">${QUALITY_METRICS[function_count]}</div>
            </div>
            <div class="metric-card">
                <h3>Lines of Code</h3>
                <div class="metric-number">${QUALITY_METRICS[lines_of_code]}</div>
            </div>
            <div class="metric-card">
                <h3>Security Issues</h3>
                <div class="metric-number">${QUALITY_METRICS[security_issues]}</div>
            </div>
        </div>
        
        <div class="section">
            <h2>Functions Discovered (${#FUNCTION_MAP[@]})</h2>
            <div class="function-list">
EOF

    # Add function details
    for func_name in "${!FUNCTION_MAP[@]}"; do
        local files="${FUNCTION_MAP[$func_name]}"
        echo "                <div class=\"function-item\"><strong>$func_name</strong> - $files</div>" >> "$HTML_REPORT"
    done

    cat >> "$HTML_REPORT" << EOF
            </div>
        </div>
        
        <div class="section">
            <h2>Analysis Results</h2>
            <div class="function-list">
EOF

    # Add analysis results
    for result in "${ANALYSIS_RESULTS[@]}"; do
        echo "                <div class=\"issue-item\">$result</div>" >> "$HTML_REPORT"
    done

    cat >> "$HTML_REPORT" << EOF
            </div>
        </div>
        
        <div style="text-align: center; margin-top: 30px; color: #666;">
            <p>Generated by Cursor IDE Code Tracker v$SCRIPT_VERSION</p>
        </div>
    </div>
</body>
</html>
EOF
    
    log "PASS" "HTML report generated: $HTML_REPORT"
}

generate_json_report() {
    log "INFO" "Generating JSON analysis report"
    
    cat > "$JSON_REPORT" << EOF
{
    "analysis_report": {
        "version": "$SCRIPT_VERSION",
        "timestamp": "$(date -Iseconds)",
        "target_directory": "$TARGET_DIR",
        "quality_metrics": {
EOF

    # Add quality metrics
    local first=true
    for metric in "${!QUALITY_METRICS[@]}"; do
        [[ "$first" != "true" ]] && echo "," >> "$JSON_REPORT"
        first=false
        echo "            \"$metric\": ${QUALITY_METRICS[$metric]}" >> "$JSON_REPORT"
    done

    cat >> "$JSON_REPORT" << EOF
        },
        "functions": {
EOF

    # Add functions
    first=true
    for func_name in "${!FUNCTION_MAP[@]}"; do
        [[ "$first" != "true" ]] && echo "," >> "$JSON_REPORT"
        first=false
        echo "            \"$func_name\": \"${FUNCTION_MAP[$func_name]}\"" >> "$JSON_REPORT"
    done

    cat >> "$JSON_REPORT" << EOF
        },
        "analysis_results": [
EOF

    # Add analysis results
    first=true
    for result in "${ANALYSIS_RESULTS[@]}"; do
        [[ "$first" != "true" ]] && echo "," >> "$JSON_REPORT"
        first=false
        echo "            \"$result\"" >> "$JSON_REPORT"
    done

    cat >> "$JSON_REPORT" << EOF
        ]
    }
}
EOF
    
    log "PASS" "JSON report generated: $JSON_REPORT"
}

generate_csv_report() {
    log "INFO" "Generating CSV metrics report"
    
    cat > "$CSV_REPORT" << EOF
Metric,Value,Description
files_analyzed,${#SOURCE_FILES[@]},Number of source files analyzed
functions_found,${#FUNCTION_MAP[@]},Number of unique functions discovered
lines_of_code,${QUALITY_METRICS[lines_of_code]},Total lines of executable code
security_issues,${QUALITY_METRICS[security_issues]},Number of potential security issues
quality_score,${QUALITY_METRICS[quality_score]},Overall quality score (0-100)
analysis_results,${#ANALYSIS_RESULTS[@]},Number of analysis findings
dependencies,${#DEPENDENCY_MAP[@]},Number of files with dependencies
EOF
    
    log "PASS" "CSV report generated: $CSV_REPORT"
}

# === MAIN EXECUTION ===
show_usage() {
    cat << EOF
Cursor IDE Code Tracker v$SCRIPT_VERSION - Professional Edition

USAGE:
    $SCRIPT_NAME [TARGET_DIRECTORY] [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -q, --quiet         Quiet mode (minimal output)
    -d, --debug         Enable debug logging
    --dry-run           Perform dry run without changes
    --version           Show version information

EXAMPLES:
    $SCRIPT_NAME                    # Analyze current directory
    $SCRIPT_NAME /path/to/code      # Analyze specific directory
    $SCRIPT_NAME --debug            # Enable debug output

REPORTS:
    HTML Report:    Visual analysis report
    JSON Report:    Machine-readable data
    CSV Report:     Metrics in spreadsheet format

Reports are saved to: $REPORTS_DIR
EOF
}

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            --version)
                echo "Cursor IDE Code Tracker v$SCRIPT_VERSION"
                exit 0
                ;;
            -q|--quiet)
                QUIET_MODE=true
                shift
                ;;
            -d|--debug)
                DEBUG_MODE=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                # Assume it's the target directory
                shift
                ;;
        esac
    done
    
    # Initialize
    initialize_tracker || {
        log "CRITICAL" "Tracker initialization failed"
        exit 1
    }
    
    # Discover source files
    discover_source_files || {
        log "ERROR" "No source files found for analysis"
        exit 1
    }
    
    # Perform analysis
    log "INFO" "Beginning comprehensive code analysis"
    
    analyze_functions || {
        log "ERROR" "Function analysis failed"
        exit 1
    }
    
    analyze_dependencies || {
        log "WARN" "Dependency analysis completed with issues"
    }
    
    analyze_security || {
        log "WARN" "Security analysis completed"
    }
    
    calculate_quality_score || {
        log "ERROR" "Quality score calculation failed"
        exit 1
    }
    
    # Generate reports
    if [[ "$DRY_RUN" != "true" ]]; then
        log "INFO" "Generating analysis reports"
        
        generate_html_report || log "WARN" "HTML report generation failed"
        generate_json_report || log "WARN" "JSON report generation failed"
        generate_csv_report || log "WARN" "CSV report generation failed"
    else
        log "INFO" "DRY RUN: Would generate analysis reports"
    fi
    
    # Final summary
    log "INFO" "=== ANALYSIS SUMMARY ==="
    log "INFO" "Files Analyzed: ${#SOURCE_FILES[@]}"
    log "INFO" "Functions Found: ${#FUNCTION_MAP[@]}"
    log "INFO" "Quality Score: ${QUALITY_METRICS[quality_score]}/100"
    log "INFO" "Security Issues: ${QUALITY_METRICS[security_issues]}"
    [[ "$DRY_RUN" != "true" ]] && log "INFO" "Reports: $REPORTS_DIR"
    
    if [[ ${QUALITY_METRICS[security_issues]} -gt 0 ]]; then
        log "WARN" "Security issues detected - review recommended"
    fi
    
    log "PASS" "Code analysis completed successfully"
    return 0
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi