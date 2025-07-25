#!/usr/bin/env bash

# =============================================================================
# CURSOR IDE ENTERPRISE CODE ANALYSIS AND TRACKING FRAMEWORK
# Version: tracker-system-v2
# Description: Advanced code analysis, dependency tracking, and quality assurance system
# Author: Enterprise Development Team
# License: MIT
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

# =============================================================================
# GLOBAL CONFIGURATION AND CONSTANTS
# =============================================================================

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_VERSION="tracker-system-v2"
readonly CURSOR_VERSION="6.9.35"
readonly TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"

# Directory structure
readonly BASE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/cursor-tracker"
readonly LOG_DIR="$BASE_DIR/logs"
readonly CONFIG_DIR="$BASE_DIR/config"
readonly CACHE_DIR="$BASE_DIR/cache"
readonly REPORTS_DIR="$BASE_DIR/reports"
readonly ANALYSIS_DIR="$BASE_DIR/analysis"
readonly METRICS_DIR="$BASE_DIR/metrics"

# Analysis configuration
readonly TARGET_DIR="${1:-$SCRIPT_DIR}"
readonly ANALYSIS_TIMESTAMP="$(date '+%Y-%m-%d_%H-%M-%S')"

# Log files
readonly MAIN_LOG="$LOG_DIR/tracker-${TIMESTAMP}.log"
readonly ERROR_LOG="$LOG_DIR/tracker-error-${TIMESTAMP}.log"
readonly AUDIT_LOG="$LOG_DIR/tracker-audit-${TIMESTAMP}.log"
readonly ANALYSIS_LOG="$LOG_DIR/analysis-${TIMESTAMP}.log"

# Report files
readonly HTML_REPORT="$REPORTS_DIR/analysis-report-${TIMESTAMP}.html"
readonly JSON_REPORT="$REPORTS_DIR/analysis-report-${TIMESTAMP}.json"
readonly CSV_REPORT="$REPORTS_DIR/metrics-${TIMESTAMP}.csv"
readonly DEPENDENCY_GRAPH="$REPORTS_DIR/dependency-graph-${TIMESTAMP}.dot"

# Colors and formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly NC='\033[0m'
readonly BOLD='\033[1m'
readonly DIM='\033[2m'

# Status codes
readonly STATUS_SUCCESS=0
readonly STATUS_WARNING=1
readonly STATUS_ERROR=2
readonly STATUS_CRITICAL=3

# Analysis types
declare -A ANALYSIS_TYPES=(
    ["functions"]="Function definition and usage analysis"
    ["dependencies"]="Dependency tracking and validation"
    ["complexity"]="Code complexity metrics"
    ["quality"]="Code quality assessment"
    ["security"]="Security vulnerability scanning"
    ["performance"]="Performance analysis"
    ["documentation"]="Documentation completeness"
    ["testing"]="Test coverage analysis"
)

# Code quality metrics
declare -A QUALITY_METRICS=(
    ["cyclomatic_complexity"]=0
    ["lines_of_code"]=0
    ["function_count"]=0
    ["duplicate_lines"]=0
    ["code_coverage"]=0
    ["security_issues"]=0
    ["documentation_coverage"]=0
    ["test_coverage"]=0
)

# Global data structures
declare -A FUNCTION_MAP=()
declare -A DEPENDENCY_MAP=()
declare -A FILE_METRICS=()
declare -A SECURITY_ISSUES=()
declare -A PERFORMANCE_ISSUES=()
declare -a ANALYSIS_RESULTS=()

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${CYAN}[INFO]${NC} $message" >&1
            echo "[$timestamp] [INFO] $message" >> "$MAIN_LOG" 2>/dev/null || true
            ;;
        "WARN")
            echo -e "${YELLOW}[WARN]${NC} $message" >&2
            echo "[$timestamp] [WARN] $message" >> "$MAIN_LOG" 2>/dev/null || true
            echo "[$timestamp] [WARN] $message" >> "$ERROR_LOG" 2>/dev/null || true
            ;;
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" >&2
            echo "[$timestamp] [ERROR] $message" >> "$MAIN_LOG" 2>/dev/null || true
            echo "[$timestamp] [ERROR] $message" >> "$ERROR_LOG" 2>/dev/null || true
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message" >&1
            echo "[$timestamp] [SUCCESS] $message" >> "$MAIN_LOG" 2>/dev/null || true
            ;;
        "DEBUG")
            if [[ "${DEBUG:-false}" == "true" ]]; then
                echo -e "${DIM}[DEBUG]${NC} $message" >&1
                echo "[$timestamp] [DEBUG] $message" >> "$MAIN_LOG" 2>/dev/null || true
            fi
            ;;
    esac
}

audit_log() {
    local action="$1"
    local details="$2"
    local status="${3:-SUCCESS}"
    local user="${USER:-unknown}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] USER=$user ACTION=$action STATUS=$status DETAILS=$details" >> "$AUDIT_LOG" 2>/dev/null || true
}

analysis_log() {
    local category="$1"
    local metric="$2"
    local value="$3"
    local details="${4:-}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] CATEGORY=$category METRIC=$metric VALUE=$value DETAILS=$details" >> "$ANALYSIS_LOG" 2>/dev/null || true
}

show_progress() {
    local current="$1"
    local total="$2"
    local description="$3"
    local percentage=$((current * 100 / total))
    local completed=$((percentage / 2))
    local remaining=$((50 - completed))
    
    printf "\r${BLUE}[%s%s]${NC} %d%% %s" \
        "$(printf "%*s" $completed | tr ' ' '=')" \
        "$(printf "%*s" $remaining)" \
        "$percentage" \
        "$description"
    
    if [[ $current -eq $total ]]; then
        echo
    fi
}

cleanup() {
    local exit_code=$?
    log "INFO" "Performing cleanup operations..."
    
    if [[ $exit_code -eq 0 ]]; then
        log "SUCCESS" "Code analysis completed successfully"
    else
        log "ERROR" "Code analysis failed with exit code: $exit_code"
    fi
    
    audit_log "CLEANUP" "Exit code: $exit_code" "COMPLETE"
    exit $exit_code
}

error_handler() {
    local line_number="$1"
    local command="$2"
    local exit_code="$3"
    
    log "ERROR" "Command failed at line $line_number: $command (exit code: $exit_code)"
    audit_log "ERROR" "Line: $line_number, Command: $command" "FAILURE"
    
    cleanup
}

# =============================================================================
# INITIALIZATION FUNCTIONS
# =============================================================================

create_directory_structure() {
    log "INFO" "Creating directory structure..."
    
    local directories=(
        "$BASE_DIR" "$LOG_DIR" "$CONFIG_DIR" "$CACHE_DIR"
        "$REPORTS_DIR" "$ANALYSIS_DIR" "$METRICS_DIR"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir" || {
            log "ERROR" "Failed to create directory: $dir"
            return 1
        }
    done
    
    log "SUCCESS" "Directory structure created successfully"
    return 0
}

initialize_configuration() {
    log "INFO" "Initializing configuration files..."
    
    # Main configuration file
    cat > "$CONFIG_DIR/tracker.conf" << 'EOF'
# Cursor IDE Code Tracker Configuration
# Version: tracker-system-v2

[analysis]
enable_function_analysis=true
enable_dependency_tracking=true
enable_complexity_analysis=true
enable_quality_metrics=true
enable_security_scanning=true
enable_performance_analysis=true

[thresholds]
max_cyclomatic_complexity=10
max_function_length=50
max_file_length=1000
min_documentation_coverage=80
min_test_coverage=70

[reporting]
generate_html_report=true
generate_json_report=true
generate_csv_metrics=true
generate_dependency_graph=true
include_source_code=false

[security]
scan_for_vulnerabilities=true
check_shell_injection=true
check_path_traversal=true
check_unsafe_commands=true
EOF

    # Analysis patterns configuration
    cat > "$CONFIG_DIR/patterns.json" << 'EOF'
{
    "function_patterns": {
        "bash": "^[[:space:]]*([a-zA-Z0-9_]+)[[:space:]]*\\(\\)[[:space:]]*\\{",
        "python": "^[[:space:]]*def[[:space:]]+([a-zA-Z0-9_]+)[[:space:]]*\\(",
        "javascript": "^[[:space:]]*function[[:space:]]+([a-zA-Z0-9_]+)[[:space:]]*\\("
    },
    "vulnerability_patterns": {
        "shell_injection": ["eval", "exec", "system", "\\$\\(", "`"],
        "path_traversal": ["\\.\\./*", "\\$\\{.*\\}"],
        "unsafe_commands": ["rm -rf", "chmod 777", "wget.*\\|", "curl.*\\|"]
    },
    "complexity_patterns": {
        "conditionals": ["if", "elif", "case", "while", "for", "until"],
        "loops": ["while", "for", "until", "do"],
        "functions": ["function", "\\(\\)", "def "]
    }
}
EOF

    log "SUCCESS" "Configuration files initialized"
    return 0
}

# =============================================================================
# FILE DISCOVERY AND ANALYSIS
# =============================================================================

discover_source_files() {
    log "INFO" "Discovering source files in: $TARGET_DIR"
    
    local file_count=0
    local file_types=()
    
    # Discover shell scripts
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]] && [[ "$file" != *"tracker"* ]] && [[ "$file" != *"test"* ]]; then
            SOURCE_FILES+=("$file")
            file_types+=("shell")
            ((file_count++))
        fi
    done < <(find "$TARGET_DIR" -maxdepth 2 -type f \( -name "*.sh" -o -name "*.bash" \) -print0)
    
    # Discover Python files
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            SOURCE_FILES+=("$file")
            file_types+=("python")
            ((file_count++))
        fi
    done < <(find "$TARGET_DIR" -maxdepth 2 -type f -name "*.py" -print0)
    
    # Discover JavaScript/TypeScript files
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            SOURCE_FILES+=("$file")
            file_types+=("javascript")
            ((file_count++))
        fi
    done < <(find "$TARGET_DIR" -maxdepth 2 -type f \( -name "*.js" -o -name "*.ts" \) -print0)
    
    log "SUCCESS" "Discovered $file_count source files"
    analysis_log "DISCOVERY" "source_files" "$file_count" "Types: ${file_types[*]}"
    
    return 0
}

analyze_file_metrics() {
    local file="$1"
    local file_name=$(basename "$file")
    
    log "DEBUG" "Analyzing file metrics: $file_name"
    
    # Basic file metrics
    local line_count=$(wc -l < "$file")
    local char_count=$(wc -c < "$file")
    local word_count=$(wc -w < "$file")
    
    # Comment analysis
    local comment_lines=$(grep -c '^[[:space:]]*#' "$file" 2>/dev/null || echo "0")
    local blank_lines=$(grep -c '^[[:space:]]*$' "$file" 2>/dev/null || echo "0")
    local code_lines=$((line_count - comment_lines - blank_lines))
    
    # Function count
    local function_count=$(grep -c '^[[:space:]]*[a-zA-Z0-9_]*[[:space:]]*()' "$file" 2>/dev/null || echo "0")
    
    # Store metrics
    FILE_METRICS["$file_name"]="lines:$line_count,chars:$char_count,words:$word_count,comments:$comment_lines,code:$code_lines,functions:$function_count"
    
    # Update global metrics
    QUALITY_METRICS["lines_of_code"]=$((QUALITY_METRICS["lines_of_code"] + code_lines))
    QUALITY_METRICS["function_count"]=$((QUALITY_METRICS["function_count"] + function_count))
    
    analysis_log "FILE_METRICS" "$file_name" "$line_count" "Code: $code_lines, Comments: $comment_lines, Functions: $function_count"
}

# =============================================================================
# FUNCTION ANALYSIS
# =============================================================================

analyze_functions() {
    log "INFO" "Analyzing function definitions and usage..."
    
    local total_functions=0
    local analyzed_files=0
    
    # Clear function map
    FUNCTION_MAP=()
    
    for file in "${SOURCE_FILES[@]}"; do
        local file_name=$(basename "$file")
        log "DEBUG" "Scanning functions in: $file_name"
        
        local file_functions=0
        
        # Extract function definitions
        while IFS= read -r line; do
            # Bash function pattern
            if [[ $line =~ ^[[:space:]]*([a-zA-Z0-9_]+)[[:space:]]*\(\)[[:space:]]*\{ ]]; then
                local func_name="${BASH_REMATCH[1]}"
                FUNCTION_MAP["$func_name"]+="$file_name "
                ((file_functions++))
                ((total_functions++))
                
                # Analyze function complexity
                analyze_function_complexity "$file" "$func_name"
            fi
            
            # Python function pattern
            if [[ $line =~ ^[[:space:]]*def[[:space:]]+([a-zA-Z0-9_]+)[[:space:]]*\( ]]; then
                local func_name="${BASH_REMATCH[1]}"
                FUNCTION_MAP["$func_name"]+="$file_name "
                ((file_functions++))
                ((total_functions++))
            fi
            
            # JavaScript function pattern
            if [[ $line =~ ^[[:space:]]*function[[:space:]]+([a-zA-Z0-9_]+)[[:space:]]*\( ]]; then
                local func_name="${BASH_REMATCH[1]}"
                FUNCTION_MAP["$func_name"]+="$file_name "
                ((file_functions++))
                ((total_functions++))
            fi
        done < "$file"
        
        ((analyzed_files++))
        show_progress "$analyzed_files" "${#SOURCE_FILES[@]}" "Analyzing functions"
        
        analysis_log "FUNCTION_ANALYSIS" "$file_name" "$file_functions" "Functions discovered"
    done
    
    log "SUCCESS" "Function analysis completed: $total_functions functions in $analyzed_files files"
    analysis_log "FUNCTION_SUMMARY" "total_functions" "$total_functions" "Files: $analyzed_files"
    
    return 0
}

analyze_function_complexity() {
    local file="$1"
    local function_name="$2"
    
    # Extract function body (simplified approach)
    local in_function=false
    local brace_count=0
    local complexity=1  # Base complexity
    local line_count=0
    
    while IFS= read -r line; do
        if [[ $line =~ $function_name.*\(\).*\{ ]]; then
            in_function=true
            brace_count=1
            continue
        fi
        
        if $in_function; then
            ((line_count++))
            
            # Count braces to track function scope
            local open_braces=$(echo "$line" | tr -cd '{' | wc -c)
            local close_braces=$(echo "$line" | tr -cd '}' | wc -c)
            brace_count=$((brace_count + open_braces - close_braces))
            
            # Count complexity contributors
            if [[ $line =~ (if|elif|while|for|until|case|\|\||&&) ]]; then
                ((complexity++))
            fi
            
            # End of function
            if [[ $brace_count -eq 0 ]]; then
                break
            fi
        fi
    done < "$file"
    
    # Store complexity metrics
    if [[ $complexity -gt 10 ]]; then
        ANALYSIS_RESULTS+=("HIGH_COMPLEXITY:$function_name:$complexity:$file")
    fi
    
    QUALITY_METRICS["cyclomatic_complexity"]=$((QUALITY_METRICS["cyclomatic_complexity"] + complexity))
    
    analysis_log "COMPLEXITY" "$function_name" "$complexity" "Lines: $line_count, File: $(basename "$file")"
}

analyze_function_usage() {
    log "INFO" "Analyzing function usage patterns..."
    
    local unused_functions=()
    local overused_functions=()
    local total_usage=0
    
    for func_name in "${!FUNCTION_MAP[@]}"; do
        local usage_count=0
        local definition_files="${FUNCTION_MAP[$func_name]}"
        
        # Count usage across all files
        for file in "${SOURCE_FILES[@]}"; do
            local file_usage=$(grep -c "[^a-zA-Z0-9_]$func_name[^a-zA-Z0-9_]" "$file" 2>/dev/null || echo "0")
            usage_count=$((usage_count + file_usage))
        done
        
        # Subtract definition occurrences (functions defining themselves)
        local def_count=$(echo "$definition_files" | wc -w)
        usage_count=$((usage_count - def_count))
        
        if [[ $usage_count -eq 0 ]]; then
            unused_functions+=("$func_name")
        elif [[ $usage_count -gt 20 ]]; then
            overused_functions+=("$func_name:$usage_count")
        fi
        
        total_usage=$((total_usage + usage_count))
        
        analysis_log "FUNCTION_USAGE" "$func_name" "$usage_count" "Definitions: $def_count"
    done
    
    # Report unused functions
    if [[ ${#unused_functions[@]} -gt 0 ]]; then
        log "WARN" "Found ${#unused_functions[@]} unused functions"
        for func in "${unused_functions[@]}"; do
            log "DEBUG" "Unused function: $func (defined in ${FUNCTION_MAP[$func]})"
            ANALYSIS_RESULTS+=("UNUSED_FUNCTION:$func:${FUNCTION_MAP[$func]}")
        done
    else
        log "SUCCESS" "All functions are used"
    fi
    
    # Report overused functions (potential optimization candidates)
    if [[ ${#overused_functions[@]} -gt 0 ]]; then
        log "INFO" "Found ${#overused_functions[@]} heavily used functions"
        for func_info in "${overused_functions[@]}"; do
            local func_name="${func_info%:*}"
            local usage_count="${func_info#*:}"
            log "DEBUG" "Heavily used function: $func_name ($usage_count uses)"
            ANALYSIS_RESULTS+=("HEAVY_USAGE:$func_name:$usage_count")
        done
    fi
    
    analysis_log "USAGE_SUMMARY" "total_usage" "$total_usage" "Unused: ${#unused_functions[@]}, Heavy: ${#overused_functions[@]}"
    
    return 0
}

# =============================================================================
# DEPENDENCY ANALYSIS
# =============================================================================

analyze_dependencies() {
    log "INFO" "Analyzing dependencies and imports..."
    
    local total_dependencies=0
    local external_deps=0
    local internal_deps=0
    
    DEPENDENCY_MAP=()
    
    for file in "${SOURCE_FILES[@]}"; do
        local file_name=$(basename "$file")
        local file_deps=()
        
        # Analyze shell script dependencies
        if [[ "$file" == *.sh ]] || [[ "$file" == *.bash ]]; then
            # Source/include dependencies
            while IFS= read -r line; do
                if [[ $line =~ source[[:space:]]+([^[:space:]]+) ]] || [[ $line =~ \.[[:space:]]+([^[:space:]]+) ]]; then
                    local dep="${BASH_REMATCH[1]}"
                    file_deps+=("$dep")
                    ((total_dependencies++))
                    
                    if [[ "$dep" == *"/"* ]] || [[ "$dep" == *".sh" ]]; then
                        ((internal_deps++))
                    else
                        ((external_deps++))
                    fi
                fi
            done < "$file"
            
            # Command dependencies
            local commands=($(grep -o '\<[a-zA-Z][a-zA-Z0-9_-]*\>' "$file" | grep -E '^(curl|wget|git|docker|python|node|npm|pip)$' | sort -u))
            for cmd in "${commands[@]}"; do
                file_deps+=("cmd:$cmd")
                ((external_deps++))
                ((total_dependencies++))
            done
        fi
        
        # Analyze Python dependencies
        if [[ "$file" == *.py ]]; then
            while IFS= read -r line; do
                if [[ $line =~ ^[[:space:]]*import[[:space:]]+([a-zA-Z0-9_.,[:space:]]+) ]] || [[ $line =~ ^[[:space:]]*from[[:space:]]+([a-zA-Z0-9_.]+)[[:space:]]+import ]]; then
                    local dep="${BASH_REMATCH[1]}"
                    file_deps+=("py:$dep")
                    ((total_dependencies++))
                    ((external_deps++))
                fi
            done < "$file"
        fi
        
        # Store dependencies
        if [[ ${#file_deps[@]} -gt 0 ]]; then
            DEPENDENCY_MAP["$file_name"]="${file_deps[*]}"
        fi
        
        analysis_log "DEPENDENCIES" "$file_name" "${#file_deps[@]}" "Dependencies: ${file_deps[*]}"
    done
    
    log "SUCCESS" "Dependency analysis completed: $total_dependencies dependencies ($internal_deps internal, $external_deps external)"
    analysis_log "DEPENDENCY_SUMMARY" "total" "$total_dependencies" "Internal: $internal_deps, External: $external_deps"
    
    return 0
}

validate_dependencies() {
    log "INFO" "Validating dependency availability..."
    
    local missing_deps=()
    local available_deps=0
    
    for file_name in "${!DEPENDENCY_MAP[@]}"; do
        local deps=(${DEPENDENCY_MAP[$file_name]})
        
        for dep in "${deps[@]}"; do
            local dep_available=true
            
            # Check command dependencies
            if [[ "$dep" == cmd:* ]]; then
                local cmd="${dep#cmd:}"
                if ! command -v "$cmd" >/dev/null 2>&1; then
                    missing_deps+=("$cmd (required by $file_name)")
                    dep_available=false
                fi
            fi
            
            # Check file dependencies
            if [[ "$dep" == *.sh ]] || [[ "$dep" == *"/"* ]]; then
                local dep_path="$TARGET_DIR/$dep"
                if [[ ! -f "$dep_path" ]] && [[ ! -f "$dep" ]]; then
                    missing_deps+=("$dep (required by $file_name)")
                    dep_available=false
                fi
            fi
            
            if $dep_available; then
                ((available_deps++))
            fi
        done
    done
    
    if [[ ${#missing_deps[@]} -eq 0 ]]; then
        log "SUCCESS" "All dependencies are available"
    else
        log "WARN" "Found ${#missing_deps[@]} missing dependencies"
        for dep in "${missing_deps[@]}"; do
            log "DEBUG" "Missing dependency: $dep"
            ANALYSIS_RESULTS+=("MISSING_DEPENDENCY:$dep")
        done
    fi
    
    analysis_log "DEPENDENCY_VALIDATION" "available" "$available_deps" "Missing: ${#missing_deps[@]}"
    
    return 0
}

# =============================================================================
# SECURITY ANALYSIS
# =============================================================================

analyze_security_vulnerabilities() {
    log "INFO" "Scanning for security vulnerabilities..."
    
    local total_issues=0
    local critical_issues=0
    local warning_issues=0
    
    SECURITY_ISSUES=()
    
    for file in "${SOURCE_FILES[@]}"; do
        local file_name=$(basename "$file")
        local file_issues=0
        
        # Check for shell injection vulnerabilities
        local shell_injection_patterns=('eval[[:space:]]*[^#]*\$' 'exec[[:space:]]*[^#]*\$' 'system[[:space:]]*[^#]*\$' '\$\(' '`[^`]*`')
        for pattern in "${shell_injection_patterns[@]}"; do
            while IFS= read -r line_num line_content; do
                if [[ -n "$line_content" ]]; then
                    SECURITY_ISSUES["$file_name:$line_num"]="SHELL_INJECTION:$pattern:$line_content"
                    ((file_issues++))
                    ((critical_issues++))
                fi
            done < <(grep -n "$pattern" "$file" 2>/dev/null || true)
        done
        
        # Check for path traversal vulnerabilities
        local path_traversal_patterns=('\.\./.*\$' '\$\{[^}]*\}.*/' 'rm[[:space:]]*-rf[[:space:]]*\$')
        for pattern in "${path_traversal_patterns[@]}"; do
            while IFS= read -r line_num line_content; do
                if [[ -n "$line_content" ]]; then
                    SECURITY_ISSUES["$file_name:$line_num"]="PATH_TRAVERSAL:$pattern:$line_content"
                    ((file_issues++))
                    ((critical_issues++))
                fi
            done < <(grep -n "$pattern" "$file" 2>/dev/null || true)
        done
        
        # Check for unsafe command usage
        local unsafe_commands=('chmod[[:space:]]*777' 'wget.*|' 'curl.*|' 'sudo[[:space:]]*rm' 'dd[[:space:]].*of=')
        for pattern in "${unsafe_commands[@]}"; do
            while IFS= read -r line_num line_content; do
                if [[ -n "$line_content" ]]; then
                    SECURITY_ISSUES["$file_name:$line_num"]="UNSAFE_COMMAND:$pattern:$line_content"
                    ((file_issues++))
                    ((warning_issues++))
                fi
            done < <(grep -n "$pattern" "$file" 2>/dev/null || true)
        done
        
        # Check for hardcoded credentials
        local credential_patterns=('password[[:space:]]*=' 'token[[:space:]]*=' 'secret[[:space:]]*=' 'api_key[[:space:]]*=')
        for pattern in "${credential_patterns[@]}"; do
            while IFS= read -r line_num line_content; do
                if [[ -n "$line_content" ]] && [[ ! "$line_content" =~ ^[[:space:]]*# ]]; then
                    SECURITY_ISSUES["$file_name:$line_num"]="HARDCODED_CREDENTIAL:$pattern:$line_content"
                    ((file_issues++))
                    ((critical_issues++))
                fi
            done < <(grep -ni "$pattern" "$file" 2>/dev/null || true)
        done
        
        total_issues=$((total_issues + file_issues))
        
        if [[ $file_issues -gt 0 ]]; then
            analysis_log "SECURITY_SCAN" "$file_name" "$file_issues" "Potential security issues found"
        fi
    done
    
    QUALITY_METRICS["security_issues"]=$total_issues
    
    if [[ $total_issues -eq 0 ]]; then
        log "SUCCESS" "No security vulnerabilities detected"
    else
        log "WARN" "Found $total_issues potential security issues ($critical_issues critical, $warning_issues warnings)"
        for issue_key in "${!SECURITY_ISSUES[@]}"; do
            local issue_info="${SECURITY_ISSUES[$issue_key]}"
            log "DEBUG" "Security issue: $issue_key - $issue_info"
            ANALYSIS_RESULTS+=("SECURITY_ISSUE:$issue_key:$issue_info")
        done
    fi
    
    analysis_log "SECURITY_SUMMARY" "total_issues" "$total_issues" "Critical: $critical_issues, Warnings: $warning_issues"
    
    return 0
}

# =============================================================================
# QUALITY ANALYSIS
# =============================================================================

analyze_code_quality() {
    log "INFO" "Analyzing code quality metrics..."
    
    local total_files=${#SOURCE_FILES[@]}
    local analyzed_files=0
    
    for file in "${SOURCE_FILES[@]}"; do
        local file_name=$(basename "$file")
        
        # Analyze file-specific quality metrics
        analyze_file_metrics "$file"
        
        # Check for code smells
        check_code_smells "$file"
        
        # Check documentation coverage
        check_documentation_coverage "$file"
        
        ((analyzed_files++))
        show_progress "$analyzed_files" "$total_files" "Analyzing code quality"
    done
    
    # Calculate overall quality score
    calculate_quality_score
    
    log "SUCCESS" "Code quality analysis completed for $analyzed_files files"
    
    return 0
}

check_code_smells() {
    local file="$1"
    local file_name=$(basename "$file")
    
    local smells_found=0
    
    # Long function detection
    local in_function=false
    local function_name=""
    local function_lines=0
    local brace_count=0
    
    while IFS= read -r line_num line; do
        if [[ $line =~ ^[[:space:]]*([a-zA-Z0-9_]+)[[:space:]]*\(\)[[:space:]]*\{ ]]; then
            in_function=true
            function_name="${BASH_REMATCH[1]}"
            function_lines=1
            brace_count=1
        elif $in_function; then
            ((function_lines++))
            
            local open_braces=$(echo "$line" | tr -cd '{' | wc -c)
            local close_braces=$(echo "$line" | tr -cd '}' | wc -c)
            brace_count=$((brace_count + open_braces - close_braces))
            
            if [[ $brace_count -eq 0 ]]; then
                if [[ $function_lines -gt 50 ]]; then
                    ANALYSIS_RESULTS+=("LONG_FUNCTION:$function_name:$function_lines:$file_name")
                    ((smells_found++))
                fi
                in_function=false
                function_name=""
                function_lines=0
            fi
        fi
        
        # Long line detection
        if [[ ${#line} -gt 120 ]]; then
            ANALYSIS_RESULTS+=("LONG_LINE:$line_num:${#line}:$file_name")
            ((smells_found++))
        fi
        
        # TODO/FIXME detection
        if [[ $line =~ (TODO|FIXME|HACK|XXX) ]]; then
            ANALYSIS_RESULTS+=("TODO_COMMENT:$line_num:$line:$file_name")
        fi
        
    done < <(nl -ba "$file")
    
    analysis_log "CODE_SMELLS" "$file_name" "$smells_found" "Code smells detected"
}

check_documentation_coverage() {
    local file="$1"
    local file_name=$(basename "$file")
    
    local total_functions=0
    local documented_functions=0
    
    # Simple documentation check - look for comments before function definitions
    while IFS= read -r line_num line; do
        if [[ $line =~ ^[[:space:]]*([a-zA-Z0-9_]+)[[:space:]]*\(\)[[:space:]]*\{ ]]; then
            ((total_functions++))
            
            # Check previous lines for documentation
            local prev_line_num=$((line_num - 1))
            if [[ $prev_line_num -gt 0 ]]; then
                local prev_line=$(sed -n "${prev_line_num}p" "$file")
                if [[ $prev_line =~ ^[[:space:]]*# ]]; then
                    ((documented_functions++))
                fi
            fi
        fi
    done < <(nl -ba "$file")
    
    local doc_coverage=0
    if [[ $total_functions -gt 0 ]]; then
        doc_coverage=$((documented_functions * 100 / total_functions))
    fi
    
    QUALITY_METRICS["documentation_coverage"]=$((QUALITY_METRICS["documentation_coverage"] + doc_coverage))
    
    analysis_log "DOCUMENTATION" "$file_name" "$doc_coverage" "Functions: $documented_functions/$total_functions"
}

calculate_quality_score() {
    log "INFO" "Calculating overall quality score..."
    
    local total_files=${#SOURCE_FILES[@]}
    local avg_complexity=0
    local avg_doc_coverage=0
    
    if [[ $total_files -gt 0 ]]; then
        avg_complexity=$((QUALITY_METRICS["cyclomatic_complexity"] / QUALITY_METRICS["function_count"]))
        avg_doc_coverage=$((QUALITY_METRICS["documentation_coverage"] / total_files))
    fi
    
    # Quality score calculation (0-100)
    local quality_score=100
    
    # Reduce score for high complexity
    if [[ $avg_complexity -gt 10 ]]; then
        quality_score=$((quality_score - (avg_complexity - 10) * 5))
    fi
    
    # Reduce score for poor documentation
    if [[ $avg_doc_coverage -lt 80 ]]; then
        quality_score=$((quality_score - (80 - avg_doc_coverage)))
    fi
    
    # Reduce score for security issues
    quality_score=$((quality_score - QUALITY_METRICS["security_issues"] * 10))
    
    # Ensure score doesn't go below 0
    if [[ $quality_score -lt 0 ]]; then
        quality_score=0
    fi
    
    QUALITY_METRICS["quality_score"]=$quality_score
    
    local score_grade="F"
    if [[ $quality_score -ge 90 ]]; then
        score_grade="A"
    elif [[ $quality_score -ge 80 ]]; then
        score_grade="B"
    elif [[ $quality_score -ge 70 ]]; then
        score_grade="C"
    elif [[ $quality_score -ge 60 ]]; then
        score_grade="D"
    fi
    
    log "INFO" "Overall quality score: $quality_score/100 (Grade: $score_grade)"
    analysis_log "QUALITY_SCORE" "overall" "$quality_score" "Grade: $score_grade, Complexity: $avg_complexity, Documentation: $avg_doc_coverage%"
}

# =============================================================================
# REPORTING FUNCTIONS
# =============================================================================

generate_html_report() {
    log "INFO" "Generating HTML analysis report..."
    
    cat > "$HTML_REPORT" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Cursor IDE Code Analysis Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; margin-bottom: 30px; padding-bottom: 20px; border-bottom: 2px solid #e0e0e0; }
        .header h1 { color: #2c3e50; margin: 0; font-size: 2.5em; }
        .header p { color: #7f8c8d; margin: 10px 0 0 0; font-size: 1.1em; }
        .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .metric-card { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 8px; text-align: center; }
        .metric-card h3 { margin: 0 0 10px 0; font-size: 1.2em; }
        .metric-card .number { font-size: 2.5em; font-weight: bold; margin: 10px 0; }
        .section { margin-bottom: 30px; }
        .section h2 { color: #34495e; border-bottom: 1px solid #bdc3c7; padding-bottom: 10px; }
        .function-list { background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 10px 0; }
        .function-item { padding: 8px 0; border-bottom: 1px solid #dee2e6; }
        .function-item:last-child { border-bottom: none; }
        .issue-high { color: #e74c3c; font-weight: bold; }
        .issue-medium { color: #f39c12; font-weight: bold; }
        .issue-low { color: #f1c40f; }
        .footer { margin-top: 40px; text-align: center; color: #7f8c8d; font-size: 0.9em; }
        .quality-score { font-size: 3em; font-weight: bold; margin: 20px 0; }
        .grade-a { color: #27ae60; }
        .grade-b { color: #2ecc71; }
        .grade-c { color: #f39c12; }
        .grade-d { color: #e67e22; }
        .grade-f { color: #e74c3c; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Code Analysis Report</h1>
            <p>Generated on $(date '+%Y-%m-%d %H:%M:%S')</p>
            <p>Analysis Target: $TARGET_DIR</p>
        </div>
        
        <div class="section">
            <h2>Quality Score</h2>
            <div style="text-align: center;">
                <div class="quality-score grade-$(echo ${QUALITY_METRICS[quality_score]} | awk '{if($1>=90) print "a"; else if($1>=80) print "b"; else if($1>=70) print "c"; else if($1>=60) print "d"; else print "f"}')">${QUALITY_METRICS[quality_score]}/100</div>
                <p>Overall code quality assessment based on complexity, documentation, and security metrics.</p>
            </div>
        </div>
        
        <div class="metrics">
            <div class="metric-card">
                <h3>Lines of Code</h3>
                <div class="number">${QUALITY_METRICS[lines_of_code]}</div>
            </div>
            <div class="metric-card">
                <h3>Functions</h3>
                <div class="number">${QUALITY_METRICS[function_count]}</div>
            </div>
            <div class="metric-card">
                <h3>Security Issues</h3>
                <div class="number">${QUALITY_METRICS[security_issues]}</div>
            </div>
            <div class="metric-card">
                <h3>Files Analyzed</h3>
                <div class="number">${#SOURCE_FILES[@]}</div>
            </div>
        </div>
        
        <div class="section">
            <h2>Function Analysis</h2>
            <div class="function-list">
                <h3>Discovered Functions (${#FUNCTION_MAP[@]})</h3>
EOF

    # Add function details
    for func_name in "${!FUNCTION_MAP[@]}"; do
        local files="${FUNCTION_MAP[$func_name]}"
        cat >> "$HTML_REPORT" << EOF
                <div class="function-item">
                    <strong>$func_name</strong> - Defined in: $files
                </div>
EOF
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
        local result_type="${result%%:*}"
        local result_details="${result#*:}"
        local css_class="issue-low"
        
        case "$result_type" in
            "SECURITY_ISSUE"|"HIGH_COMPLEXITY")
                css_class="issue-high"
                ;;
            "UNUSED_FUNCTION"|"LONG_FUNCTION")
                css_class="issue-medium"
                ;;
        esac
        
        cat >> "$HTML_REPORT" << EOF
                <div class="function-item">
                    <span class="$css_class">[$result_type]</span> $result_details
                </div>
EOF
    done

    cat >> "$HTML_REPORT" << EOF
            </div>
        </div>
        
        <div class="footer">
            <p>Generated by Cursor IDE Enterprise Code Analysis Framework v$SCRIPT_VERSION</p>
        </div>
    </div>
</body>
</html>
EOF
    
    log "SUCCESS" "HTML report generated: $HTML_REPORT"
}

generate_json_report() {
    log "INFO" "Generating JSON analysis report..."
    
    local timestamp=$(date -Iseconds)
    
    cat > "$JSON_REPORT" << EOF
{
    "analysis_report": {
        "version": "$SCRIPT_VERSION",
        "timestamp": "$timestamp",
        "target_directory": "$TARGET_DIR",
        "analysis_duration": "$(date +%s)",
        "quality_metrics": {
EOF

    # Add quality metrics
    local first_metric=true
    for metric in "${!QUALITY_METRICS[@]}"; do
        if [[ "$first_metric" != "true" ]]; then
            echo "," >> "$JSON_REPORT"
        fi
        first_metric=false
        echo "            \"$metric\": ${QUALITY_METRICS[$metric]}" >> "$JSON_REPORT"
    done

    cat >> "$JSON_REPORT" << EOF
        },
        "functions": {
EOF

    # Add function map
    local first_function=true
    for func_name in "${!FUNCTION_MAP[@]}"; do
        if [[ "$first_function" != "true" ]]; then
            echo "," >> "$JSON_REPORT"
        fi
        first_function=false
        local files="${FUNCTION_MAP[$func_name]}"
        echo "            \"$func_name\": \"$files\"" >> "$JSON_REPORT"
    done

    cat >> "$JSON_REPORT" << EOF
        },
        "dependencies": {
EOF

    # Add dependency map
    local first_dep=true
    for file_name in "${!DEPENDENCY_MAP[@]}"; do
        if [[ "$first_dep" != "true" ]]; then
            echo "," >> "$JSON_REPORT"
        fi
        first_dep=false
        local deps="${DEPENDENCY_MAP[$file_name]}"
        echo "            \"$file_name\": \"$deps\"" >> "$JSON_REPORT"
    done

    cat >> "$JSON_REPORT" << EOF
        },
        "analysis_results": [
EOF

    # Add analysis results
    local first_result=true
    for result in "${ANALYSIS_RESULTS[@]}"; do
        if [[ "$first_result" != "true" ]]; then
            echo "," >> "$JSON_REPORT"
        fi
        first_result=false
        echo "            \"$result\"" >> "$JSON_REPORT"
    done

    cat >> "$JSON_REPORT" << EOF
        ],
        "file_metrics": {
EOF

    # Add file metrics
    local first_file=true
    for file_name in "${!FILE_METRICS[@]}"; do
        if [[ "$first_file" != "true" ]]; then
            echo "," >> "$JSON_REPORT"
        fi
        first_file=false
        local metrics="${FILE_METRICS[$file_name]}"
        echo "            \"$file_name\": \"$metrics\"" >> "$JSON_REPORT"
    done

    cat >> "$JSON_REPORT" << EOF
        }
    }
}
EOF
    
    log "SUCCESS" "JSON report generated: $JSON_REPORT"
}

generate_csv_metrics() {
    log "INFO" "Generating CSV metrics report..."
    
    # Create CSV header
    cat > "$CSV_REPORT" << EOF
Metric,Value,Description
EOF
    
    # Add quality metrics
    for metric in "${!QUALITY_METRICS[@]}"; do
        local description=""
        case "$metric" in
            "lines_of_code") description="Total lines of executable code" ;;
            "function_count") description="Total number of functions" ;;
            "cyclomatic_complexity") description="Sum of cyclomatic complexity" ;;
            "security_issues") description="Number of potential security issues" ;;
            "quality_score") description="Overall quality score (0-100)" ;;
            *) description="$metric metric" ;;
        esac
        echo "$metric,${QUALITY_METRICS[$metric]},$description" >> "$CSV_REPORT"
    done
    
    # Add summary metrics
    echo "total_files,${#SOURCE_FILES[@]},Number of source files analyzed" >> "$CSV_REPORT"
    echo "total_functions,${#FUNCTION_MAP[@]},Number of unique functions discovered" >> "$CSV_REPORT"
    echo "total_dependencies,${#DEPENDENCY_MAP[@]},Number of files with dependencies" >> "$CSV_REPORT"
    echo "analysis_results,${#ANALYSIS_RESULTS[@]},Number of analysis findings" >> "$CSV_REPORT"
    
    log "SUCCESS" "CSV metrics generated: $CSV_REPORT"
}

# =============================================================================
# MAIN EXECUTION FUNCTIONS
# =============================================================================

show_usage() {
    cat << EOF
Cursor IDE Enterprise Code Analysis and Tracking Framework v$SCRIPT_VERSION

USAGE:
    $SCRIPT_NAME [TARGET_DIRECTORY] [OPTIONS]

OPTIONS:
    -h, --help              Show this help message
    -v, --version           Show version information
    -a, --analysis TYPE     Analysis type: functions, dependencies, complexity, quality, security, all
    -r, --report FORMAT     Report format: html, json, csv, all (default: all)
    -o, --output DIR        Output directory for reports
    -q, --quiet             Quiet mode (minimal output)
    -d, --debug             Enable debug logging
    --no-security           Skip security analysis
    --no-complexity         Skip complexity analysis

ANALYSIS TYPES:
$(for type in "${!ANALYSIS_TYPES[@]}"; do
    printf "    %-15s %s\n" "$type" "${ANALYSIS_TYPES[$type]}"
done)

EXAMPLES:
    $SCRIPT_NAME                           # Analyze current directory
    $SCRIPT_NAME /path/to/code             # Analyze specific directory
    $SCRIPT_NAME --analysis security       # Security analysis only
    $SCRIPT_NAME --report html             # Generate HTML report only
    $SCRIPT_NAME --debug                   # Enable debug output

REPORTS:
    HTML Report:    Comprehensive visual analysis report
    JSON Report:    Machine-readable analysis data
    CSV Metrics:    Quality metrics in spreadsheet format

For more information, visit: https://cursor.sh/docs/analysis
EOF
}

show_version() {
    cat << EOF
Cursor IDE Enterprise Code Analysis and Tracking Framework
Version: $SCRIPT_VERSION
Cursor Version: $CURSOR_VERSION
Build Date: $(date '+%Y-%m-%d')
Platform: $(uname -s) $(uname -m)

Analysis Capabilities:
- Function definition and usage tracking
- Dependency analysis and validation
- Code complexity metrics
- Security vulnerability scanning
- Code quality assessment
- Performance analysis

Copyright (c) 2024 Enterprise Development Team
Licensed under MIT License
EOF
}

main() {
    # Set up signal handlers
    trap cleanup EXIT
    trap 'error_handler ${LINENO} "$BASH_COMMAND" $?' ERR
    
    log "INFO" "Starting Cursor IDE Code Analysis Framework v$SCRIPT_VERSION"
    log "INFO" "Target directory: $TARGET_DIR"
    audit_log "ANALYSIS_STARTED" "Target: $TARGET_DIR" "SUCCESS"
    
    # Initialize environment
    create_directory_structure || {
        log "CRITICAL" "Failed to create directory structure"
        exit 1
    }
    
    initialize_configuration || {
        log "CRITICAL" "Failed to initialize configuration"
        exit 1
    }
    
    # Discover and analyze source files
    declare -a SOURCE_FILES=()
    discover_source_files || {
        log "ERROR" "Failed to discover source files"
        exit 1
    }
    
    if [[ ${#SOURCE_FILES[@]} -eq 0 ]]; then
        log "WARN" "No source files found in target directory"
        exit 1
    fi
    
    # Perform analysis
    log "INFO" "Beginning comprehensive code analysis..."
    
    analyze_functions || {
        log "ERROR" "Function analysis failed"
        exit 1
    }
    
    analyze_function_usage || {
        log "ERROR" "Function usage analysis failed"
        exit 1
    }
    
    analyze_dependencies || {
        log "ERROR" "Dependency analysis failed"
        exit 1
    }
    
    validate_dependencies || {
        log "WARN" "Dependency validation completed with issues"
    }
    
    analyze_security_vulnerabilities || {
        log "ERROR" "Security analysis failed"
        exit 1
    }
    
    analyze_code_quality || {
        log "ERROR" "Quality analysis failed"
        exit 1
    }
    
    # Generate reports
    log "INFO" "Generating analysis reports..."
    
    generate_html_report || {
        log "WARN" "HTML report generation failed"
    }
    
    generate_json_report || {
        log "WARN" "JSON report generation failed"
    }
    
    generate_csv_metrics || {
        log "WARN" "CSV metrics generation failed"
    }
    
    # Final summary
    log "INFO" "=== CODE ANALYSIS SUMMARY ==="
    log "INFO" "Files Analyzed: ${#SOURCE_FILES[@]}"
    log "INFO" "Functions Found: ${#FUNCTION_MAP[@]}"
    log "INFO" "Dependencies: ${#DEPENDENCY_MAP[@]}"
    log "INFO" "Analysis Results: ${#ANALYSIS_RESULTS[@]}"
    log "INFO" "Quality Score: ${QUALITY_METRICS[quality_score]}/100"
    log "INFO" "Security Issues: ${QUALITY_METRICS[security_issues]}"
    log "INFO" "Reports Directory: $REPORTS_DIR"
    
    audit_log "ANALYSIS_COMPLETED" "Success" "SUCCESS"
    
    if [[ ${QUALITY_METRICS[security_issues]} -gt 0 ]]; then
        log "WARN" "Security issues detected - review required"
        exit 1
    fi
    
    if [[ ${QUALITY_METRICS[quality_score]} -lt 70 ]]; then
        log "WARN" "Code quality below threshold - improvements recommended"
        exit 1
    fi
    
    log "SUCCESS" "Code analysis completed successfully"
    
    return 0
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Only run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi