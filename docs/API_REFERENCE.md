# Enterprise Frameworks API Reference

## Professional Error Checking Framework API

### Core Functions

#### `init_error_framework()`
Initializes the error checking framework with logging and directory setup.

**Parameters**: None
**Returns**: 0 on success
**Side Effects**: Creates log directories, initializes error tracking

#### `log_framework(level, message, context)`
Central logging function with colored output and error tracking.

**Parameters**:
- `level` (string): Log level (CRITICAL, ERROR, WARN, INFO, DEBUG)
- `message` (string): Log message
- `context` (string, optional): Context identifier

**Returns**: None
**Side Effects**: Writes to log files, increments error counters

**Example**:
```bash
log_framework "ERROR" "Database connection failed" "database_init"
log_framework "INFO" "Process completed successfully"
```

#### `validate_required_param(param_name, param_value, validation_type)`
Validates input parameters with comprehensive type checking.

**Parameters**:
- `param_name` (string): Name of parameter for error messages
- `param_value` (string): Value to validate
- `validation_type` (string): Type of validation to perform

**Validation Types**:
- `string`: Non-empty string
- `number`: Positive integer
- `email`: Valid email format
- `url`: Valid HTTP/HTTPS URL
- `path`: Existing path
- `file`: Existing readable file
- `directory`: Existing directory

**Returns**: 0 if valid, 1 if invalid
**Side Effects**: Logs validation attempts and results

**Example**:
```bash
validate_required_param "config_file" "$CONFIG_PATH" "file" || exit 1
validate_required_param "user_email" "$EMAIL" "email" || exit 1
```

#### `validate_command_exists(command, required)`
Validates that required commands are available in the system.

**Parameters**:
- `command` (string): Command name to check
- `required` (boolean): Whether command is required (true/false)

**Returns**: 0 if command exists, 1 if not found
**Side Effects**: Logs command availability

**Example**:
```bash
validate_command_exists "git" true || exit 1
validate_command_exists "jq" false  # Optional command
```

#### `validate_environment(env_var, required, pattern)`
Validates environment variables with optional pattern matching.

**Parameters**:
- `env_var` (string): Environment variable name
- `required` (boolean): Whether variable is required
- `pattern` (string, optional): Regex pattern to match

**Returns**: 0 if valid, 1 if invalid
**Side Effects**: Logs environment validation

**Example**:
```bash
validate_environment "HOME" true
validate_environment "DEBUG" false "^(true|false)$"
```

#### `safe_execute(command, error_message, retry_count, retry_delay)`
Executes commands with retry logic and comprehensive error handling.

**Parameters**:
- `command` (string): Command to execute
- `error_message` (string, optional): Custom error message
- `retry_count` (number, optional): Number of retries (default: 0)
- `retry_delay` (number, optional): Delay between retries in seconds (default: 1)

**Returns**: Exit code of command
**Side Effects**: Logs execution attempts and results

**Example**:
```bash
safe_execute "git push origin main" "Git push failed" 3 5
safe_execute "npm test" "Tests failed"
```

#### `validate_disk_space(path, required_mb)`
Validates available disk space before operations.

**Parameters**:
- `path` (string): Path to check
- `required_mb` (number): Required space in megabytes

**Returns**: 0 if sufficient space, 1 if insufficient
**Side Effects**: Logs disk space validation

**Example**:
```bash
validate_disk_space "/var/log" 100  # Require 100MB
validate_disk_space "." 500         # Require 500MB in current dir
```

#### `setup_error_trap(cleanup_function)`
Sets up error and exit traps with custom cleanup function.

**Parameters**:
- `cleanup_function` (string): Name of cleanup function to call

**Returns**: None
**Side Effects**: Registers error and exit handlers

**Example**:
```bash
cleanup_on_error() {
    log_framework "INFO" "Cleaning up temporary files"
    rm -f /tmp/temp_*
}

setup_error_trap "cleanup_on_error"
```

### Advanced Functions

#### `validate_network_connectivity(host, port, timeout)`
Tests network connectivity to specified endpoints.

**Parameters**:
- `host` (string, optional): Host to test (default: google.com)
- `port` (number, optional): Port to test (default: 80)
- `timeout` (number, optional): Timeout in seconds (default: 5)

**Returns**: 0 if connected, 1 if failed
**Example**:
```bash
validate_network_connectivity "github.com" 443 10
```

#### `safe_file_operation(operation, source, destination)`
Validates file operations before execution.

**Parameters**:
- `operation` (string): Operation type (read, write, copy, move, delete)
- `source` (string): Source file path
- `destination` (string, optional): Destination path for copy/move

**Returns**: 0 if validation passes, 1 if fails
**Example**:
```bash
safe_file_operation "read" "/etc/config.conf"
safe_file_operation "copy" "source.txt" "backup/source.txt"
```

## Enterprise Testing Framework API

### Core Testing Functions

#### `validate_enterprise_input(value, validation_type, validation_rules, context)`
Advanced input validation with security focus.

**Parameters**:
- `value` (string): Value to validate
- `validation_type` (string): Validation type
- `validation_rules` (string, optional): Additional validation rules
- `context` (string, optional): Validation context

**Validation Types**:
- `string`, `number`, `email`, `url`
- `file_path`, `directory_path`, `ip_address`, `port`
- `json`, `xml`, `base64`
- `sql_injection`, `xss`, `command_injection`
- `custom`

**Returns**: 0 if valid, 1 if invalid
**Example**:
```bash
validate_enterprise_input "$user_input" "sql_injection" "" "login_form"
validate_enterprise_input "$json_data" "json" "required_fields:name,email" "api_request"
```

#### `execute_with_circuit_breaker(operation, fallback_function, service_name)`
Executes operations with circuit breaker pattern for reliability.

**Parameters**:
- `operation` (string): Operation to execute
- `fallback_function` (string): Fallback function name
- `service_name` (string): Service identifier

**Returns**: Operation exit code or fallback result
**Example**:
```bash
api_fallback() {
    echo "API unavailable, using cached data"
    cat /tmp/cached_response.json
}

execute_with_circuit_breaker "curl -s https://api.example.com/data" "api_fallback" "external_api"
```

#### `run_parallel_validation_suite(test_configs)`
Runs multiple validation tests in parallel.

**Parameters**:
- `test_configs` (array): Array of test configuration strings

**Returns**: 0 if all tests pass, 1 if any fail
**Example**:
```bash
test_configs=(
    "input:$email:email:user_registration"
    "file:$config:file_path:config_validation"
    "network:github.com:443:connectivity"
)
run_parallel_validation_suite "${test_configs[@]}"
```

### Performance Monitoring

#### `start_performance_monitoring(operation_name)`
Begins performance monitoring for an operation.

**Parameters**:
- `operation_name` (string): Name of operation to monitor

**Returns**: Monitoring session ID
**Side Effects**: Starts resource tracking

#### `stop_performance_monitoring(session_id)`
Stops performance monitoring and generates report.

**Parameters**:
- `session_id` (string): Session ID from start function

**Returns**: 0 on success
**Side Effects**: Generates performance report

### Security Functions

#### `scan_for_security_vulnerabilities(target_path, scan_level)`
Performs security vulnerability scanning.

**Parameters**:
- `target_path` (string): Path to scan
- `scan_level` (string): Scan level (basic, standard, strict, paranoid)

**Returns**: 0 if no vulnerabilities, 1 if found
**Example**:
```bash
scan_for_security_vulnerabilities "/var/www/html" "strict"
```

#### `validate_input_for_injection(input, injection_type)`
Validates input for specific injection attack patterns.

**Parameters**:
- `input` (string): Input to validate
- `injection_type` (string): Type of injection (sql, xss, command, ldap)

**Returns**: 0 if safe, 1 if dangerous
**Example**:
```bash
validate_input_for_injection "$user_query" "sql"
validate_input_for_injection "$html_content" "xss"
```

## Enhanced Test Runner API

### Test Discovery

#### `discover_test_scripts(test_pattern, search_dir)`
Discovers test scripts matching specified patterns.

**Parameters**:
- `test_pattern` (string, optional): Glob pattern (default: *test*.sh)
- `search_dir` (string, optional): Directory to search (default: current)

**Returns**: Prints discovered test paths
**Example**:
```bash
mapfile -t tests < <(discover_test_scripts "*integration*.sh" "tests/")
```

#### `validate_test_script(test_script)`
Validates test script before execution.

**Parameters**:
- `test_script` (string): Path to test script

**Returns**: 0 if valid, 1 if invalid
**Side Effects**: Logs validation results

### Test Execution

#### `execute_single_test(test_script)`
Executes a single test with comprehensive monitoring.

**Parameters**:
- `test_script` (string): Path to test script

**Returns**: Test exit code
**Side Effects**: Creates test log, updates test statistics

#### `execute_parallel_tests(tests)`
Executes multiple tests in parallel with concurrency control.

**Parameters**:
- `tests` (array): Array of test script paths

**Returns**: 0 if all pass, 1 if any fail
**Side Effects**: Manages parallel execution, collects results

### Specialized Testing

#### `run_installation_script_tests()`
Tests all installation scripts for help functionality and syntax.

**Parameters**: None
**Returns**: 0 if all pass, 1 if any fail
**Side Effects**: Tests all numbered installation scripts

#### `run_gui_script_tests()`
Tests GUI scripts to ensure help works without opening windows.

**Parameters**: None
**Returns**: 0 if all pass, 1 if any fail
**Side Effects**: Tests tkinter and zenity scripts

## Multi-Layer Analysis API

### Analysis Functions

#### `run_shellcheck_analysis(target_files, output_format)`
Runs ShellCheck analysis on shell scripts.

**Parameters**:
- `target_files` (array): Files to analyze
- `output_format` (string): Output format (json, xml, gcc, checkstyle)

**Returns**: 0 if no issues, 1 if issues found
**Example**:
```bash
run_shellcheck_analysis "scripts/*.sh" "json"
```

#### `run_security_analysis(target_dir, security_level)`
Performs comprehensive security analysis.

**Parameters**:
- `target_dir` (string): Directory to analyze
- `security_level` (string): Analysis level (basic, strict, paranoid)

**Returns**: 0 if secure, 1 if vulnerabilities found
**Example**:
```bash
run_security_analysis "/var/www" "strict"
```

#### `generate_analysis_report(analysis_results, output_format)`
Generates comprehensive analysis reports.

**Parameters**:
- `analysis_results` (array): Results from analysis layers
- `output_format` (string): Format (html, json, xml, text)

**Returns**: 0 on success
**Side Effects**: Creates formatted report files

### Configuration Functions

#### `load_analysis_config(config_file)`
Loads analysis configuration from file.

**Parameters**:
- `config_file` (string): Path to configuration file

**Returns**: 0 on success, 1 on error
**Side Effects**: Updates analysis configuration

#### `add_custom_pattern(pattern, severity, description)`
Adds custom analysis patterns.

**Parameters**:
- `pattern` (string): Regex pattern to match
- `severity` (string): Severity level (LOW, MEDIUM, HIGH, CRITICAL)
- `description` (string): Pattern description

**Returns**: 0 on success
**Example**:
```bash
add_custom_pattern "TODO.*URGENT" "HIGH" "Urgent todo items"
add_custom_pattern "FIXME" "MEDIUM" "Code requiring fixes"
```

## Global Variables

### Error Framework Variables
```bash
ERROR_COUNT          # Total error count
WARNING_COUNT        # Total warning count  
VALIDATION_COUNT     # Total validation attempts
ERROR_CATEGORIES     # Associative array of error categories
ERROR_LOG_DIR        # Error log directory path
ERROR_LOG            # Main error log file
```

### Testing Framework Variables
```bash
FRAMEWORK_CONFIG     # Framework configuration array
TOTAL_TESTS         # Total number of tests
PASSED_TESTS        # Number of passed tests
FAILED_TESTS        # Number of failed tests
SKIPPED_TESTS       # Number of skipped tests
TEST_SUITE_RESULTS  # Test results array
```

## Return Codes

### Standard Return Codes
- `0`: Success
- `1`: General error
- `2`: Skipped (tests only)
- `124`: Timeout (command execution)

### Framework-Specific Codes
- `10`: Validation error
- `11`: Configuration error
- `12`: Network error
- `13`: Permission error
- `14`: Resource exhaustion

## Integration Examples

### Basic Script Integration
```bash
#!/usr/bin/env bash
source "scripts/lib/professional_error_checking.sh"
setup_error_trap "cleanup"

cleanup() {
    log_framework "INFO" "Cleaning up"
}

main() {
    validate_required_param "config" "$1" "file" || exit 1
    safe_execute "process_config $1" "Config processing failed" 3 2
}

main "$@"
```

### Advanced Integration
```bash
#!/usr/bin/env bash
source "scripts/enterprise_error_testing_framework.sh"

main() {
    # Run comprehensive validation
    run_comprehensive_validation || exit 1
    
    # Execute with circuit breaker
    execute_with_circuit_breaker "external_service_call" "fallback_handler" "api"
    
    # Parallel validation
    test_configs=(
        "input:$email:email:registration"
        "file:$config:file_path:validation"
    )
    run_parallel_validation_suite "${test_configs[@]}"
}
```

---

*API Reference for cursor_bundle Enterprise Quality Assurance Frameworks*