# Enterprise Frameworks Integration Guide

This guide provides step-by-step instructions for integrating the enterprise error checking and quality assurance frameworks into your scripts and applications.

## Quick Start

### 1. Basic Error Framework Integration

For simple scripts that need basic error checking and validation:

```bash
#!/usr/bin/env bash
# Source the professional error checking framework
source "scripts/lib/professional_error_checking.sh"

# Set up error trap with cleanup function
setup_error_trap "cleanup"

# Define cleanup function
cleanup() {
    log_framework "INFO" "Performing cleanup"
    # Add your cleanup logic here
}

main() {
    # Validate required parameters
    validate_required_param "input_file" "$1" "file" || exit 1
    validate_required_param "output_dir" "$2" "directory" || exit 1
    
    # Validate required commands
    validate_command_exists "git" true || exit 1
    
    # Safe command execution
    safe_execute "git status" "Git status failed" || exit 1
    
    log_framework "INFO" "Script completed successfully"
}

main "$@"
```

### 2. Advanced Enterprise Framework Integration

For complex applications requiring comprehensive validation:

```bash
#!/usr/bin/env bash
# Source enterprise testing framework (includes error framework)
source "scripts/enterprise_error_testing_framework.sh"

# Configure framework
FRAMEWORK_CONFIG["security_scan_level"]="strict"
FRAMEWORK_CONFIG["max_concurrent_operations"]="5"

setup_error_trap "advanced_cleanup"

advanced_cleanup() {
    log_framework "INFO" "Running advanced cleanup"
    stop_all_monitoring_sessions
    cleanup_temporary_resources
}

main() {
    # Run comprehensive system validation
    run_comprehensive_validation || exit 1
    
    # Validate user inputs with security checks
    validate_enterprise_input "$user_email" "email" "" "user_registration" || exit 1
    validate_enterprise_input "$user_input" "sql_injection" "" "database_query" || exit 1
    
    # Execute with circuit breaker protection
    execute_with_circuit_breaker "external_api_call" "api_fallback" "payment_service" || exit 1
    
    log_framework "INFO" "Advanced operation completed"
}

main "$@"
```

## Integration Patterns

### Pattern 1: Validation-First Scripts

Scripts that prioritize input validation and error prevention:

```bash
#!/usr/bin/env bash
source "scripts/lib/professional_error_checking.sh"
setup_error_trap "validation_cleanup"

validate_all_inputs() {
    log_framework "INFO" "Starting input validation"
    
    # Environment validation
    validate_environment "HOME" true || return 1
    validate_environment "USER" true || return 1
    
    # Command validation
    validate_command_exists "curl" true || return 1
    validate_command_exists "jq" true || return 1
    
    # Parameter validation
    validate_required_param "api_key" "$API_KEY" "string" || return 1
    validate_required_param "config_file" "$CONFIG_FILE" "file" || return 1
    
    # Network validation
    validate_network_connectivity "api.example.com" 443 10 || return 1
    
    # Disk space validation
    validate_disk_space "/tmp" 100 || return 1
    
    log_framework "INFO" "All validations passed"
    return 0
}

main() {
    validate_all_inputs || exit 1
    
    # Now safely proceed with main logic
    safe_execute "curl -s https://api.example.com/data" "API call failed" 3 5
}
```

### Pattern 2: Test-Driven Integration

Integration with comprehensive testing framework:

```bash
#!/usr/bin/env bash
source "scripts/enhanced_test_runner.sh"

# Configure testing environment
TEST_TIMEOUT=600
MAX_PARALLEL_TESTS=8
COMPREHENSIVE_MODE=true

run_application_tests() {
    log_framework "INFO" "Running application-specific tests"
    
    # Discover and run custom tests
    local test_scripts
    mapfile -t test_scripts < <(discover_test_scripts "*app*.sh" "tests/")
    
    if [[ ${#test_scripts[@]} -gt 0 ]]; then
        execute_parallel_tests "${test_scripts[@]}"
    fi
    
    # Run installation script tests
    run_installation_script_tests
    
    # Run GUI script tests
    run_gui_script_tests
    
    # Generate comprehensive report
    generate_test_summary
}

main() {
    validate_test_environment || exit 1
    run_application_tests
    
    if [[ $FAILED_TESTS -gt 0 ]]; then
        log_framework "ERROR" "Application tests failed"
        exit 1
    fi
    
    log_framework "INFO" "All application tests passed"
}
```

### Pattern 3: Security-First Integration

Integration focused on security validation:

```bash
#!/usr/bin/env bash
source "scripts/enterprise_error_testing_framework.sh"

# Configure security settings
FRAMEWORK_CONFIG["security_scan_level"]="paranoid"
FRAMEWORK_CONFIG["injection_detection"]="enabled"

validate_security_requirements() {
    log_framework "INFO" "Running security validation"
    
    # Scan for vulnerabilities
    scan_for_security_vulnerabilities "." "strict" || return 1
    
    # Validate all user inputs for injection attacks
    for input in "$@"; do
        validate_input_for_injection "$input" "sql" || return 1
        validate_input_for_injection "$input" "xss" || return 1
        validate_input_for_injection "$input" "command" || return 1
    done
    
    # Check file permissions
    validate_file_permissions "/etc/secrets" "600" || return 1
    
    log_framework "INFO" "Security validation completed"
    return 0
}

main() {
    validate_security_requirements "$@" || exit 1
    
    # Proceed with secure operations
    log_framework "INFO" "Security requirements satisfied"
}
```

## Framework-Specific Integration

### Professional Error Checking Framework

#### Basic Setup
```bash
# 1. Source the framework
source "scripts/lib/professional_error_checking.sh"

# 2. Set up error handling
setup_error_trap "my_cleanup"

# 3. Define cleanup function
my_cleanup() {
    log_framework "INFO" "Cleaning up resources"
    # Your cleanup code here
}
```

#### Configuration Options
```bash
# Enable debug mode
export DEBUG=true

# Enable network validation
export VALIDATE_NETWORK=true

# Set custom log directory
export ERROR_LOG_DIR="/custom/logs"
```

#### Common Usage Patterns
```bash
# Input validation
validate_required_param "username" "$USERNAME" "string"
validate_required_param "config" "$CONFIG_PATH" "file"
validate_required_param "email" "$EMAIL" "email"

# Command validation
validate_command_exists "git" true
validate_command_exists "docker" false

# Safe execution
safe_execute "git clone $REPO" "Clone failed" 3 5
safe_execute "npm install" "Install failed"

# File operations
safe_file_operation "read" "/etc/config"
safe_file_operation "copy" "source.txt" "backup/"
```

### Enterprise Testing Framework

#### Advanced Setup
```bash
# 1. Source the enterprise framework
source "scripts/enterprise_error_testing_framework.sh"

# 2. Configure framework
FRAMEWORK_CONFIG["max_concurrent_tests"]="20"
FRAMEWORK_CONFIG["security_scan_level"]="strict"
FRAMEWORK_CONFIG["circuit_breaker_enabled"]="true"

# 3. Set up monitoring
setup_comprehensive_monitoring
```

#### Security Integration
```bash
# Input security validation
validate_enterprise_input "$user_data" "sql_injection" "" "login"
validate_enterprise_input "$file_content" "xss" "" "upload"
validate_enterprise_input "$shell_command" "command_injection" "" "exec"

# Security scanning
scan_for_security_vulnerabilities "/var/www" "paranoid"
validate_file_permissions "/etc/secrets" "600"
```

#### Circuit Breaker Pattern
```bash
# Define fallback function
api_fallback() {
    log_framework "WARN" "API unavailable, using cached data"
    cat "/tmp/cached_response.json"
}

# Execute with circuit breaker
execute_with_circuit_breaker "curl -s $API_URL" "api_fallback" "external_api"
```

### Enhanced Test Runner

#### Test Discovery and Execution
```bash
# Configure test runner
TEST_TIMEOUT=300
MAX_PARALLEL_TESTS=4
COMPREHENSIVE_MODE=true

# Discover tests
mapfile -t tests < <(discover_test_scripts "*unit*.sh" "tests/unit/")

# Validate tests
for test in "${tests[@]}"; do
    validate_test_script "$test" || continue
done

# Execute tests
execute_parallel_tests "${tests[@]}"
```

#### Custom Test Integration
```bash
# Add custom test functions
run_custom_application_tests() {
    log_framework "INFO" "Running custom application tests"
    
    # Test application startup
    local startup_test="app_startup_test"
    execute_single_test "tests/startup.sh"
    
    # Test API endpoints
    execute_single_test "tests/api_endpoints.sh"
    
    # Test database connectivity
    execute_single_test "tests/database.sh"
}

# Integrate with main test suite
main() {
    validate_test_environment || exit 1
    
    # Standard tests
    run_installation_script_tests
    run_gui_script_tests
    
    # Custom tests
    run_custom_application_tests
    
    generate_test_summary
}
```

## CI/CD Integration

### GitHub Actions Integration

```yaml
name: Enterprise Quality Assurance
on: [push, pull_request]

jobs:
  quality-assurance:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Enterprise Validation
        run: |
          # Source frameworks
          source scripts/lib/professional_error_checking.sh
          source scripts/enterprise_error_testing_framework.sh
          
          # Run comprehensive validation
          run_comprehensive_validation
          
          # Run security scanning
          scan_for_security_vulnerabilities "." "strict"
          
          # Run all tests
          scripts/enhanced_test_runner.sh --comprehensive
          
      - name: Upload Test Reports
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: test-reports
          path: test-results/
```

### Docker Integration

```dockerfile
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    bash \
    curl \
    git \
    jq \
    shellcheck \
    && rm -rf /var/lib/apt/lists/*

# Copy frameworks
COPY scripts/ /app/scripts/
COPY docs/ /app/docs/

WORKDIR /app

# Set up environment
ENV DEBUG=false
ENV VALIDATE_NETWORK=false
ENV ERROR_LOG_DIR=/app/logs

# Create directories
RUN mkdir -p /app/logs /app/test-results

# Validate frameworks
RUN source scripts/lib/professional_error_checking.sh && \
    run_comprehensive_validation

# Default command
CMD ["scripts/enhanced_test_runner.sh", "--comprehensive"]
```

### Jenkins Integration

```groovy
pipeline {
    agent any
    
    environment {
        DEBUG = 'true'
        VALIDATE_NETWORK = 'true'
    }
    
    stages {
        stage('Setup') {
            steps {
                script {
                    sh '''
                        source scripts/lib/professional_error_checking.sh
                        run_comprehensive_validation
                    '''
                }
            }
        }
        
        stage('Security Scan') {
            steps {
                script {
                    sh '''
                        source scripts/enterprise_error_testing_framework.sh
                        scan_for_security_vulnerabilities "." "strict"
                    '''
                }
            }
        }
        
        stage('Test Execution') {
            steps {
                script {
                    sh '''
                        scripts/enhanced_test_runner.sh --comprehensive \
                            --parallel=8 \
                            --timeout=600
                    '''
                }
            }
        }
        
        stage('Code Analysis') {
            steps {
                script {
                    sh '''
                        scripts/multi_layer_code_analysis.sh \
                            --target-dir=. \
                            --output-format=html \
                            --security-level=strict
                    '''
                }
            }
        }
    }
    
    post {
        always {
            publishHTML([
                allowMissing: false,
                alwaysLinkToLastBuild: true,
                keepAll: true,
                reportDir: 'test-results',
                reportFiles: '*.html',
                reportName: 'Quality Assurance Report'
            ])
        }
    }
}
```

## Migration Guide

### Migrating Existing Scripts

#### Step 1: Assessment
```bash
# Create migration assessment script
#!/usr/bin/env bash
source "scripts/lib/professional_error_checking.sh"

assess_script_migration() {
    local script_path="$1"
    
    log_framework "INFO" "Assessing migration needs for: $script_path"
    
    # Check for existing error handling
    if grep -q "set -e" "$script_path"; then
        log_framework "INFO" "Script already has basic error handling"
    else
        log_framework "WARN" "Script lacks error handling"
    fi
    
    # Check for input validation
    if grep -q "validate\|check.*param" "$script_path"; then
        log_framework "INFO" "Script has some validation"
    else
        log_framework "WARN" "Script lacks input validation"
    fi
    
    # Generate migration recommendations
    echo "Migration recommendations for $script_path:"
    echo "1. Add professional error checking framework"
    echo "2. Implement input validation"
    echo "3. Add safe command execution"
    echo "4. Set up error traps and cleanup"
}

# Assess all scripts
find . -name "*.sh" -type f | while read -r script; do
    assess_script_migration "$script"
done
```

#### Step 2: Gradual Migration
```bash
# Minimal migration - add basic error checking
#!/usr/bin/env bash
# Original script with minimal changes

# Add error checking framework
source "scripts/lib/professional_error_checking.sh"
setup_error_trap "cleanup"

cleanup() {
    # Add cleanup logic
    log_framework "INFO" "Script cleanup completed"
}

# Keep existing logic but add validation
main() {
    # Add basic parameter validation
    validate_required_param "input" "$1" "string" || exit 1
    
    # Keep existing commands but make them safe
    safe_execute "original_command" "Command failed"
    
    # Rest of original logic unchanged
}

main "$@"
```

#### Step 3: Full Migration
```bash
# Complete migration with all features
#!/usr/bin/env bash
source "scripts/enterprise_error_testing_framework.sh"

# Configure for production use
FRAMEWORK_CONFIG["security_scan_level"]="strict"
FRAMEWORK_CONFIG["circuit_breaker_enabled"]="true"

setup_error_trap "full_cleanup"

full_cleanup() {
    log_framework "INFO" "Running comprehensive cleanup"
    stop_all_monitoring_sessions
    cleanup_temporary_files
    generate_final_report
}

main() {
    # Comprehensive validation
    run_comprehensive_validation || exit 1
    
    # Security-focused input validation
    for arg in "$@"; do
        validate_enterprise_input "$arg" "sql_injection" "" "main_args"
        validate_enterprise_input "$arg" "command_injection" "" "main_args"
    done
    
    # Circuit breaker protected operations
    execute_with_circuit_breaker "critical_operation" "fallback_handler" "main_service"
    
    log_framework "INFO" "Migration completed successfully"
}

main "$@"
```

## Best Practices

### 1. Framework Selection
- **Simple scripts**: Use professional error checking framework
- **Complex applications**: Use enterprise testing framework
- **Security-critical**: Enable all security features
- **CI/CD pipelines**: Use enhanced test runner

### 2. Error Handling Strategy
```bash
# Always set up error traps early
setup_error_trap "cleanup"

# Use specific cleanup functions
cleanup() {
    # Stop background processes
    pkill -f "background_process" 2>/dev/null || true
    
    # Clean temporary files
    rm -f /tmp/script_temp_*
    
    # Log cleanup completion
    log_framework "INFO" "Cleanup completed"
}
```

### 3. Validation Strategy
```bash
# Validate early and often
validate_all_prerequisites() {
    # Environment
    validate_environment "HOME" true
    validate_environment "USER" true
    
    # Commands
    validate_command_exists "git" true
    validate_command_exists "curl" true
    
    # Resources
    validate_disk_space "." 100
    validate_network_connectivity "github.com" 443
    
    return 0
}
```

### 4. Security Integration
```bash
# Always validate user inputs for security
secure_input_processing() {
    local user_input="$1"
    
    # Multiple security checks
    validate_enterprise_input "$user_input" "sql_injection" "" "user_data"
    validate_enterprise_input "$user_input" "xss" "" "user_data"
    validate_enterprise_input "$user_input" "command_injection" "" "user_data"
    
    # Additional custom validation
    if [[ "$user_input" =~ [;&|] ]]; then
        log_framework "ERROR" "Dangerous characters in input"
        return 1
    fi
    
    return 0
}
```

## Troubleshooting Integration Issues

### Common Problems and Solutions

#### 1. Framework Not Found
**Problem**: `source: scripts/lib/professional_error_checking.sh: No such file or directory`

**Solution**:
```bash
# Check framework path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_PATH="$SCRIPT_DIR/scripts/lib/professional_error_checking.sh"

if [[ ! -f "$FRAMEWORK_PATH" ]]; then
    echo "Error: Framework not found at $FRAMEWORK_PATH" >&2
    exit 1
fi

source "$FRAMEWORK_PATH"
```

#### 2. Permission Issues
**Problem**: Framework cannot create log directories

**Solution**:
```bash
# Ensure log directory is writable
ensure_log_directory() {
    local log_dir="${ERROR_LOG_DIR:-$HOME/.cache/cursor/error-framework}"
    
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" || {
            echo "Cannot create log directory: $log_dir" >&2
            echo "Using temporary directory instead" >&2
            ERROR_LOG_DIR="/tmp/cursor-error-framework-$$"
            mkdir -p "$ERROR_LOG_DIR"
        }
    fi
}

ensure_log_directory
```

#### 3. Performance Issues
**Problem**: Framework causing slowdowns

**Solution**:
```bash
# Optimize framework performance
optimize_framework() {
    # Reduce logging verbosity
    export DEBUG=false
    export VERBOSE_VALIDATION=false
    
    # Disable optional features
    export VALIDATE_NETWORK=false
    export GENERATE_DETAILED_REPORTS=false
    
    # Reduce parallel job count
    FRAMEWORK_CONFIG["max_concurrent_tests"]="2"
    FRAMEWORK_CONFIG["max_parallel_validations"]="2"
}

optimize_framework
```

---

*Integration Guide for cursor_bundle Enterprise Quality Assurance Frameworks*