#!/usr/bin/env bash
#
# PROFESSIONAL CURSOR IDE DOCKER DEPLOYMENT v2.0
# Enterprise-Grade Container Orchestration System
#
# Enhanced Features:
# - Robust container lifecycle management
# - Self-correcting deployment mechanisms
# - Advanced health monitoring
# - Professional logging and auditing
# - Automated backup and recovery
# - Performance optimization
#

set -euo pipefail
IFS=$'\n\t'

# === CONFIGURATION ===
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_NAME="$(basename "${0}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Docker Configuration
readonly DOCKER_NAMESPACE="cursor-enterprise"
readonly NETWORK_NAME="cursor-network"
readonly VOLUME_PREFIX="cursor-vol"
readonly CURSOR_VERSION="${CURSOR_VERSION:-6.9.35}"

# Directory Structure
readonly BASE_DIR="${HOME}/.cache/cursor/docker"
readonly LOG_DIR="${BASE_DIR}/logs"
readonly CONFIG_DIR="${BASE_DIR}/config"
readonly BACKUP_DIR="${BASE_DIR}/backup"
readonly COMPOSE_DIR="${BASE_DIR}/compose"

# Log Files
readonly MAIN_LOG="${LOG_DIR}/docker_${TIMESTAMP}.log"
readonly ERROR_LOG="${LOG_DIR}/docker_errors_${TIMESTAMP}.log"
readonly AUDIT_LOG="${LOG_DIR}/docker_audit_${TIMESTAMP}.log"

# Container Types
declare -A CONTAINER_TYPES=(
    ["base"]="Basic Cursor IDE container"
    ["dev"]="Development environment"
    ["enterprise"]="Full enterprise container"
)

# Service Ports
declare -A SERVICE_PORTS=(
    ["vnc"]=5900
    ["web"]=8080
    ["ssh"]=2222
    ["api"]=3000
)

# Runtime Variables
declare -g CONTAINER_TYPE="base"
declare -g DRY_RUN=false
declare -g QUIET_MODE=false
declare -g FORCE_REBUILD=false
declare -g ENABLE_MONITORING=false

# === UTILITY FUNCTIONS ===

# Enhanced logging
log() {
    local level="$1"
    local message="$2"
    local timestamp="$(date -Iseconds)"
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$MAIN_LOG")" 2>/dev/null || true
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
            [[ "$QUIET_MODE" != "true" ]] && echo -e "\033[0;34m[INFO]\033[0m ${message}"
            ;;
        DEBUG) 
            [[ "${DEBUG:-false}" == "true" ]] && echo -e "\033[0;36m[DEBUG]\033[0m ${message}"
            ;;
    esac
}

# Audit logging
audit_log() {
    local action="$1"
    local status="$2"
    local details="${3:-}"
    local user="${USER:-unknown}"
    local timestamp="$(date -Iseconds)"
    
    echo "[${timestamp}] USER=${user} ACTION=${action} STATUS=${status} DETAILS=${details}" >> "$AUDIT_LOG"
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
    local dirs=("$LOG_DIR" "$CONFIG_DIR" "$BACKUP_DIR" "$COMPOSE_DIR")
    
    for dir in "${dirs[@]}"; do
        if ! ensure_directory "$dir"; then
            echo "Failed to initialize directories"
            return 1
        fi
    done
    
    # Log rotation
    find "$LOG_DIR" -name "docker_*.log" -mtime +7 -delete 2>/dev/null || true
    find "$BACKUP_DIR" -name "backup_*.tar.gz" -mtime +30 -delete 2>/dev/null || true
    
    return 0
}

# Retry mechanism
retry_operation() {
    local operation="$1"
    local max_attempts="${2:-3}"
    local delay="${3:-2}"
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if eval "$operation"; then
            return 0
        fi
        
        ((attempt++))
        if [[ $attempt -lt $max_attempts ]]; then
            log "WARN" "Operation failed, retrying (attempt $((attempt + 1))/$max_attempts)"
            sleep "$delay"
        fi
    done
    
    log "ERROR" "Operation failed after $max_attempts attempts: $operation"
    return 1
}

# Cleanup function
cleanup() {
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log "PASS" "Docker operations completed successfully"
        audit_log "OPERATION_COMPLETE" "SUCCESS" "Exit code: $exit_code"
    else
        log "ERROR" "Docker operations failed with exit code: $exit_code"
        audit_log "OPERATION_FAILED" "FAILURE" "Exit code: $exit_code"
    fi
}

trap cleanup EXIT
trap 'exit 130' INT TERM

# === DOCKER VALIDATION ===

# Check Docker availability
check_docker() {
    log "INFO" "Checking Docker environment"
    
    local docker_issues=0
    
    # Check Docker installation
    if ! command -v docker >/dev/null 2>&1; then
        log "ERROR" "Docker not installed"
        ((docker_issues++))
    else
        local docker_version=$(docker --version | cut -d' ' -f3 | tr -d ',')
        log "DEBUG" "Docker version: $docker_version"
    fi
    
    # Check Docker daemon
    if ! docker info >/dev/null 2>&1; then
        log "ERROR" "Docker daemon not running"
        ((docker_issues++))
    else
        log "DEBUG" "Docker daemon running"
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose >/dev/null 2>&1 && ! docker compose version >/dev/null 2>&1; then
        log "WARN" "Docker Compose not available"
        ((docker_issues++))
    fi
    
    # Check system resources
    local total_mem_kb=$(grep "MemTotal:" /proc/meminfo 2>/dev/null | awk '{print $2}' || echo "0")
    local total_mem_mb=$((total_mem_kb / 1024))
    
    if [[ $total_mem_mb -lt 4096 ]]; then
        log "WARN" "Low memory: ${total_mem_mb}MB (recommended: 4GB+)"
    fi
    
    local available_disk_kb=$(df "$BASE_DIR" 2>/dev/null | tail -1 | awk '{print $4}' || df / | tail -1 | awk '{print $4}')
    local available_disk_gb=$((available_disk_kb / 1024 / 1024))
    
    if [[ $available_disk_gb -lt 10 ]]; then
        log "WARN" "Low disk space: ${available_disk_gb}GB (recommended: 10GB+)"
    fi
    
    if [[ $docker_issues -eq 0 ]]; then
        log "PASS" "Docker environment validated"
        return 0
    else
        log "ERROR" "Docker validation failed ($docker_issues issues)"
        return 1
    fi
}

# Initialize Docker network
initialize_network() {
    log "INFO" "Initializing Docker network"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would create network: $NETWORK_NAME"
        return 0
    fi
    
    # Check if network exists
    if docker network ls | grep -q "$NETWORK_NAME"; then
        log "DEBUG" "Network already exists: $NETWORK_NAME"
        return 0
    fi
    
    # Create network
    if docker network create \
        --driver bridge \
        --subnet=172.20.0.0/16 \
        --label "project=cursor-enterprise" \
        "$NETWORK_NAME"; then
        log "PASS" "Network created: $NETWORK_NAME"
        audit_log "NETWORK_CREATED" "SUCCESS" "Network: $NETWORK_NAME"
        return 0
    else
        log "ERROR" "Failed to create network"
        return 1
    fi
}

# === DOCKERFILE GENERATION ===

# Generate base Dockerfile
generate_base_dockerfile() {
    log "INFO" "Generating base Dockerfile"
    
    cat > "$COMPOSE_DIR/Dockerfile.base" << 'EOF'
FROM ubuntu:22.04

LABEL maintainer="Enterprise Development Team"
LABEL version="2.0.0"
LABEL description="Cursor IDE Base Container"

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1

# Install system packages
RUN apt-get update && apt-get install -y \
    curl wget git vim htop \
    xvfb x11vnc fluxbox \
    fonts-liberation \
    fuse libfuse2 \
    supervisor \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create user
RUN useradd -m -s /bin/bash cursor && \
    echo 'cursor:cursor' | chpasswd

# Create directories
RUN mkdir -p /opt/cursor /home/cursor/.config

# Download Cursor AppImage
RUN curl -fsSL "https://download.cursor.sh/linux/appImage/x64" \
    -o /opt/cursor/cursor.AppImage && \
    chmod +x /opt/cursor/cursor.AppImage && \
    ln -sf /opt/cursor/cursor.AppImage /usr/local/bin/cursor

# Setup VNC
RUN mkdir -p /home/cursor/.vnc && \
    echo "cursor" | vncpasswd -f > /home/cursor/.vnc/passwd && \
    chmod 600 /home/cursor/.vnc/passwd && \
    chown -R cursor:cursor /home/cursor

# Create startup script
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 5900 8080

WORKDIR /home/cursor
USER cursor

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD pgrep -f cursor || exit 1

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
EOF
    
    # Create entrypoint script
    cat > "$COMPOSE_DIR/entrypoint.sh" << 'EOF'
#!/bin/bash
set -e

export DISPLAY=:1

# Start Xvfb
Xvfb :1 -screen 0 1920x1080x24 &
sleep 2

# Start window manager
fluxbox &

# Start VNC server
x11vnc -display :1 -forever -usepw -shared -rfbport 5900 &

# Start Cursor IDE
cursor --no-sandbox &

exec "$@"
EOF
    
    log "PASS" "Base Dockerfile generated"
}

# Generate development Dockerfile
generate_dev_dockerfile() {
    log "INFO" "Generating development Dockerfile"
    
    cat > "$COMPOSE_DIR/Dockerfile.dev" << 'EOF'
FROM cursor-enterprise:base

USER root

# Install development tools
RUN apt-get update && apt-get install -y \
    nodejs npm python3 python3-pip \
    golang-go openjdk-11-jdk \
    postgresql-client \
    jq tree fd-find ripgrep \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install global packages
RUN npm install -g typescript prettier eslint && \
    pip3 install pytest black flake8

# Create workspace
RUN mkdir -p /workspace && \
    chown -R cursor:cursor /workspace

USER cursor
WORKDIR /workspace

HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD pgrep -f cursor && command -v node && command -v python3 || exit 1
EOF
    
    log "PASS" "Development Dockerfile generated"
}

# Generate enterprise Dockerfile
generate_enterprise_dockerfile() {
    log "INFO" "Generating enterprise Dockerfile"
    
    cat > "$COMPOSE_DIR/Dockerfile.enterprise" << 'EOF'
FROM cursor-enterprise:dev

USER root

# Install enterprise tools
RUN apt-get update && apt-get install -y \
    prometheus-node-exporter \
    rsyslog logrotate \
    netcat-openbsd \
    sysstat iotop \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create enterprise directories
RUN mkdir -p /opt/cursor/enterprise/{logs,config,reports} && \
    chown -R cursor:cursor /opt/cursor/enterprise

USER cursor

HEALTHCHECK --interval=60s --timeout=15s --start-period=120s --retries=5 \
    CMD pgrep -f cursor && pgrep -f node-exporter || exit 1

VOLUME ["/opt/cursor/enterprise", "/workspace"]
EOF
    
    log "PASS" "Enterprise Dockerfile generated"
}

# === DOCKER COMPOSE GENERATION ===

# Generate Docker Compose file
generate_compose() {
    log "INFO" "Generating Docker Compose configuration"
    
    cat > "$COMPOSE_DIR/docker-compose.yml" << EOF
version: '3.8'

networks:
  cursor-network:
    external: true

volumes:
  cursor-data:
    name: ${VOLUME_PREFIX}-data
  cursor-config:
    name: ${VOLUME_PREFIX}-config
  cursor-workspace:
    name: ${VOLUME_PREFIX}-workspace

services:
  cursor-base:
    build:
      context: .
      dockerfile: Dockerfile.base
    image: ${DOCKER_NAMESPACE}:base
    container_name: cursor-base
    networks:
      - cursor-network
    ports:
      - "${SERVICE_PORTS[vnc]}:5900"
      - "${SERVICE_PORTS[web]}:8080"
    volumes:
      - cursor-data:/home/cursor/.local/share/cursor
      - cursor-config:/home/cursor/.config
    environment:
      - DISPLAY=:1
      - CURSOR_VERSION=${CURSOR_VERSION}
    restart: unless-stopped
    profiles:
      - base

  cursor-dev:
    build:
      context: .
      dockerfile: Dockerfile.dev
    image: ${DOCKER_NAMESPACE}:dev
    container_name: cursor-dev
    networks:
      - cursor-network
    ports:
      - "${SERVICE_PORTS[vnc]}:5900"
      - "${SERVICE_PORTS[web]}:8080"
      - "${SERVICE_PORTS[ssh]}:22"
    volumes:
      - cursor-data:/home/cursor/.local/share/cursor
      - cursor-config:/home/cursor/.config
      - cursor-workspace:/workspace
    environment:
      - DISPLAY=:1
      - NODE_ENV=development
    restart: unless-stopped
    profiles:
      - dev

  cursor-enterprise:
    build:
      context: .
      dockerfile: Dockerfile.enterprise
    image: ${DOCKER_NAMESPACE}:enterprise
    container_name: cursor-enterprise
    networks:
      - cursor-network
    ports:
      - "${SERVICE_PORTS[vnc]}:5900"
      - "${SERVICE_PORTS[web]}:8080"
      - "${SERVICE_PORTS[ssh]}:22"
      - "${SERVICE_PORTS[api]}:3000"
    volumes:
      - cursor-data:/home/cursor/.local/share/cursor
      - cursor-config:/home/cursor/.config
      - cursor-workspace:/workspace
      - ./logs:/opt/cursor/enterprise/logs
    environment:
      - DISPLAY=:1
      - MONITORING_ENABLED=true
    restart: unless-stopped
    profiles:
      - enterprise
EOF
    
    log "PASS" "Docker Compose configuration generated"
}

# === CONTAINER OPERATIONS ===

# Build containers
build_containers() {
    log "INFO" "Building Cursor IDE containers"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would build containers for type: $CONTAINER_TYPE"
        return 0
    fi
    
    # Generate required files
    generate_base_dockerfile
    if [[ "$CONTAINER_TYPE" != "base" ]]; then
        generate_dev_dockerfile
    fi
    if [[ "$CONTAINER_TYPE" == "enterprise" ]]; then
        generate_enterprise_dockerfile
    fi
    generate_compose
    
    cd "$COMPOSE_DIR" || {
        log "ERROR" "Failed to change to compose directory"
        return 1
    }
    
    # Build containers based on type
    case "$CONTAINER_TYPE" in
        "base")
            if retry_operation "docker build -f Dockerfile.base -t '${DOCKER_NAMESPACE}:base' ."; then
                log "PASS" "Base container built successfully"
            else
                log "ERROR" "Failed to build base container"
                return 1
            fi
            ;;
        "dev")
            if retry_operation "docker build -f Dockerfile.base -t '${DOCKER_NAMESPACE}:base' ." && \
               retry_operation "docker build -f Dockerfile.dev -t '${DOCKER_NAMESPACE}:dev' ."; then
                log "PASS" "Development containers built successfully"
            else
                log "ERROR" "Failed to build development containers"
                return 1
            fi
            ;;
        "enterprise")
            if retry_operation "docker build -f Dockerfile.base -t '${DOCKER_NAMESPACE}:base' ." && \
               retry_operation "docker build -f Dockerfile.dev -t '${DOCKER_NAMESPACE}:dev' ." && \
               retry_operation "docker build -f Dockerfile.enterprise -t '${DOCKER_NAMESPACE}:enterprise' ."; then
                log "PASS" "Enterprise containers built successfully"
            else
                log "ERROR" "Failed to build enterprise containers"
                return 1
            fi
            ;;
        *)
            log "ERROR" "Unknown container type: $CONTAINER_TYPE"
            return 1
            ;;
    esac
    
    audit_log "CONTAINERS_BUILT" "SUCCESS" "Type: $CONTAINER_TYPE"
    return 0
}

# Start services
start_services() {
    log "INFO" "Starting Cursor IDE services"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would start services for type: $CONTAINER_TYPE"
        return 0
    fi
    
    cd "$COMPOSE_DIR" || {
        log "ERROR" "Failed to change to compose directory"
        return 1
    }
    
    # Start services with appropriate profile
    local compose_cmd="docker-compose --profile $CONTAINER_TYPE up -d"
    
    if eval "$compose_cmd"; then
        log "PASS" "Services started successfully"
        show_service_status
        audit_log "SERVICES_STARTED" "SUCCESS" "Type: $CONTAINER_TYPE"
        return 0
    else
        log "ERROR" "Failed to start services"
        return 1
    fi
}

# Stop services
stop_services() {
    log "INFO" "Stopping Cursor IDE services"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would stop all services"
        return 0
    fi
    
    cd "$COMPOSE_DIR" || {
        log "ERROR" "Failed to change to compose directory"
        return 1
    }
    
    if docker-compose down; then
        log "PASS" "Services stopped successfully"
        audit_log "SERVICES_STOPPED" "SUCCESS" "All services stopped"
        return 0
    else
        log "ERROR" "Failed to stop services"
        return 1
    fi
}

# Show service status
show_service_status() {
    log "INFO" "Service Status Overview"
    echo
    
    echo "Running Containers:"
    docker ps --filter "name=cursor-" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" || true
    echo
    
    echo "Access URLs:"
    if docker ps | grep -q "cursor-"; then
        echo "  VNC:         vnc://localhost:${SERVICE_PORTS[vnc]}"
        echo "  Web UI:      http://localhost:${SERVICE_PORTS[web]}"
        
        if [[ "$CONTAINER_TYPE" != "base" ]]; then
            echo "  SSH:         ssh cursor@localhost -p ${SERVICE_PORTS[ssh]}"
        fi
        
        if [[ "$CONTAINER_TYPE" == "enterprise" ]]; then
            echo "  API:         http://localhost:${SERVICE_PORTS[api]}"
        fi
    fi
    echo
    
    echo "Useful Commands:"
    echo "  Shell:       docker exec -it cursor-${CONTAINER_TYPE} bash"
    echo "  Logs:        docker-compose logs -f cursor-${CONTAINER_TYPE}"
    echo "  Restart:     docker-compose restart cursor-${CONTAINER_TYPE}"
    echo
}

# === BACKUP AND RESTORE ===

# Create backup
create_backup() {
    log "INFO" "Creating container backup"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would create backup"
        return 0
    fi
    
    local backup_file="$BACKUP_DIR/cursor_backup_${TIMESTAMP}.tar.gz"
    local backup_items=()
    
    # Collect volumes to backup
    for volume in $(docker volume ls --filter "name=${VOLUME_PREFIX}-" --format "{{.Name}}"); do
        backup_items+=("$volume")
    done
    
    if [[ ${#backup_items[@]} -gt 0 ]]; then
        # Create temporary container for backup
        docker run --rm \
            $(for vol in "${backup_items[@]}"; do echo "-v $vol:/backup/$vol:ro"; done) \
            -v "$BACKUP_DIR:/output" \
            busybox tar czf "/output/$(basename "$backup_file")" -C /backup .
        
        log "PASS" "Backup created: $backup_file"
        audit_log "BACKUP_CREATED" "SUCCESS" "File: $backup_file"
    else
        log "INFO" "No volumes to backup"
    fi
    
    return 0
}

# Run health checks
run_health_checks() {
    log "INFO" "Running health checks"
    
    local health_issues=0
    
    # Check container health
    for container in $(docker ps --filter "name=cursor-" --format "{{.Names}}"); do
        local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "unknown")
        if [[ "$health_status" != "healthy" ]]; then
            log "WARN" "Container health issue: $container ($health_status)"
            ((health_issues++))
        else
            log "DEBUG" "Container healthy: $container"
        fi
    done
    
    # Check service ports
    for port in "${SERVICE_PORTS[@]}"; do
        if ! nc -z localhost "$port" 2>/dev/null; then
            log "WARN" "Service port not accessible: $port"
            ((health_issues++))
        fi
    done
    
    if [[ $health_issues -eq 0 ]]; then
        log "PASS" "All health checks passed"
        return 0
    else
        log "WARN" "Health checks completed with $health_issues issues"
        return 1
    fi
}

# === MAIN EXECUTION ===

# Show usage
show_usage() {
    cat << EOF
Cursor IDE Professional Docker Deployment v$SCRIPT_VERSION

USAGE:
    $SCRIPT_NAME [COMMAND] [OPTIONS]

COMMANDS:
    build               Build container images
    start, up           Start services
    stop, down          Stop services
    status              Show service status
    shell               Open container shell
    backup              Create backup
    health              Run health checks
    logs                Show service logs

OPTIONS:
    -h, --help          Show this help message
    -t, --type TYPE     Container type: base, dev, enterprise
    -n, --dry-run       Perform dry run
    -f, --force         Force rebuild
    -q, --quiet         Quiet mode

CONTAINER TYPES:
$(for type in "${!CONTAINER_TYPES[@]}"; do
    printf "    %-12s %s\n" "$type" "${CONTAINER_TYPES[$type]}"
done)

EXAMPLES:
    $SCRIPT_NAME build --type enterprise
    $SCRIPT_NAME start --type dev
    $SCRIPT_NAME shell

EOF
}

# Parse arguments
parse_arguments() {
    local command=""
    
    # Check for help first before any other processing
    for arg in "$@"; do
        if [[ "$arg" == "--help" ]] || [[ "$arg" == "-h" ]]; then
            show_usage
            exit 0
        fi
    done
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --version)
                echo "Cursor IDE Professional Docker Deployment v$SCRIPT_VERSION"
                exit 0
                ;;
            -t|--type)
                if [[ -n "$2" ]] && [[ -n "${CONTAINER_TYPES[$2]}" ]]; then
                    CONTAINER_TYPE="$2"
                    shift
                else
                    log "ERROR" "Invalid container type: ${2:-}"
                    exit 1
                fi
                ;;
            -n|--dry-run)
                DRY_RUN=true
                ;;
            -f|--force)
                FORCE_REBUILD=true
                ;;
            -q|--quiet)
                QUIET_MODE=true
                ;;
            build|start|up|stop|down|status|shell|backup|health|logs)
                if [[ -z "$command" ]]; then
                    command="$1"
                else
                    log "ERROR" "Multiple commands specified"
                    exit 1
                fi
                ;;
            *)
                log "ERROR" "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
        shift
    done
    
    # Validate command was provided
    if [[ -z "$command" ]]; then
        log "ERROR" "No command specified"
        show_usage
        exit 1
    fi
    
    echo "$command"
}

# Main function
main() {
    # Check for help first - before any other processing
    for arg in "$@"; do
        if [[ "$arg" == "--help" ]] || [[ "$arg" == "-h" ]]; then
            show_usage
            return 0
        fi
    done
    
    local command=$(parse_arguments "$@")
    
    log "INFO" "Starting Cursor IDE Docker Deployment v$SCRIPT_VERSION"
    log "INFO" "Command: $command, Container Type: $CONTAINER_TYPE"
    audit_log "SCRIPT_STARTED" "SUCCESS" "Command: $command"
    
    # Initialize
    if ! initialize_directories; then
        log "ERROR" "Failed to initialize directories"
        exit 1
    fi
    
    # Execute command
    case "$command" in
        "build")
            check_docker || exit 1
            initialize_network || exit 1
            build_containers || exit 1
            ;;
        "start"|"up")
            check_docker || exit 1
            initialize_network || exit 1
            start_services || exit 1
            ;;
        "stop"|"down")
            stop_services || exit 1
            ;;
        "status")
            show_service_status
            ;;
        "shell")
            if [[ "$DRY_RUN" != "true" ]]; then
                docker exec -it "cursor-${CONTAINER_TYPE}" bash
            fi
            ;;
        "backup")
            create_backup || exit 1
            ;;
        "health")
            run_health_checks
            ;;
        "logs")
            if [[ "$DRY_RUN" != "true" ]]; then
                cd "$COMPOSE_DIR" && docker-compose logs -f
            fi
            ;;
        "help")
            show_usage
            ;;
        *)
            log "ERROR" "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
    
    log "PASS" "Docker deployment completed successfully"
    audit_log "SCRIPT_COMPLETED" "SUCCESS" "Command: $command"
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi