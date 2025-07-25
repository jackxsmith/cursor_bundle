#!/usr/bin/env bash

# =============================================================================
# CURSOR IDE ENTERPRISE DOCKER ORCHESTRATION FRAMEWORK
# Version: 6.9.223
# Description: Advanced containerized deployment system for Cursor IDE
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
readonly SCRIPT_VERSION="6.9.223"
readonly CURSOR_VERSION="6.9.35"
readonly TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"

# Directory structure
readonly BASE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/cursor-docker"
readonly LOG_DIR="$BASE_DIR/logs"
readonly CONFIG_DIR="$BASE_DIR/config"
readonly CACHE_DIR="$BASE_DIR/cache"
readonly VOLUMES_DIR="$BASE_DIR/volumes"
readonly BACKUP_DIR="$BASE_DIR/backup"
readonly COMPOSE_DIR="$BASE_DIR/compose"

# Docker configuration
readonly DOCKER_NAMESPACE="cursor-enterprise"
readonly NETWORK_NAME="cursor-network"
readonly VOLUME_PREFIX="cursor-vol"

# Container configurations
declare -A CONTAINER_CONFIGS=(
    ["base"]="Basic Cursor IDE container"
    ["dev"]="Development environment with tools"
    ["enterprise"]="Enterprise edition with extensions"
    ["cluster"]="Multi-node cluster deployment"
    ["gpu"]="GPU-accelerated container"
)

# Service ports
declare -A SERVICE_PORTS=(
    ["vnc"]=5900
    ["web_ui"]=8080
    ["ssh"]=2222
    ["api"]=3000
    ["metrics"]=9090
    ["health"]=8081
)

# Log files
readonly MAIN_LOG="$LOG_DIR/docker-${TIMESTAMP}.log"
readonly ERROR_LOG="$LOG_DIR/docker-error-${TIMESTAMP}.log"
readonly AUDIT_LOG="$LOG_DIR/docker-audit-${TIMESTAMP}.log"
readonly PERFORMANCE_LOG="$LOG_DIR/docker-performance-${TIMESTAMP}.log"

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

# Global variables
declare -g CONTAINER_TYPE="base"
declare -g ENABLE_GPU=false
declare -g ENABLE_CLUSTERING=false
declare -g PERSISTENT_STORAGE=true
declare -g ENABLE_MONITORING=false
declare -g DRY_RUN=false
declare -g FORCE_REBUILD=false
declare -g PRODUCTION_MODE=false

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

performance_log() {
    local operation="$1"
    local duration="$2"
    local details="${3:-}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] OPERATION=$operation DURATION=${duration}ms DETAILS=$details" >> "$PERFORMANCE_LOG" 2>/dev/null || true
}

cleanup() {
    local exit_code=$?
    log "INFO" "Performing cleanup operations..."
    
    if [[ $exit_code -eq 0 ]]; then
        log "SUCCESS" "Docker operations completed successfully"
    else
        log "ERROR" "Docker operations failed with exit code: $exit_code"
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
        "$VOLUMES_DIR" "$BACKUP_DIR" "$COMPOSE_DIR"
    )
    
    for dir in "${directories[@]}"; do
        if [[ "$DRY_RUN" == "true" ]]; then
            log "DEBUG" "DRY RUN: Would create directory: $dir"
        else
            mkdir -p "$dir" || {
                log "ERROR" "Failed to create directory: $dir"
                return 1
            }
        fi
    done
    
    log "SUCCESS" "Directory structure created successfully"
    return 0
}

check_docker_availability() {
    log "INFO" "Checking Docker availability..."
    
    local docker_issues=0
    
    # Check if Docker is installed
    if ! command -v docker >/dev/null 2>&1; then
        log "ERROR" "Docker is not installed"
        log "ERROR" "Please install Docker: https://docs.docker.com/get-docker/"
        ((docker_issues++))
    else
        local docker_version=$(docker --version | cut -d' ' -f3 | tr -d ',')
        log "DEBUG" "Docker version: $docker_version"
    fi
    
    # Check if Docker daemon is running
    if ! docker info >/dev/null 2>&1; then
        log "ERROR" "Docker daemon is not running"
        log "ERROR" "Please start Docker daemon"
        ((docker_issues++))
    else
        log "DEBUG" "Docker daemon is running"
    fi
    
    # Check Docker Compose availability
    if command -v docker-compose >/dev/null 2>&1; then
        local compose_version=$(docker-compose --version | cut -d' ' -f3 | tr -d ',')
        log "DEBUG" "Docker Compose version: $compose_version"
    elif docker compose version >/dev/null 2>&1; then
        log "DEBUG" "Docker Compose plugin available"
    else
        log "WARN" "Docker Compose not available - some features may be limited"
        ((docker_issues++))
    fi
    
    # Check system resources
    local total_memory=$(free -m | awk '/^Mem:/ {print $2}')
    if [[ $total_memory -lt 4096 ]]; then
        log "WARN" "Low system memory: ${total_memory}MB (recommended: 4GB+)"
    fi
    
    local available_disk=$(df "$BASE_DIR" 2>/dev/null | awk 'NR==2 {print $4}' || df / | awk 'NR==2 {print $4}')
    if [[ $available_disk -lt 10485760 ]]; then  # 10GB in KB
        log "WARN" "Low disk space: $((available_disk / 1024 / 1024))GB (recommended: 10GB+)"
    fi
    
    if [[ $docker_issues -eq 0 ]]; then
        log "SUCCESS" "Docker environment validated successfully"
        return 0
    else
        log "ERROR" "Docker environment validation failed ($docker_issues issues)"
        return 1
    fi
}

initialize_docker_network() {
    log "INFO" "Initializing Docker network..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "DEBUG" "DRY RUN: Would create Docker network: $NETWORK_NAME"
        return 0
    fi
    
    # Check if network already exists
    if docker network ls | grep -q "$NETWORK_NAME"; then
        log "DEBUG" "Docker network '$NETWORK_NAME' already exists"
        return 0
    fi
    
    # Create custom bridge network
    if docker network create \
        --driver bridge \
        --subnet=172.20.0.0/16 \
        --ip-range=172.20.240.0/20 \
        --gateway=172.20.0.1 \
        --opt com.docker.network.bridge.name=cursor-br0 \
        --label "project=cursor-enterprise" \
        "$NETWORK_NAME"; then
        log "SUCCESS" "Docker network '$NETWORK_NAME' created successfully"
        audit_log "NETWORK_CREATED" "Network: $NETWORK_NAME" "SUCCESS"
        return 0
    else
        log "ERROR" "Failed to create Docker network"
        return 1
    fi
}

# =============================================================================
# DOCKERFILE GENERATION FUNCTIONS
# =============================================================================

generate_base_dockerfile() {
    log "INFO" "Generating base Dockerfile..."
    
    cat > "$COMPOSE_DIR/Dockerfile.base" << 'EOF'
# Cursor IDE Enterprise Base Container
FROM ubuntu:22.04

LABEL maintainer="Enterprise Development Team"
LABEL version="6.9.223"
LABEL description="Cursor IDE Enterprise Base Container"

# Prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # Core system packages
    curl wget git vim nano htop \
    build-essential cmake \
    # X11 and desktop environment
    xvfb x11vnc fluxbox \
    # Audio support
    pulseaudio pulseaudio-utils \
    # Graphics and fonts
    fonts-liberation fonts-dejavu-core \
    # AppImage support
    fuse libfuse2 \
    # Additional utilities
    supervisor nginx \
    # Cleanup
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create application user
RUN useradd -m -s /bin/bash -G audio,video cursor && \
    echo 'cursor:cursor' | chpasswd

# Create directories
RUN mkdir -p /opt/cursor /home/cursor/.config /var/log/supervisor

# Download and install Cursor AppImage
RUN curl -fsSL https://api.cursor.com/releases/6.9.35/cursor.AppImage -o /opt/cursor/cursor.AppImage && \
    chmod +x /opt/cursor/cursor.AppImage && \
    ln -sf /opt/cursor/cursor.AppImage /usr/local/bin/cursor

# Copy configuration files
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY start-vnc.sh /usr/local/bin/start-vnc.sh
COPY nginx.conf /etc/nginx/sites-available/default

# Set permissions
RUN chmod +x /usr/local/bin/start-vnc.sh && \
    chown -R cursor:cursor /home/cursor

# Create startup script
RUN cat > /usr/local/bin/entrypoint.sh << 'ENTRYPOINT'
#!/bin/bash
set -e

# Start VNC server
su - cursor -c "export DISPLAY=:1 && Xvfb :1 -screen 0 1920x1080x24 &"
sleep 2
su - cursor -c "export DISPLAY=:1 && fluxbox &"
su - cursor -c "export DISPLAY=:1 && x11vnc -display :1 -forever -usepw -create -shared -rfbport 5900 &"

# Start Cursor IDE
su - cursor -c "export DISPLAY=:1 && cursor --no-sandbox &"

# Keep container running
exec "$@"
ENTRYPOINT

RUN chmod +x /usr/local/bin/entrypoint.sh

# Expose ports
EXPOSE 5900 8080 2222 3000

# Set working directory
WORKDIR /home/cursor

# Switch to application user
USER cursor

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Default command
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
EOF
    
    log "SUCCESS" "Base Dockerfile generated"
}

generate_development_dockerfile() {
    log "INFO" "Generating development Dockerfile..."
    
    cat > "$COMPOSE_DIR/Dockerfile.dev" << 'EOF'
# Cursor IDE Enterprise Development Container
FROM cursor-enterprise:base

LABEL description="Cursor IDE Development Environment"

# Switch to root for installations
USER root

# Install development tools
RUN apt-get update && apt-get install -y \
    # Programming languages
    nodejs npm python3 python3-pip \
    golang-go openjdk-11-jdk \
    # Database tools
    postgresql-client mysql-client redis-tools \
    # DevOps tools
    docker.io kubectl helm \
    # Additional development utilities
    jq yq tree fd-find ripgrep \
    # Cleanup
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install global npm packages
RUN npm install -g \
    typescript ts-node \
    @angular/cli @vue/cli create-react-app \
    prettier eslint

# Install Python packages
RUN pip3 install \
    pytest black flake8 mypy \
    django flask fastapi \
    pandas numpy jupyter

# Install Go tools
RUN go install golang.org/x/tools/cmd/goimports@latest && \
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

# Create development workspace
RUN mkdir -p /workspace /home/cursor/.vscode-server
RUN chown -R cursor:cursor /workspace /home/cursor/.vscode-server

# Copy development configuration
COPY dev-config/ /home/cursor/.config/
RUN chown -R cursor:cursor /home/cursor/.config/

# Switch back to application user
USER cursor

# Set development working directory
WORKDIR /workspace

# Development-specific health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -f http://localhost:8080/health && \
        command -v node && command -v python3 && command -v go || exit 1
EOF
    
    log "SUCCESS" "Development Dockerfile generated"
}

generate_enterprise_dockerfile() {
    log "INFO" "Generating enterprise Dockerfile..."
    
    cat > "$COMPOSE_DIR/Dockerfile.enterprise" << 'EOF'
# Cursor IDE Enterprise Edition Container
FROM cursor-enterprise:dev

LABEL description="Cursor IDE Enterprise Edition with Extensions"

# Switch to root for installations
USER root

# Install enterprise security tools
RUN apt-get update && apt-get install -y \
    # Security scanning
    clamav clamav-daemon \
    # Monitoring
    prometheus-node-exporter \
    # Logging
    rsyslog logrotate \
    # Network tools
    netcat-openbsd tcpdump wireshark-common \
    # System monitoring
    sysstat iotop nethogs \
    # Cleanup
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Configure ClamAV
RUN mkdir -p /var/lib/clamav && \
    chown clamav:clamav /var/lib/clamav && \
    freshclam || true

# Install enterprise extensions
RUN mkdir -p /opt/cursor/extensions && \
    curl -fsSL https://marketplace.visualstudio.com/_apis/public/gallery/publishers/ms-vscode/vsextensions/vscode-eslint/latest/vspackage \
         -o /tmp/eslint.vsix && \
    cursor --install-extension /tmp/eslint.vsix || true

# Configure monitoring
COPY monitoring/ /opt/monitoring/
RUN chown -R cursor:cursor /opt/monitoring/

# Enterprise logging configuration
COPY enterprise-logging.conf /etc/rsyslog.d/50-cursor.conf

# Security hardening
RUN echo "cursor ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/cursor && \
    chmod 440 /etc/sudoers.d/cursor

# Create enterprise directories
RUN mkdir -p /opt/cursor/enterprise/{logs,config,cache,reports} && \
    chown -R cursor:cursor /opt/cursor/enterprise

# Switch back to application user
USER cursor

# Enterprise health check with security validation
HEALTHCHECK --interval=60s --timeout=15s --start-period=120s --retries=5 \
    CMD curl -f http://localhost:8080/health && \
        curl -f http://localhost:9090/metrics && \
        ps aux | grep -q cursor || exit 1

# Enterprise-specific volumes
VOLUME ["/opt/cursor/enterprise", "/workspace", "/home/cursor/.config"]
EOF
    
    log "SUCCESS" "Enterprise Dockerfile generated"
}

# =============================================================================
# DOCKER COMPOSE GENERATION FUNCTIONS
# =============================================================================

generate_docker_compose() {
    log "INFO" "Generating Docker Compose configuration..."
    
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
    hostname: cursor-base
    networks:
      - cursor-network
    ports:
      - "${SERVICE_PORTS[vnc]}:5900"
      - "${SERVICE_PORTS[web_ui]}:8080"
    volumes:
      - cursor-data:/home/cursor/.local/share/cursor
      - cursor-config:/home/cursor/.config
      - /tmp/.X11-unix:/tmp/.X11-unix:rw
    environment:
      - DISPLAY=:1
      - CURSOR_VERSION=${CURSOR_VERSION}
      - CONTAINER_TYPE=base
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    labels:
      - traefik.enable=true
      - traefik.http.routers.cursor.rule=Host(\`cursor.local\`)
      - traefik.http.services.cursor.loadbalancer.server.port=8080

  cursor-dev:
    build:
      context: .
      dockerfile: Dockerfile.dev
    image: ${DOCKER_NAMESPACE}:dev
    container_name: cursor-dev
    hostname: cursor-dev
    networks:
      - cursor-network
    ports:
      - "${SERVICE_PORTS[vnc]}:5900"
      - "${SERVICE_PORTS[web_ui]}:8080"
      - "${SERVICE_PORTS[ssh]}:22"
    volumes:
      - cursor-data:/home/cursor/.local/share/cursor
      - cursor-config:/home/cursor/.config
      - cursor-workspace:/workspace
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - DISPLAY=:1
      - CURSOR_VERSION=${CURSOR_VERSION}
      - CONTAINER_TYPE=dev
      - NODE_ENV=development
    restart: unless-stopped
    depends_on:
      - cursor-base
    profiles:
      - dev

  cursor-enterprise:
    build:
      context: .
      dockerfile: Dockerfile.enterprise
    image: ${DOCKER_NAMESPACE}:enterprise
    container_name: cursor-enterprise
    hostname: cursor-enterprise
    networks:
      - cursor-network
    ports:
      - "${SERVICE_PORTS[vnc]}:5900"
      - "${SERVICE_PORTS[web_ui]}:8080"
      - "${SERVICE_PORTS[ssh]}:22"
      - "${SERVICE_PORTS[api]}:3000"
      - "${SERVICE_PORTS[metrics]}:9090"
    volumes:
      - cursor-data:/home/cursor/.local/share/cursor
      - cursor-config:/home/cursor/.config
      - cursor-workspace:/workspace
      - ./enterprise-config:/opt/cursor/enterprise/config:ro
      - ./logs:/opt/cursor/enterprise/logs
    environment:
      - DISPLAY=:1
      - CURSOR_VERSION=${CURSOR_VERSION}
      - CONTAINER_TYPE=enterprise
      - MONITORING_ENABLED=true
      - SECURITY_SCANNING=true
    restart: unless-stopped
    depends_on:
      - cursor-dev
    profiles:
      - enterprise

$(if [[ "$ENABLE_MONITORING" == "true" ]]; then
cat << 'MONITORING'
  prometheus:
    image: prom/prometheus:latest
    container_name: cursor-prometheus
    hostname: prometheus
    networks:
      - cursor-network
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=200h'
      - '--web.enable-lifecycle'
    restart: unless-stopped
    profiles:
      - monitoring

  grafana:
    image: grafana/grafana:latest
    container_name: cursor-grafana
    hostname: grafana
    networks:
      - cursor-network
    ports:
      - "3001:3000"
    volumes:
      - grafana-data:/var/lib/grafana
      - ./monitoring/grafana-datasources.yml:/etc/grafana/provisioning/datasources/datasources.yml:ro
      - ./monitoring/grafana-dashboards.yml:/etc/grafana/provisioning/dashboards/dashboards.yml:ro
      - ./monitoring/dashboards:/var/lib/grafana/dashboards:ro
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_USERS_ALLOW_SIGN_UP=false
    restart: unless-stopped
    profiles:
      - monitoring
MONITORING
fi)

$(if [[ "$ENABLE_MONITORING" == "true" ]]; then
cat << 'VOLUMES'
volumes:
  prometheus-data:
    name: ${VOLUME_PREFIX}-prometheus
  grafana-data:
    name: ${VOLUME_PREFIX}-grafana
VOLUMES
fi)
EOF
    
    log "SUCCESS" "Docker Compose configuration generated"
}

generate_support_files() {
    log "INFO" "Generating support configuration files..."
    
    # Supervisor configuration
    cat > "$COMPOSE_DIR/supervisord.conf" << 'EOF'
[supervisord]
nodaemon=true
logfile=/var/log/supervisor/supervisord.log
pidfile=/var/run/supervisord.pid

[program:xvfb]
command=Xvfb :1 -screen 0 1920x1080x24
autorestart=true
user=cursor

[program:fluxbox]
command=fluxbox
environment=DISPLAY=:1
autorestart=true
user=cursor

[program:vnc]
command=x11vnc -display :1 -forever -usepw -create -shared -rfbport 5900
autorestart=true
user=cursor

[program:nginx]
command=nginx -g "daemon off;"
autorestart=true
EOF
    
    # VNC startup script
    cat > "$COMPOSE_DIR/start-vnc.sh" << 'EOF'
#!/bin/bash
set -e

export DISPLAY=:1

# Start Xvfb
Xvfb :1 -screen 0 1920x1080x24 &
sleep 2

# Start window manager
fluxbox &

# Set VNC password
mkdir -p ~/.vnc
echo "cursor" | vncpasswd -f > ~/.vnc/passwd
chmod 600 ~/.vnv/passwd

# Start VNC server
x11vnc -display :1 -forever -usepw -create -shared -rfbport 5900 &

# Start Cursor IDE
cursor --no-sandbox &

wait
EOF
    
    # Nginx configuration
    cat > "$COMPOSE_DIR/nginx.conf" << 'EOF'
server {
    listen 8080;
    server_name localhost;
    
    location / {
        proxy_pass http://localhost:5900;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF
    
    log "SUCCESS" "Support configuration files generated"
}

# =============================================================================
# CONTAINER MANAGEMENT FUNCTIONS
# =============================================================================

build_containers() {
    log "INFO" "Building Cursor IDE containers..."
    
    local build_start=$(date +%s%3N)
    local containers_built=0
    
    # Generate all required files
    generate_base_dockerfile
    generate_development_dockerfile
    generate_enterprise_dockerfile
    generate_docker_compose
    generate_support_files
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would build containers for type: $CONTAINER_TYPE"
        return 0
    fi
    
    cd "$COMPOSE_DIR" || {
        log "ERROR" "Failed to change to compose directory"
        return 1
    }
    
    # Build based on container type
    case "$CONTAINER_TYPE" in
        "base")
            log "INFO" "Building base container..."
            if docker build -f Dockerfile.base -t "${DOCKER_NAMESPACE}:base" .; then
                ((containers_built++))
                log "SUCCESS" "Base container built successfully"
            else
                log "ERROR" "Failed to build base container"
                return 1
            fi
            ;;
        "dev")
            log "INFO" "Building development containers..."
            if docker build -f Dockerfile.base -t "${DOCKER_NAMESPACE}:base" . && \
               docker build -f Dockerfile.dev -t "${DOCKER_NAMESPACE}:dev" .; then
                containers_built=2
                log "SUCCESS" "Development containers built successfully"
            else
                log "ERROR" "Failed to build development containers"
                return 1
            fi
            ;;
        "enterprise")
            log "INFO" "Building enterprise containers..."
            if docker build -f Dockerfile.base -t "${DOCKER_NAMESPACE}:base" . && \
               docker build -f Dockerfile.dev -t "${DOCKER_NAMESPACE}:dev" . && \
               docker build -f Dockerfile.enterprise -t "${DOCKER_NAMESPACE}:enterprise" .; then
                containers_built=3
                log "SUCCESS" "Enterprise containers built successfully"
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
    
    local build_end=$(date +%s%3N)
    local duration=$((build_end - build_start))
    performance_log "container_build" "$duration" "Built: $containers_built containers"
    
    log "SUCCESS" "Container build completed successfully"
    audit_log "CONTAINERS_BUILT" "Type: $CONTAINER_TYPE, Count: $containers_built" "SUCCESS"
    
    return 0
}

start_services() {
    log "INFO" "Starting Cursor IDE services..."
    
    local start_time=$(date +%s%3N)
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would start services for type: $CONTAINER_TYPE"
        return 0
    fi
    
    cd "$COMPOSE_DIR" || {
        log "ERROR" "Failed to change to compose directory"
        return 1
    }
    
    # Start services based on container type
    local compose_profiles=""
    case "$CONTAINER_TYPE" in
        "base")
            compose_profiles=""
            ;;
        "dev")
            compose_profiles="--profile dev"
            ;;
        "enterprise")
            compose_profiles="--profile enterprise"
            ;;
    esac
    
    # Add monitoring profile if enabled
    if [[ "$ENABLE_MONITORING" == "true" ]]; then
        compose_profiles="$compose_profiles --profile monitoring"
    fi
    
    # Start services
    if docker-compose $compose_profiles up -d; then
        log "SUCCESS" "Services started successfully"
        
        # Display service information
        show_service_status
        
        local end_time=$(date +%s%3N)
        local duration=$((end_time - start_time))
        performance_log "service_start" "$duration" "Type: $CONTAINER_TYPE"
        
        audit_log "SERVICES_STARTED" "Type: $CONTAINER_TYPE" "SUCCESS"
        return 0
    else
        log "ERROR" "Failed to start services"
        return 1
    fi
}

stop_services() {
    log "INFO" "Stopping Cursor IDE services..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would stop all services"
        return 0
    fi
    
    cd "$COMPOSE_DIR" || {
        log "ERROR" "Failed to change to compose directory"
        return 1
    }
    
    if docker-compose down; then
        log "SUCCESS" "Services stopped successfully"
        audit_log "SERVICES_STOPPED" "All services stopped" "SUCCESS"
        return 0
    else
        log "ERROR" "Failed to stop services"
        return 1
    fi
}

show_service_status() {
    log "INFO" "Service Status Overview:"
    echo
    
    # Show running containers
    echo -e "${BOLD}Running Containers:${NC}"
    docker ps --filter "label=com.docker.compose.project=cursor-docker" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo
    
    # Show service URLs
    echo -e "${BOLD}Service Access URLs:${NC}"
    if docker ps | grep -q "cursor-"; then
        echo "  VNC Access:     vnc://localhost:${SERVICE_PORTS[vnc]}"
        echo "  Web Interface:  http://localhost:${SERVICE_PORTS[web_ui]}"
        
        if [[ "$CONTAINER_TYPE" == "dev" ]] || [[ "$CONTAINER_TYPE" == "enterprise" ]]; then
            echo "  SSH Access:     ssh cursor@localhost -p ${SERVICE_PORTS[ssh]}"
        fi
        
        if [[ "$CONTAINER_TYPE" == "enterprise" ]]; then
            echo "  API Endpoint:   http://localhost:${SERVICE_PORTS[api]}"
            echo "  Metrics:        http://localhost:${SERVICE_PORTS[metrics]}"
        fi
        
        if [[ "$ENABLE_MONITORING" == "true" ]]; then
            echo "  Prometheus:     http://localhost:9090"
            echo "  Grafana:        http://localhost:3001"
        fi
    fi
    echo
    
    # Show helpful commands
    echo -e "${BOLD}Useful Commands:${NC}"
    echo "  Shell Access:   docker exec -it cursor-${CONTAINER_TYPE} bash"
    echo "  View Logs:      docker-compose logs -f cursor-${CONTAINER_TYPE}"
    echo "  Restart:        docker-compose restart cursor-${CONTAINER_TYPE}"
    echo
}

# =============================================================================
# BACKUP AND RESTORE FUNCTIONS
# =============================================================================

backup_containers() {
    log "INFO" "Creating container backup..."
    
    local backup_start=$(date +%s%3N)
    local backup_name="cursor-backup-${TIMESTAMP}"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would create backup: $backup_name"
        return 0
    fi
    
    # Create backup directory
    local backup_path="$BACKUP_DIR/$backup_name"
    mkdir -p "$backup_path"
    
    # Export container images
    local images=(
        "${DOCKER_NAMESPACE}:base"
        "${DOCKER_NAMESPACE}:dev"
        "${DOCKER_NAMESPACE}:enterprise"
    )
    
    for image in "${images[@]}"; do
        if docker images | grep -q "$image"; then
            local image_file="${image//[:\\/]/-}.tar"
            log "INFO" "Exporting image: $image"
            if docker save "$image" -o "$backup_path/$image_file"; then
                log "DEBUG" "Image exported: $image_file"
            else
                log "WARN" "Failed to export image: $image"
            fi
        fi
    done
    
    # Backup volumes
    local volumes=(
        "${VOLUME_PREFIX}-data"
        "${VOLUME_PREFIX}-config"
        "${VOLUME_PREFIX}-workspace"
    )
    
    for volume in "${volumes[@]}"; do
        if docker volume ls | grep -q "$volume"; then
            log "INFO" "Backing up volume: $volume"
            docker run --rm \
                -v "$volume:/source:ro" \
                -v "$backup_path:/backup" \
                busybox tar czf "/backup/${volume}.tar.gz" -C /source .
        fi
    done
    
    # Backup compose configuration
    cp -r "$COMPOSE_DIR" "$backup_path/compose"
    
    # Create backup manifest
    cat > "$backup_path/MANIFEST" << EOF
# Cursor IDE Docker Backup Manifest
Created: $(date)
Version: $SCRIPT_VERSION
Container Type: $CONTAINER_TYPE
Backup Path: $backup_path

Images:
$(docker images --filter "reference=${DOCKER_NAMESPACE}:*" --format "{{.Repository}}:{{.Tag}} {{.Size}}")

Volumes:
$(docker volume ls --filter "name=${VOLUME_PREFIX}-*" --format "{{.Name}}")
EOF
    
    local backup_end=$(date +%s%3N)
    local duration=$((backup_end - backup_start))
    performance_log "container_backup" "$duration" "Backup: $backup_name"
    
    log "SUCCESS" "Backup created successfully: $backup_path"
    audit_log "BACKUP_CREATED" "Path: $backup_path" "SUCCESS"
    
    return 0
}

restore_containers() {
    local backup_path="$1"
    
    if [[ -z "$backup_path" ]] || [[ ! -d "$backup_path" ]]; then
        log "ERROR" "Invalid backup path: $backup_path"
        return 1
    fi
    
    log "INFO" "Restoring containers from backup: $backup_path"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "INFO" "DRY RUN: Would restore from backup: $backup_path"
        return 0
    fi
    
    # Stop existing services
    stop_services
    
    # Load container images
    for image_file in "$backup_path"/*.tar; do
        if [[ -f "$image_file" ]]; then
            log "INFO" "Loading image: $(basename "$image_file")"
            docker load -i "$image_file"
        fi
    done
    
    # Restore volumes
    for volume_file in "$backup_path"/*.tar.gz; do
        if [[ -f "$volume_file" ]]; then
            local volume_name=$(basename "$volume_file" .tar.gz)
            log "INFO" "Restoring volume: $volume_name"
            
            # Create volume if it doesn't exist
            docker volume create "$volume_name" || true
            
            # Restore data
            docker run --rm \
                -v "$volume_name:/target" \
                -v "$backup_path:/backup:ro" \
                busybox tar xzf "/backup/$(basename "$volume_file")" -C /target
        fi
    done
    
    # Restore compose configuration
    if [[ -d "$backup_path/compose" ]]; then
        cp -r "$backup_path/compose/"* "$COMPOSE_DIR/"
    fi
    
    log "SUCCESS" "Container restore completed successfully"
    audit_log "CONTAINERS_RESTORED" "Source: $backup_path" "SUCCESS"
    
    return 0
}

# =============================================================================
# MONITORING AND DIAGNOSTICS
# =============================================================================

show_system_diagnostics() {
    log "INFO" "System Diagnostics Report"
    echo
    
    # Docker system information
    echo -e "${BOLD}Docker System Info:${NC}"
    docker system df
    echo
    
    # Container resource usage
    echo -e "${BOLD}Container Resource Usage:${NC}"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}"
    echo
    
    # Network information
    echo -e "${BOLD}Docker Networks:${NC}"
    docker network ls --filter "name=cursor"
    echo
    
    # Volume information
    echo -e "${BOLD}Docker Volumes:${NC}"
    docker volume ls --filter "name=${VOLUME_PREFIX}"
    echo
    
    # Container logs summary
    echo -e "${BOLD}Recent Container Logs:${NC}"
    for container in $(docker ps --filter "label=com.docker.compose.project=cursor-docker" --format "{{.Names}}"); do
        echo "--- $container ---"
        docker logs --tail 5 "$container" 2>&1 | head -10
        echo
    done
}

run_health_checks() {
    log "INFO" "Running comprehensive health checks..."
    
    local health_issues=0
    
    # Check container health
    for container in $(docker ps --filter "label=com.docker.compose.project=cursor-docker" --format "{{.Names}}"); do
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
    
    # Check disk space
    local available_space=$(df "$BASE_DIR" | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 1048576 ]]; then  # 1GB
        log "WARN" "Low disk space: $((available_space / 1024))MB"
        ((health_issues++))
    fi
    
    if [[ $health_issues -eq 0 ]]; then
        log "SUCCESS" "All health checks passed"
        return 0
    else
        log "WARN" "Health checks completed with $health_issues issues"
        return 1
    fi
}

# =============================================================================
# MAIN EXECUTION FUNCTIONS
# =============================================================================

show_usage() {
    cat << EOF
Cursor IDE Enterprise Docker Orchestration Framework v$SCRIPT_VERSION

USAGE:
    $SCRIPT_NAME [COMMAND] [OPTIONS]

COMMANDS:
    build               Build container images
    start, up           Start services
    stop, down          Stop services
    restart             Restart services
    status              Show service status
    logs                Show service logs
    shell               Open container shell
    backup              Create backup
    restore             Restore from backup
    health              Run health checks
    diagnostics         Show system diagnostics
    cleanup             Clean up unused resources

OPTIONS:
    -h, --help          Show this help message
    -v, --version       Show version information
    -t, --type TYPE     Container type: base, dev, enterprise (default: base)
    -n, --dry-run       Perform dry run without making changes
    -f, --force         Force rebuild containers
    -m, --monitoring    Enable monitoring stack
    -g, --gpu           Enable GPU support
    -p, --production    Production mode settings
    -q, --quiet         Quiet mode (minimal output)

CONTAINER TYPES:
$(for type in "${!CONTAINER_CONFIGS[@]}"; do
    printf "    %-12s %s\n" "$type" "${CONTAINER_CONFIGS[$type]}"
done)

EXAMPLES:
    $SCRIPT_NAME build --type enterprise    # Build enterprise containers
    $SCRIPT_NAME start --monitoring         # Start with monitoring
    $SCRIPT_NAME shell cursor-dev           # Open development shell
    $SCRIPT_NAME backup                     # Create backup
    $SCRIPT_NAME diagnostics                # Show system diagnostics

SERVICE PORTS:
$(for service in "${!SERVICE_PORTS[@]}"; do
    printf "    %-12s %s\n" "$service" "${SERVICE_PORTS[$service]}"
done)

For more information, visit: https://cursor.sh/docs/docker
EOF
}

show_version() {
    cat << EOF
Cursor IDE Enterprise Docker Orchestration Framework
Version: $SCRIPT_VERSION
Cursor Version: $CURSOR_VERSION
Build Date: $(date '+%Y-%m-%d')
Platform: $(uname -s) $(uname -m)

Docker Support:
$(docker --version 2>/dev/null || echo "Docker not available")
$(docker-compose --version 2>/dev/null || echo "Docker Compose not available")

Copyright (c) 2024 Enterprise Development Team
Licensed under MIT License
EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -v|--version)
                show_version
                exit 0
                ;;
            -t|--type)
                if [[ -n "$2" ]] && [[ -n "${CONTAINER_CONFIGS[$2]}" ]]; then
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
            -m|--monitoring)
                ENABLE_MONITORING=true
                ;;
            -g|--gpu)
                ENABLE_GPU=true
                ;;
            -p|--production)
                PRODUCTION_MODE=true
                ;;
            -q|--quiet)
                export QUIET_MODE=true
                ;;
            build|start|up|stop|down|restart|status|logs|shell|backup|restore|health|diagnostics|cleanup)
                COMMAND="$1"
                ;;
            *)
                if [[ -z "${COMMAND:-}" ]]; then
                    COMMAND="$1"
                else
                    log "ERROR" "Unknown option: $1"
                    exit 1
                fi
                ;;
        esac
        shift
    done
    
    # Default command
    if [[ -z "${COMMAND:-}" ]]; then
        COMMAND="help"
    fi
}

main() {
    # Set up signal handlers
    trap cleanup EXIT
    trap 'error_handler ${LINENO} "$BASH_COMMAND" $?' ERR
    
    # Parse command line arguments
    parse_arguments "$@"
    
    log "INFO" "Starting Cursor IDE Docker Orchestration v$SCRIPT_VERSION"
    log "INFO" "Command: $COMMAND, Container Type: $CONTAINER_TYPE"
    audit_log "SCRIPT_STARTED" "Command: $COMMAND, Type: $CONTAINER_TYPE" "SUCCESS"
    
    # Initialize environment
    create_directory_structure || {
        log "CRITICAL" "Failed to create directory structure"
        exit 1
    }
    
    # Execute command
    case "$COMMAND" in
        "build")
            check_docker_availability || exit 1
            initialize_docker_network || exit 1
            build_containers || exit 1
            ;;
        "start"|"up")
            check_docker_availability || exit 1
            initialize_docker_network || exit 1
            start_services || exit 1
            ;;
        "stop"|"down")
            stop_services || exit 1
            ;;
        "restart")
            stop_services
            sleep 2
            start_services || exit 1
            ;;
        "status")
            show_service_status
            ;;
        "logs")
            if [[ "$DRY_RUN" != "true" ]]; then
                cd "$COMPOSE_DIR" && docker-compose logs -f
            fi
            ;;
        "shell")
            if [[ "$DRY_RUN" != "true" ]]; then
                docker exec -it "cursor-${CONTAINER_TYPE}" bash
            fi
            ;;
        "backup")
            backup_containers || exit 1
            ;;
        "restore")
            # Would need backup path as parameter
            log "INFO" "Restore requires backup path parameter"
            log "INFO" "Available backups:"
            ls -la "$BACKUP_DIR" 2>/dev/null || log "INFO" "No backups found"
            ;;
        "health")
            run_health_checks
            ;;
        "diagnostics")
            show_system_diagnostics
            ;;
        "cleanup")
            if [[ "$DRY_RUN" != "true" ]]; then
                docker system prune -f
                docker volume prune -f
            fi
            log "SUCCESS" "Cleanup completed"
            ;;
        "help")
            show_usage
            ;;
        *)
            log "ERROR" "Unknown command: $COMMAND"
            show_usage
            exit 1
            ;;
    esac
    
    log "SUCCESS" "Docker orchestration completed successfully"
    audit_log "SCRIPT_COMPLETED" "Command: $COMMAND" "SUCCESS"
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Only run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi