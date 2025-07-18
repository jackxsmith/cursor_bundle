#!/usr/bin/env bash
# Docker Installation Script for Cursor IDE v6.9.33

set -euo pipefail

VERSION="6.9.33"
SCRIPT_NAME="Docker Cursor Installer"

# Logging function
log() {
    echo "[docker][$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

show_help() {
    cat << 'HELP'
Cursor IDE Docker Installer v6.9.33

USAGE:
  ./15-docker_install_v6.9.33.sh [OPTIONS]

OPTIONS:
  --build         Build Docker image
  --run           Run Docker container
  --stop          Stop Docker container
  --remove        Remove Docker container and image
  --help, -h      Show this help message

EXAMPLES:
  ./15-docker_install_v6.9.33.sh --build
  ./15-docker_install_v6.9.33.sh --run
  docker exec -it cursor-ide bash

PORTS:
  5900 - VNC server (for GUI access)
  8080 - Web UI interface
HELP
}

check_docker() {
    if ! command -v docker >/dev/null 2>&1; then
        log "ERROR: Docker is not installed"
        log "Please install Docker first: https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    if ! docker info >/dev/null 2>&1; then
        log "ERROR: Docker daemon is not running"
        log "Please start Docker daemon"
        exit 1
    fi
    
    log "Docker is available and running"
}

build_image() {
    log "Building Cursor IDE Docker image..."
    docker build -t cursor-ide:v6.9.33 .
    log "Docker image built successfully"
}

run_container() {
    log "Running Cursor IDE Docker container..."
    
    # Stop existing container if running
    docker stop cursor-ide 2>/dev/null || true
    docker rm cursor-ide 2>/dev/null || true
    
    # Run new container
    docker run -d \
        --name cursor-ide \
        -p 5900:5900 \
        -p 8080:8080 \
        cursor-ide:v6.9.33
    
    log "Container started successfully"
    log "VNC access: localhost:5900"
    log "Web UI: http://localhost:8080"
    log "Shell access: docker exec -it cursor-ide bash"
}

stop_container() {
    log "Stopping Cursor IDE container..."
    docker stop cursor-ide 2>/dev/null || true
    log "Container stopped"
}

remove_all() {
    log "Removing Cursor IDE container and image..."
    docker stop cursor-ide 2>/dev/null || true
    docker rm cursor-ide 2>/dev/null || true
    docker rmi cursor-ide:v6.9.33 2>/dev/null || true
    log "Cleanup completed"
}

main() {
    case "${1:-}" in
        --build)
            check_docker
            build_image
            ;;
        --run)
            check_docker
            run_container
            ;;
        --stop)
            stop_container
            ;;
        --remove)
            remove_all
            ;;
        --help|-h)
            show_help
            ;;
        *)
            log "Starting Cursor IDE Docker installer v$VERSION"
            show_help
            ;;
    esac
}

main "$@"
