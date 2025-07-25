#!/usr/bin/env bash
#
# PROFESSIONAL CURSOR IDE PROJECT TRACKER v2.0
# Enterprise-Grade Code Analysis and Monitoring System
#
# Enhanced Features:
# - Robust project tracking and analysis
# - Self-correcting metric collection
# - Advanced dependency monitoring
# - Professional reporting and analytics
# - Automated quality assessment
# - Performance optimization
#

set -euo pipefail
IFS=$'\n\t'

# === CONFIGURATION ===
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="$(basename "${0}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Analysis Configuration
readonly TARGET_DIR="${1:-$SCRIPT_DIR}"
readonly ANALYSIS_ID="analysis_${TIMESTAMP}"

# Directory Structure
readonly BASE_DIR="${HOME}/.cache/cursor/tracker"
readonly LOG_DIR="${BASE_DIR}/logs"
readonly REPORTS_DIR="${BASE_DIR}/reports"
readonly METRICS_DIR="${BASE_DIR}/metrics"
readonly TEMP_DIR="$(mktemp -d -t cursor_tracker_XXXXXX)"

# Log Files
readonly MAIN_LOG="${LOG_DIR}/tracker_${TIMESTAMP}.log"
readonly ERROR_LOG="${LOG_DIR}/tracker_errors_${TIMESTAMP}.log"
readonly ANALYSIS_LOG="${LOG_DIR}/analysis_${TIMESTAMP}.log"

# Report Files
readonly JSON_REPORT="${REPORTS_DIR}/report_${TIMESTAMP}.json"
readonly HTML_REPORT="${REPORTS_DIR}/report_${TIMESTAMP}.html"
readonly METRICS_CSV="${METRICS_DIR}/metrics_${TIMESTAMP}.csv"

# Analysis Variables
declare -A FILE_METRICS
declare -A PROJECT_STATS
declare -A QUALITY_SCORES
declare -g DRY_RUN=false
declare -g VERBOSE=false
declare -g INCLUDE_TESTS=false

# === UTILITY FUNCTIONS ===

# Enhanced logging
log() {
    local level="$1"
    local message="$2"
    local timestamp="$(date -Iseconds)"
    
    echo "[${timestamp}] ${level}: ${message}" >> "$MAIN_LOG"
    
    case "$level" in
        ERROR) 
            echo "[${timestamp}] ${level}: ${message}" >> "$ERROR_LOG"
            echo -e "\033[0;31m[ERROR]\033[0m ${message}" >&2
            ;;
        WARN) 
            echo -e "\033[1;33m[WARN]\033[0m ${message}"
            ;;
        PASS) 
            echo -e "\033[0;32m[✓]\033[0m ${message}"
            ;;
        INFO) 
            echo -e "\033[0;34m[INFO]\033[0m ${message}"
            ;;
        DEBUG) 
            [[ "$VERBOSE" == "true" ]] && echo -e "\033[0;36m[DEBUG]\033[0m ${message}"
            ;;
    esac
}

# Ensure directory with error handling
ensure_directory() {
    local dir="$1"
    local max_attempts=3
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if [[ -d "$dir" ]]; then
            return 0
        elif mkdir -p "$dir" 2>/dev/null; then
            log "DEBUG" "Created directory: $dir"
            return 0
        fi
        
        ((attempt++))
        [[ $attempt -lt $max_attempts ]] && sleep 0.5
    done
    
    log "ERROR" "Failed to create directory: $dir"
    return 1
}

# Initialize directories
initialize_directories() {
    local dirs=("$LOG_DIR" "$REPORTS_DIR" "$METRICS_DIR")
    
    for dir in "${dirs[@]}"; do
        if ! ensure_directory "$dir"; then
            echo "Failed to initialize directories"
            return 1
        fi
    done
    
    # Log rotation
    find "$LOG_DIR" -name "tracker_*.log" -mtime +7 -delete 2>/dev/null || true
    find "$REPORTS_DIR" -name "report_*.html" -mtime +30 -delete 2>/dev/null || true
    
    return 0
}

# Cleanup function
cleanup() {
    [[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
    
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        log "PASS" "Project tracking completed successfully"
    else
        log "ERROR" "Project tracking failed with exit code: $exit_code"
    fi
}

trap cleanup EXIT
trap 'exit 130' INT TERM

# === ANALYSIS FUNCTIONS ===

# Validate target directory
validate_target() {
    log "INFO" "Validating target directory: $TARGET_DIR"
    
    if [[ ! -d "$TARGET_DIR" ]]; then
        log "ERROR" "Target directory does not exist: $TARGET_DIR"
        return 1
    fi
    
    if [[ ! -r "$TARGET_DIR" ]]; then
        log "ERROR" "Target directory is not readable: $TARGET_DIR"
        return 1
    fi
    
    # Check if directory contains analyzable files
    local file_count=$(find "$TARGET_DIR" -type f \( -name "*.sh" -o -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.json" -o -name "*.md" \) | wc -l)
    
    if [[ $file_count -eq 0 ]]; then
        log "WARN" "No analyzable files found in target directory"
        return 1
    fi
    
    PROJECT_STATS[target_dir]="$TARGET_DIR"
    PROJECT_STATS[file_count]="$file_count"
    
    log "PASS" "Target validation completed ($file_count files found)"
    return 0
}

# Analyze file metrics
analyze_files() {
    log "INFO" "Analyzing project files"
    
    local analyzed_files=0
    local total_lines=0
    local total_size=0
    
    # File extensions to analyze
    local extensions=("*.sh" "*.py" "*.js" "*.ts" "*.json" "*.md" "*.txt" "*.yml" "*.yaml")
    
    for ext in "${extensions[@]}"; do
        while IFS= read -r -d '' file; do
            # Skip hidden files and directories unless verbose
            if [[ "$VERBOSE" != "true" ]] && [[ "$(basename "$file")" =~ ^\. ]]; then
                continue
            fi
            
            # Skip test files unless explicitly included
            if [[ "$INCLUDE_TESTS" != "true" ]] && [[ "$file" =~ test|spec ]]; then
                continue
            fi
            
            analyze_file "$file"
            ((analyzed_files++))
            
        done < <(find "$TARGET_DIR" -name "$ext" -type f -print0 2>/dev/null)
    done
    
    # Calculate totals
    for file in "${!FILE_METRICS[@]}"; do
        if [[ "$file" =~ _lines$ ]]; then
            total_lines=$((total_lines + FILE_METRICS[$file]))
        elif [[ "$file" =~ _size$ ]]; then
            total_size=$((total_size + FILE_METRICS[$file]))
        fi
    done
    
    PROJECT_STATS[analyzed_files]="$analyzed_files"
    PROJECT_STATS[total_lines]="$total_lines"
    PROJECT_STATS[total_size]="$total_size"
    PROJECT_STATS[avg_file_size]="$((total_size / (analyzed_files > 0 ? analyzed_files : 1)))"
    
    log "PASS" "File analysis completed ($analyzed_files files, $total_lines lines)"
    return 0
}

# Analyze individual file
analyze_file() {
    local file="$1"
    local filename="$(basename "$file")"
    local extension="${filename##*.}"
    
    log "DEBUG" "Analyzing file: $file"
    
    # Basic metrics
    local size=$(stat -c%s "$file" 2>/dev/null || echo "0")
    local lines=$(wc -l < "$file" 2>/dev/null || echo "0")
    local chars=$(wc -c < "$file" 2>/dev/null || echo "0")
    
    FILE_METRICS["${filename}_size"]="$size"
    FILE_METRICS["${filename}_lines"]="$lines"
    FILE_METRICS["${filename}_chars"]="$chars"
    FILE_METRICS["${filename}_extension"]="$extension"
    
    # Content analysis based on file type
    case "$extension" in
        sh|bash)
            analyze_shell_script "$file" "$filename"
            ;;
        py)
            analyze_python_file "$file" "$filename"
            ;;
        js|ts)
            analyze_javascript_file "$file" "$filename"
            ;;
        json)
            analyze_json_file "$file" "$filename"
            ;;
        md)
            analyze_markdown_file "$file" "$filename"
            ;;
    esac
}

# Analyze shell scripts
analyze_shell_script() {
    local file="$1"
    local filename="$2"
    
    # Count functions
    local function_count=$(grep -c "^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*(" "$file" 2>/dev/null || echo "0")
    
    # Check for best practices
    local has_shebang=$(head -1 "$file" | grep -c "^#!" || echo "0")
    local has_set_flags=$(grep -c "set -[euo]" "$file" 2>/dev/null || echo "0")
    local has_error_handling=$(grep -c "trap\|exit\|return" "$file" 2>/dev/null || echo "0")
    
    FILE_METRICS["${filename}_functions"]="$function_count"
    FILE_METRICS["${filename}_has_shebang"]="$has_shebang"
    FILE_METRICS["${filename}_has_set_flags"]="$has_set_flags"
    FILE_METRICS["${filename}_has_error_handling"]="$has_error_handling"
    
    # Quality score (0-100)
    local quality_score=$(( (has_shebang * 25) + (has_set_flags * 25) + (has_error_handling > 0 ? 25 : 0) + (function_count > 0 ? 25 : 0) ))
    QUALITY_SCORES["$filename"]="$quality_score"
    
    log "DEBUG" "Shell script analysis: $filename (functions: $function_count, quality: $quality_score)"
}

# Analyze Python files
analyze_python_file() {
    local file="$1"
    local filename="$2"
    
    # Count classes and functions
    local class_count=$(grep -c "^class " "$file" 2>/dev/null || echo "0")
    local function_count=$(grep -c "^def " "$file" 2>/dev/null || echo "0")
    local import_count=$(grep -c "^import\|^from.*import" "$file" 2>/dev/null || echo "0")
    
    FILE_METRICS["${filename}_classes"]="$class_count"
    FILE_METRICS["${filename}_functions"]="$function_count"
    FILE_METRICS["${filename}_imports"]="$import_count"
    
    # Simple quality assessment
    local has_docstring=$(grep -c '"""' "$file" 2>/dev/null || echo "0")
    local quality_score=$(( (has_docstring > 0 ? 40 : 0) + (function_count > 0 ? 30 : 0) + (class_count > 0 ? 30 : 0) ))
    QUALITY_SCORES["$filename"]="$quality_score"
    
    log "DEBUG" "Python analysis: $filename (classes: $class_count, functions: $function_count)"
}

# Analyze JavaScript/TypeScript files
analyze_javascript_file() {
    local file="$1"
    local filename="$2"
    
    # Count functions and classes
    local function_count=$(grep -c "function\|=>" "$file" 2>/dev/null || echo "0")
    local class_count=$(grep -c "^class\|export class" "$file" 2>/dev/null || echo "0")
    local import_count=$(grep -c "import\|require(" "$file" 2>/dev/null || echo "0")
    
    FILE_METRICS["${filename}_functions"]="$function_count"
    FILE_METRICS["${filename}_classes"]="$class_count"
    FILE_METRICS["${filename}_imports"]="$import_count"
    
    local quality_score=$(( (function_count > 0 ? 50 : 0) + (class_count > 0 ? 30 : 0) + (import_count > 0 ? 20 : 0) ))
    QUALITY_SCORES["$filename"]="$quality_score"
    
    log "DEBUG" "JavaScript analysis: $filename (functions: $function_count, classes: $class_count)"
}

# Analyze JSON files
analyze_json_file() {
    local file="$1"
    local filename="$2"
    
    # Validate JSON
    local is_valid=0
    if command -v jq >/dev/null 2>&1; then
        if jq empty "$file" 2>/dev/null; then
            is_valid=1
        fi
    else
        # Basic JSON validation
        if python3 -c "import json; json.load(open('$file'))" 2>/dev/null; then
            is_valid=1
        fi
    fi
    
    FILE_METRICS["${filename}_valid_json"]="$is_valid"
    QUALITY_SCORES["$filename"]="$((is_valid * 100))"
    
    log "DEBUG" "JSON analysis: $filename (valid: $is_valid)"
}

# Analyze Markdown files
analyze_markdown_file() {
    local file="$1"
    local filename="$2"
    
    # Count headers and links
    local header_count=$(grep -c "^#" "$file" 2>/dev/null || echo "0")
    local link_count=$(grep -o "\[.*\](.*)" "$file" 2>/dev/null | wc -l || echo "0")
    local code_block_count=$(grep -c "```" "$file" 2>/dev/null || echo "0")
    
    FILE_METRICS["${filename}_headers"]="$header_count"
    FILE_METRICS["${filename}_links"]="$link_count"
    FILE_METRICS["${filename}_code_blocks"]="$code_block_count"
    
    local quality_score=$(( (header_count > 0 ? 40 : 0) + (link_count > 0 ? 30 : 0) + (code_block_count > 0 ? 30 : 0) ))
    QUALITY_SCORES["$filename"]="$quality_score"
    
    log "DEBUG" "Markdown analysis: $filename (headers: $header_count, links: $link_count)"
}

# === REPORTING FUNCTIONS ===

# Generate comprehensive report
generate_reports() {
    log "INFO" "Generating analysis reports"
    
    generate_json_report
    generate_html_report
    generate_csv_metrics
    
    log "PASS" "All reports generated successfully"
}

# Generate JSON report
generate_json_report() {
    log "DEBUG" "Generating JSON report"
    
    cat > "$JSON_REPORT" << EOF
{
    "analysis_id": "$ANALYSIS_ID",
    "timestamp": "$(date -Iseconds)",
    "version": "$SCRIPT_VERSION",
    "target_directory": "$TARGET_DIR",
    "project_stats": {
$(for key in "${!PROJECT_STATS[@]}"; do
    echo "        \"$key\": \"${PROJECT_STATS[$key]}\","
done | sed '$ s/,$//')
    },
    "file_metrics": {
$(for key in "${!FILE_METRICS[@]}"; do
    echo "        \"$key\": \"${FILE_METRICS[$key]}\","
done | sed '$ s/,$//')
    },
    "quality_scores": {
$(for key in "${!QUALITY_SCORES[@]}"; do
    echo "        \"$key\": ${QUALITY_SCORES[$key]},"
done | sed '$ s/,$//')
    }
}
EOF
    
    log "DEBUG" "JSON report saved: $JSON_REPORT"
}

# Generate HTML report
generate_html_report() {
    log "DEBUG" "Generating HTML report"
    
    # Calculate average quality score
    local total_quality=0
    local quality_count=0
    for score in "${QUALITY_SCORES[@]}"; do
        total_quality=$((total_quality + score))
        ((quality_count++))
    done
    local avg_quality=$((quality_count > 0 ? total_quality / quality_count : 0))
    
    cat > "$HTML_REPORT" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cursor IDE Project Analysis Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; padding-bottom: 20px; border-bottom: 2px solid #e0e0e0; }
        .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 20px 0; }
        .stat-card { background: #f8f9fa; padding: 20px; border-radius: 8px; text-align: center; }
        .stat-value { font-size: 2em; font-weight: bold; color: #007acc; }
        .stat-label { color: #666; margin-top: 5px; }
        .section { margin: 30px 0; }
        .section h2 { color: #333; border-bottom: 2px solid #007acc; padding-bottom: 10px; }
        .quality-bar { width: 100%; height: 20px; background: #e0e0e0; border-radius: 10px; overflow: hidden; }
        .quality-fill { height: 100%; background: linear-gradient(90deg, #ff4444, #ffaa00, #44ff44); border-radius: 10px; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background-color: #f2f2f2; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Project Analysis Report</h1>
            <p>Generated on $(date '+%Y-%m-%d %H:%M:%S')</p>
            <p>Target: $TARGET_DIR</p>
        </div>
        
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-value">${PROJECT_STATS[analyzed_files]:-0}</div>
                <div class="stat-label">Files Analyzed</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">${PROJECT_STATS[total_lines]:-0}</div>
                <div class="stat-label">Total Lines</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$(( ${PROJECT_STATS[total_size]:-0} / 1024 ))KB</div>
                <div class="stat-label">Total Size</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">$avg_quality%</div>
                <div class="stat-label">Avg Quality</div>
            </div>
        </div>
        
        <div class="section">
            <h2>Overall Quality Score</h2>
            <div class="quality-bar">
                <div class="quality-fill" style="width: ${avg_quality}%;"></div>
            </div>
            <p>${avg_quality}% - $(
                if [[ $avg_quality -ge 80 ]]; then echo "Excellent"
                elif [[ $avg_quality -ge 60 ]]; then echo "Good"
                elif [[ $avg_quality -ge 40 ]]; then echo "Fair"
                else echo "Needs Improvement"
                fi
            )</p>
        </div>
        
        <div class="section">
            <h2>File Quality Scores</h2>
            <table>
                <tr><th>File</th><th>Quality Score</th><th>Assessment</th></tr>
$(for file in "${!QUALITY_SCORES[@]}"; do
    local score=${QUALITY_SCORES[$file]}
    local assessment
    if [[ $score -ge 80 ]]; then assessment="Excellent"
    elif [[ $score -ge 60 ]]; then assessment="Good"
    elif [[ $score -ge 40 ]]; then assessment="Fair"
    else assessment="Needs Improvement"
    fi
    echo "                <tr><td>$file</td><td>${score}%</td><td>$assessment</td></tr>"
done)
            </table>
        </div>
        
        <div class="section">
            <h2>Analysis Summary</h2>
            <ul>
                <li>Analysis completed on $(date)</li>
                <li>Target directory: $TARGET_DIR</li>
                <li>Files analyzed: ${PROJECT_STATS[analyzed_files]:-0}</li>
                <li>Average file size: ${PROJECT_STATS[avg_file_size]:-0} bytes</li>
            </ul>
        </div>
    </div>
</body>
</html>
EOF
    
    log "DEBUG" "HTML report saved: $HTML_REPORT"
}

# Generate CSV metrics
generate_csv_metrics() {
    log "DEBUG" "Generating CSV metrics"
    
    {
        echo "Filename,Extension,Size,Lines,Quality_Score"
        for file in "${!QUALITY_SCORES[@]}"; do
            local size="${FILE_METRICS[${file}_size]:-0}"
            local lines="${FILE_METRICS[${file}_lines]:-0}"
            local ext="${FILE_METRICS[${file}_extension]:-unknown}"
            local quality="${QUALITY_SCORES[$file]:-0}"
            echo "$file,$ext,$size,$lines,$quality"
        done
    } > "$METRICS_CSV"
    
    log "DEBUG" "CSV metrics saved: $METRICS_CSV"
}

# === MAIN EXECUTION ===

# Show usage
show_usage() {
    cat << EOF
Cursor IDE Professional Project Tracker v$SCRIPT_VERSION

USAGE:
    $SCRIPT_NAME [TARGET_DIR] [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -v, --verbose       Enable verbose output
    -n, --dry-run       Perform dry run
    -t, --include-tests Include test files in analysis
    --version           Show version information

EXAMPLES:
    $SCRIPT_NAME                    # Analyze current directory
    $SCRIPT_NAME /path/to/project   # Analyze specific directory
    $SCRIPT_NAME --verbose          # Verbose analysis
    $SCRIPT_NAME --include-tests    # Include test files

EOF
}

# Parse arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            --version)
                echo "Cursor IDE Professional Project Tracker v$SCRIPT_VERSION"
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                ;;
            -n|--dry-run)
                DRY_RUN=true
                ;;
            -t|--include-tests)
                INCLUDE_TESTS=true
                ;;
            *)
                if [[ -d "$1" ]]; then
                    TARGET_DIR="$1"
                else
                    log "ERROR" "Unknown option or invalid directory: $1"
                    exit 1
                fi
                ;;
        esac
        shift
    done
}

# Main function
main() {
    parse_arguments "$@"
    
    log "INFO" "Starting Cursor IDE Project Tracker v$SCRIPT_VERSION"
    log "INFO" "Target directory: $TARGET_DIR"
    
    # Initialize
    if ! initialize_directories; then
        log "ERROR" "Failed to initialize directories"
        exit 1
    fi
    
    # Validate and analyze
    if ! validate_target; then
        exit 1
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would analyze ${PROJECT_STATS[file_count]} files"
        exit 0
    fi
    
    if ! analyze_files; then
        log "ERROR" "File analysis failed"
        exit 1
    fi
    
    # Generate reports
    generate_reports
    
    # Show summary
    echo
    echo "Analysis Complete!"
    echo "  Files analyzed: ${PROJECT_STATS[analyzed_files]:-0}"
    echo "  Total lines: ${PROJECT_STATS[total_lines]:-0}"
    echo "  Reports generated:"
    echo "    HTML: $HTML_REPORT"
    echo "    JSON: $JSON_REPORT"
    echo "    CSV:  $METRICS_CSV"
    echo
    
    log "PASS" "Project tracking completed successfully"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi