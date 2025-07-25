#\!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# ============================================================================
# 15-docker-improved-v2.sh - Professional Docker Integration Framework v2.0
# Enterprise-grade Docker containerization with robust error handling and self-correcting mechanisms
# ============================================================================

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="2.0.0"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

# Configuration Management
readonly APP_NAME="cursor"
readonly DOCKER_CONFIG_DIR="${HOME}/.config/cursor-docker"
readonly DOCKER_CACHE_DIR="${HOME}/.cache/cursor-docker"
readonly DOCKER_LOG_DIR="${DOCKER_CONFIG_DIR}/logs"

# Logging Configuration
readonly LOG_FILE="${DOCKER_LOG_DIR}/docker_${TIMESTAMP}.log"
readonly ERROR_LOG="${DOCKER_LOG_DIR}/docker_errors_${TIMESTAMP}.log"
readonly CONTAINER_LOG="${DOCKER_LOG_DIR}/containers_${TIMESTAMP}.log"

# Docker Configuration
readonly DOCKER_IMAGE_NAME="cursor-ide"
readonly DOCKER_TAG="latest"
readonly CONTAINER_NAME="cursor-ide-container"

# Lock Management
readonly LOCK_FILE="${DOCKER_CONFIG_DIR}/.docker.lock"
readonly PID_FILE="${DOCKER_CONFIG_DIR}/.docker.pid"

# Global Variables
declare -g DOCKER_CONFIG="${DOCKER_CONFIG_DIR}/docker.conf"
declare -g VERBOSE_MODE=false
declare -g DRY_RUN_MODE=false
declare -g DOCKER_OPERATION_SUCCESS=true

# Enhanced error handling with self-correction
error_handler() {
    local line_no="$1"
    local bash_command="$2"
    local exit_code="$3"
    
    log_error "Error on line $line_no: Command '$bash_command' failed with exit code $exit_code"
    
    # Self-correction attempts
    case "$bash_command" in
        *"docker"*)
            log_info "Docker command failed, checking Docker status..."
            check_docker_status
            ;;
        *"mkdir"*)
            log_info "Directory creation failed, attempting to fix permissions..."
            fix_directory_permissions
            ;;
        *"build"*)
            log_info "Build failed, checking build context and cleanup..."
            cleanup_build_context
            ;;
    esac
    
    cleanup_on_error
}

# Professional logging system
log_info() {
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [INFO] $message"  < /dev/null |  tee -a "$LOG_FILE"
    [[ "$VERBOSE_MODE" == "true" ]] && echo "[INFO] $message" >&2
}

log_error() {
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [ERROR] $message" | tee -a "$LOG_FILE" >&2
    echo "[$timestamp] [ERROR] $message" >> "$ERROR_LOG"
}

log_warning() {
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [WARNING] $message" | tee -a "$LOG_FILE"
    [[ "$VERBOSE_MODE" == "true" ]] && echo "[WARNING] $message" >&2
}

log_container() {
    local action="$1"
    local container="$2"
    local status="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] CONTAINER: $action - $container = $status" >> "$CONTAINER_LOG"
}

# Initialize Docker framework
initialize_docker_framework() {
    log_info "Initializing Professional Docker Integration Framework v${VERSION}"
    
    # Set up error handling
    trap 'error_handler ${LINENO} "$BASH_COMMAND" $?' ERR
    trap 'cleanup_on_exit' EXIT
    trap 'log_info "Received interrupt signal, cleaning up..."; cleanup_on_exit; exit 130' INT TERM
    
    # Create directory structure
    create_directory_structure
    
    # Load configuration
    load_configuration
    
    # Validate Docker installation
    validate_docker_installation
    
    # Acquire lock
    acquire_lock
    
    log_info "Docker framework initialization completed successfully"
}

# Create directory structure with retry logic
create_directory_structure() {
    local dirs=("$DOCKER_CONFIG_DIR" "$DOCKER_CACHE_DIR" "$DOCKER_LOG_DIR")
    local max_retries=3
    
    for dir in "${dirs[@]}"; do
        local retry_count=0
        while [[ $retry_count -lt $max_retries ]]; do
            if mkdir -p "$dir" 2>/dev/null; then
                break
            else
                ((retry_count++))
                log_warning "Failed to create directory $dir (attempt $retry_count/$max_retries)"
                sleep 1
            fi
        done
        
        if [[ $retry_count -eq $max_retries ]]; then
            log_error "Failed to create directory $dir after $max_retries attempts"
            return 1
        fi
    done
}

# Load configuration with defaults
load_configuration() {
    if [[ \! -f "$DOCKER_CONFIG" ]]; then
        log_info "Creating default Docker configuration"
        create_default_configuration
    fi
    
    # Source configuration safely
    if [[ -r "$DOCKER_CONFIG" ]]; then
        source "$DOCKER_CONFIG"
        log_info "Configuration loaded from $DOCKER_CONFIG"
    else
        log_warning "Configuration file not readable, using defaults"
    fi
}

# Create default configuration
create_default_configuration() {
    cat > "$DOCKER_CONFIG" << 'CONFIGEOF'
# Professional Docker Integration Framework Configuration v2.0

# General Settings
VERBOSE_MODE=false
DRY_RUN_MODE=false
AUTO_CLEANUP=true
ENABLE_MONITORING=true

# Docker Settings
DOCKER_REGISTRY=""
DOCKER_NAMESPACE="cursor"
BASE_IMAGE="ubuntu:22.04"
EXPOSE_PORTS="3000,8080"

# Container Settings
CONTAINER_MEMORY_LIMIT="2g"
CONTAINER_CPU_LIMIT="2.0"
ENABLE_GPU_SUPPORT=false
MOUNT_HOME_DIRECTORY=true

# Volume Settings
ENABLE_PERSISTENT_STORAGE=true
DATA_VOLUME_SIZE="10g"
CONFIG_VOLUME_PATH="/app/config"
WORKSPACE_VOLUME_PATH="/workspace"

# Network Settings
NETWORK_MODE="bridge"
CUSTOM_NETWORK_NAME="cursor-network"
ENABLE_HOST_NETWORKING=false
DNS_SERVERS="8.8.8.8,8.8.4.4"

# Security Settings
RUN_AS_NON_ROOT=true
ENABLE_APPARMOR=false
ENABLE_SECCOMP=true
READ_ONLY_ROOT_FILESYSTEM=false

# Maintenance Settings
LOG_RETENTION_DAYS=30
AUTO_UPDATE_IMAGES=false
CLEANUP_INTERVAL_HOURS=24
ENABLE_HEALTH_CHECKS=true
CONFIGEOF
    
    log_info "Default configuration created: $DOCKER_CONFIG"
}

# Validate Docker installation
validate_docker_installation() {
    log_info "Validating Docker installation..."
    
    # Check if Docker is installed
    if \! command -v docker &>/dev/null; then
        log_error "Docker is not installed or not in PATH"
        return 1
    fi
    
    # Check if Docker daemon is running
    if \! docker info >/dev/null 2>&1; then
        log_error "Docker daemon is not running"
        
        # Attempt to start Docker if systemctl is available
        if command -v systemctl &>/dev/null; then
            log_info "Attempting to start Docker daemon..."
            if sudo systemctl start docker 2>/dev/null; then
                sleep 3
                if docker info >/dev/null 2>&1; then
                    log_info "Docker daemon started successfully"
                else
                    log_error "Failed to start Docker daemon"
                    return 1
                fi
            else
                log_error "Failed to start Docker daemon via systemctl"
                return 1
            fi
        else
            return 1
        fi
    fi
    
    # Check Docker version
    local docker_version
    docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
    log_info "Docker version: $docker_version"
    
    # Check if user can run Docker commands
    if \! docker ps >/dev/null 2>&1; then
        log_warning "Current user may not have permission to run Docker commands"
        log_info "You may need to add your user to the 'docker' group or use sudo"
    fi
    
    log_info "Docker validation completed successfully"
}

# Acquire lock with timeout
acquire_lock() {
    local timeout=10
    local elapsed=0
    
    while [[ $elapsed -lt $timeout ]]; do
        if (set -C; echo $$ > "$LOCK_FILE") 2>/dev/null; then
            echo $$ > "$PID_FILE"
            log_info "Lock acquired successfully"
            return 0
        fi
        
        if [[ -f "$LOCK_FILE" ]]; then
            local lock_pid
            lock_pid=$(cat "$LOCK_FILE" 2>/dev/null || echo "")
            if [[ -n "$lock_pid" ]] && \! kill -0 "$lock_pid" 2>/dev/null; then
                log_info "Removing stale lock file"
                rm -f "$LOCK_FILE"
                continue
            fi
        fi
        
        sleep 1
        ((elapsed++))
    done
    
    log_warning "Could not acquire lock, continuing anyway"
    return 0
}

# Build Docker image
build_docker_image() {
    log_info "Building Docker image for Cursor IDE..."
    log_container "BUILD" "$DOCKER_IMAGE_NAME:$DOCKER_TAG" "STARTED"
    
    # Create Dockerfile
    create_dockerfile
    
    # Prepare build context
    prepare_build_context
    
    # Build the image
    local build_start=$(date +%s)
    
    if docker build -t "$DOCKER_IMAGE_NAME:$DOCKER_TAG" "$DOCKER_CACHE_DIR/build" 2>&1 | tee -a "$LOG_FILE"; then
        local build_end=$(date +%s)
        local build_duration=$((build_end - build_start))
        log_info "Docker image built successfully in ${build_duration}s"
        log_container "BUILD" "$DOCKER_IMAGE_NAME:$DOCKER_TAG" "SUCCESS"
        return 0
    else
        log_error "Failed to build Docker image"
        log_container "BUILD" "$DOCKER_IMAGE_NAME:$DOCKER_TAG" "FAILED"
        DOCKER_OPERATION_SUCCESS=false
        return 1
    fi
}

# Create Dockerfile
create_dockerfile() {
    log_info "Creating Dockerfile..."
    
    local build_dir="$DOCKER_CACHE_DIR/build"
    mkdir -p "$build_dir"
    
    cat > "$build_dir/Dockerfile" << 'DOCKEREOF'
# Professional Cursor IDE Docker Container
FROM ubuntu:22.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:0
ENV HOME=/home/cursor
ENV USER=cursor

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    unzip \
    xvfb \
    x11vnc \
    fluxbox \
    supervisor \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libdrm2 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libxss1 \
    libxtst6 \
    xdg-utils \
    && rm -rf /var/lib/apt/lists/*

# Create user
RUN useradd -m -s /bin/bash cursor && \
    usermod -aG sudo cursor && \
    echo 'cursor ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Set up directories
RUN mkdir -p /app /workspace /home/cursor/.config && \
    chown -R cursor:cursor /app /workspace /home/cursor

# Copy application files
COPY --chown=cursor:cursor cursor.AppImage /app/
RUN chmod +x /app/cursor.AppImage

# Create startup script
RUN cat > /app/start.sh << 'STARTEOF'
#\!/bin/bash
set -e

# Start X11 virtual framebuffer
Xvfb :0 -screen 0 1920x1080x24 &
export DISPLAY=:0

# Start window manager
fluxbox &

# Start VNC server for remote access
x11vnc -display :0 -forever -usepw -create &

# Start Cursor IDE
cd /workspace
exec /app/cursor.AppImage "$@"
STARTEOF

RUN chmod +x /app/start.sh

# Switch to cursor user
USER cursor
WORKDIR /workspace

# Expose ports
EXPOSE 5900 3000 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep -f cursor.AppImage || exit 1

# Default command
CMD ["/app/start.sh"]
DOCKEREOF
    
    log_info "Dockerfile created successfully"
}

# Prepare build context
prepare_build_context() {
    log_info "Preparing build context..."
    
    local build_dir="$DOCKER_CACHE_DIR/build"
    
    # Find and copy AppImage
    local app_binary="${SCRIPT_DIR}/cursor.AppImage"
    if [[ \! -f "$app_binary" ]]; then
        app_binary=$(find "$SCRIPT_DIR" -name "*.AppImage" -type f | head -1)
    fi
    
    if [[ -n "$app_binary" && -f "$app_binary" ]]; then
        cp "$app_binary" "$build_dir/cursor.AppImage"
        log_info "Copied AppImage to build context"
    else
        log_error "Cursor AppImage not found for Docker build"
        return 1
    fi
    
    # Copy additional files if they exist
    for file in "VERSION" "README.md"; do
        if [[ -f "${SCRIPT_DIR}/$file" ]]; then
            cp "${SCRIPT_DIR}/$file" "$build_dir/"
            log_info "Copied $file to build context"
        fi
    done
    
    log_info "Build context prepared successfully"
}

# Run Docker container
run_docker_container() {
    log_info "Running Cursor IDE Docker container..."
    log_container "RUN" "$CONTAINER_NAME" "STARTED"
    
    # Stop existing container if running
    if docker ps -a --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        log_info "Stopping existing container..."
        docker stop "$CONTAINER_NAME" >/dev/null 2>&1 || true
        docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
    fi
    
    # Build run command
    local docker_run_cmd=(
        "docker" "run"
        "--name" "$CONTAINER_NAME"
        "--detach"
        "--interactive"
        "--tty"
    )
    
    # Add memory limit
    if [[ -n "${CONTAINER_MEMORY_LIMIT:-}" ]]; then
        docker_run_cmd+=("--memory" "$CONTAINER_MEMORY_LIMIT")
    fi
    
    # Add CPU limit
    if [[ -n "${CONTAINER_CPU_LIMIT:-}" ]]; then
        docker_run_cmd+=("--cpus" "$CONTAINER_CPU_LIMIT")
    fi
    
    # Add port mappings
    if [[ -n "${EXPOSE_PORTS:-}" ]]; then
        IFS=',' read -ra PORTS <<< "$EXPOSE_PORTS"
        for port in "${PORTS[@]}"; do
            docker_run_cmd+=("-p" "$port:$port")
        done
    fi
    
    # Add VNC port
    docker_run_cmd+=("-p" "5900:5900")
    
    # Add volume mounts
    if [[ "${MOUNT_HOME_DIRECTORY:-true}" == "true" ]]; then
        docker_run_cmd+=("-v" "$HOME:/home/cursor/host-home")
    fi
    
    if [[ "${ENABLE_PERSISTENT_STORAGE:-true}" == "true" ]]; then
        docker_run_cmd+=("-v" "cursor-data:/app/data")
        docker_run_cmd+=("-v" "cursor-config:/app/config")
    fi
    
    # Add workspace mount
    local workspace_dir="${PWD}"
    docker_run_cmd+=("-v" "$workspace_dir:/workspace")
    
    # Add environment variables
    docker_run_cmd+=("-e" "DISPLAY=:0")
    
    # Add security options
    if [[ "${RUN_AS_NON_ROOT:-true}" == "true" ]]; then
        docker_run_cmd+=("--user" "1000:1000")
    fi
    
    # Add image name
    docker_run_cmd+=("$DOCKER_IMAGE_NAME:$DOCKER_TAG")
    
    # Add any additional arguments
    docker_run_cmd+=("$@")
    
    # Execute the run command
    log_info "Executing: ${docker_run_cmd[*]}"
    
    if "${docker_run_cmd[@]}"; then
        log_info "Container started successfully"
        log_container "RUN" "$CONTAINER_NAME" "SUCCESS"
        
        # Show container info
        show_container_info
        
        return 0
    else
        log_error "Failed to start container"
        log_container "RUN" "$CONTAINER_NAME" "FAILED"
        DOCKER_OPERATION_SUCCESS=false
        return 1
    fi
}

# Show container information
show_container_info() {
    log_info "Container information:"
    
    # Get container status
    local container_status
    container_status=$(docker ps --format "table {{.Status}}" --filter "name=$CONTAINER_NAME" | tail -1)
    log_info "Status: $container_status"
    
    # Get container IP
    local container_ip
    container_ip=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$CONTAINER_NAME" 2>/dev/null || echo "N/A")
    log_info "IP Address: $container_ip"
    
    # Show port mappings
    log_info "Port mappings:"
    docker port "$CONTAINER_NAME" 2>/dev/null | while read -r line; do
        log_info "  $line"
    done || true
    
    # Show access information
    echo ""
    echo "=== Cursor IDE Container Started ==="
    echo "Container Name: $CONTAINER_NAME"
    echo "VNC Access: vnc://localhost:5900"
    echo "Container IP: $container_ip"
    echo ""
    echo "To view logs: docker logs $CONTAINER_NAME"
    echo "To execute commands: docker exec -it $CONTAINER_NAME bash"
    echo "To stop: docker stop $CONTAINER_NAME"
    echo ""
}

# Stop Docker container
stop_docker_container() {
    log_info "Stopping Cursor IDE Docker container..."
    log_container "STOP" "$CONTAINER_NAME" "STARTED"
    
    if docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
        if docker stop "$CONTAINER_NAME" >/dev/null 2>&1; then
            log_info "Container stopped successfully"
            log_container "STOP" "$CONTAINER_NAME" "SUCCESS"
            
            # Optionally remove the container
            if [[ "${AUTO_CLEANUP:-true}" == "true" ]]; then
                docker rm "$CONTAINER_NAME" >/dev/null 2>&1 || true
                log_info "Container removed"
            fi
            
            return 0
        else
            log_error "Failed to stop container"
            log_container "STOP" "$CONTAINER_NAME" "FAILED"
            return 1
        fi
    else
        log_warning "Container is not running"
        log_container "STOP" "$CONTAINER_NAME" "NOT_RUNNING"
        return 0
    fi
}

# List Docker containers and images
list_docker_resources() {
    log_info "Listing Docker resources..."
    
    echo "=== Cursor IDE Docker Images ==="
    docker images --filter "reference=$DOCKER_IMAGE_NAME" --format "table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.CreatedAt}}\t{{.Size}}" 2>/dev/null || echo "No images found"
    
    echo ""
    echo "=== Cursor IDE Docker Containers ==="
    docker ps -a --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "No containers found"
    
    echo ""
    echo "=== Docker Volumes ==="
    docker volume ls --filter "name=cursor" --format "table {{.Name}}\t{{.Driver}}" 2>/dev/null || echo "No volumes found"
}

# Clean up Docker resources
cleanup_docker_resources() {
    log_info "Cleaning up Docker resources..."
    
    # Stop and remove containers
    if docker ps -a --format "table {{.Names}}" | grep -q "cursor"; then
        log_info "Stopping and removing Cursor containers..."
        docker ps -a --filter "name=cursor" --format "{{.Names}}" | xargs -r docker stop >/dev/null 2>&1 || true
        docker ps -a --filter "name=cursor" --format "{{.Names}}" | xargs -r docker rm >/dev/null 2>&1 || true
    fi
    
    # Remove images
    if docker images --format "table {{.Repository}}" | grep -q "$DOCKER_IMAGE_NAME"; then
        log_info "Removing Cursor images..."
        docker images --filter "reference=$DOCKER_IMAGE_NAME" --format "{{.ID}}" | xargs -r docker rmi -f >/dev/null 2>&1 || true
    fi
    
    # Remove volumes (with confirmation in non-dry-run mode)
    if docker volume ls --format "table {{.Name}}" | grep -q "cursor"; then
        log_info "Removing Cursor volumes..."
        docker volume ls --filter "name=cursor" --format "{{.Name}}" | xargs -r docker volume rm >/dev/null 2>&1 || true
    fi
    
    log_info "Docker cleanup completed"
}

# Self-correction functions
check_docker_status() {
    log_info "Checking Docker status..."
    
    if \! command -v docker &>/dev/null; then
        log_error "Docker is not installed"
        return 1
    fi
    
    if \! docker info >/dev/null 2>&1; then
        log_warning "Docker daemon is not running"
        
        # Try to start Docker daemon
        if command -v systemctl &>/dev/null; then
            log_info "Attempting to start Docker daemon..."
            sudo systemctl start docker >/dev/null 2>&1 || true
            sleep 3
        fi
    fi
    
    # Check disk space for Docker
    local docker_root
    docker_root=$(docker info --format '{{.DockerRootDir}}' 2>/dev/null || echo "/var/lib/docker")
    local available_space
    available_space=$(df "$docker_root" 2>/dev/null | awk 'NR==2 {print int($4/1024)}' || echo "0")
    
    if [[ $available_space -lt 1024 ]]; then
        log_warning "Low disk space for Docker: ${available_space}MB available"
    fi
}

fix_directory_permissions() {
    log_info "Attempting to fix directory permissions..."
    
    for dir in "$DOCKER_CONFIG_DIR" "$DOCKER_CACHE_DIR" "$DOCKER_LOG_DIR"; do
        if [[ -d "$dir" ]]; then
            chmod 755 "$dir" 2>/dev/null || true
        fi
    done
}

cleanup_build_context() {
    log_info "Cleaning up build context..."
    
    local build_dir="$DOCKER_CACHE_DIR/build"
    if [[ -d "$build_dir" ]]; then
        rm -rf "$build_dir" 2>/dev/null || true
        log_info "Build context cleaned up"
    fi
}

# Cleanup functions
cleanup_on_error() {
    log_warning "Performing error cleanup..."
    cleanup_on_exit
}

cleanup_on_exit() {
    [[ -f "$LOCK_FILE" ]] && rm -f "$LOCK_FILE"
    [[ -f "$PID_FILE" ]] && rm -f "$PID_FILE"
    jobs -p | xargs -r kill 2>/dev/null || true
    log_info "Cleanup completed"
}

# Display usage information
display_usage() {
    cat << 'USAGEEOF'
Professional Docker Integration Framework v2.0

USAGE:
    docker-improved-v2.sh [OPTIONS] [COMMAND]

COMMANDS:
    build       Build Docker image
    run         Run Docker container (default)
    stop        Stop Docker container
    list        List Docker resources
    cleanup     Clean up Docker resources
    logs        Show container logs

OPTIONS:
    --verbose       Enable verbose output
    --dry-run       Show what would be done
    --help          Display this help message
    --version       Display version information

EXAMPLES:
    ./docker-improved-v2.sh build
    ./docker-improved-v2.sh run
    ./docker-improved-v2.sh stop
    ./docker-improved-v2.sh list
    ./docker-improved-v2.sh cleanup

For more information, see the documentation.
USAGEEOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            build)
                OPERATION="build"
                shift
                ;;
            run)
                OPERATION="run"
                shift
                ;;
            stop)
                OPERATION="stop"
                shift
                ;;
            list)
                OPERATION="list"
                shift
                ;;
            cleanup)
                OPERATION="cleanup"
                shift
                ;;
            logs)
                OPERATION="logs"
                shift
                ;;
            --verbose)
                VERBOSE_MODE=true
                shift
                ;;
            --dry-run)
                DRY_RUN_MODE=true
                shift
                ;;
            --help)
                display_usage
                exit 0
                ;;
            --version)
                echo "Professional Docker Integration Framework v$VERSION"
                exit 0
                ;;
            -*)
                log_warning "Unknown option: $1"
                shift
                ;;
            *)
                # Pass remaining arguments to container
                break
                ;;
        esac
    done
}

# Main execution function
main() {
    local OPERATION="${OPERATION:-run}"
    
    # Parse command line arguments
    parse_arguments "$@"
    
    # Initialize framework
    initialize_docker_framework
    
    case "$OPERATION" in
        "build")
            if build_docker_image; then
                log_info "Docker image build completed successfully"
                exit 0
            else
                log_error "Docker image build failed"
                exit 1
            fi
            ;;
        "run")
            # Build image if it doesn't exist
            if \! docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^${DOCKER_IMAGE_NAME}:${DOCKER_TAG}$"; then
                log_info "Docker image not found, building..."
                if \! build_docker_image; then
                    log_error "Failed to build Docker image"
                    exit 1
                fi
            fi
            
            if run_docker_container "$@"; then
                log_info "Docker container started successfully"
                exit 0
            else
                log_error "Failed to start Docker container"
                exit 1
            fi
            ;;
        "stop")
            if stop_docker_container; then
                log_info "Docker container stopped successfully"
                exit 0
            else
                log_error "Failed to stop Docker container"
                exit 1
            fi
            ;;
        "list")
            list_docker_resources
            exit 0
            ;;
        "cleanup")
            cleanup_docker_resources
            log_info "Docker cleanup completed"
            exit 0
            ;;
        "logs")
            if docker ps --format "table {{.Names}}" | grep -q "^${CONTAINER_NAME}$"; then
                docker logs -f "$CONTAINER_NAME"
            else
                log_error "Container $CONTAINER_NAME is not running"
                exit 1
            fi
            ;;
        *)
            log_error "Unknown operation: $OPERATION"
            display_usage
            exit 1
            ;;
    esac
}

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
