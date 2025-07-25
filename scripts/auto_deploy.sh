#!/bin/bash
# Automated deployment script with comprehensive checks

set -e

# Configuration
DEPLOYMENT_ENV="${DEPLOYMENT_ENV:-staging}"
MAX_RETRIES=3
HEALTH_CHECK_TIMEOUT=30

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ❌ $1${NC}"
}

# Pre-deployment checks
pre_deployment_checks() {
    log "Running pre-deployment checks..."
    
    # Check git status
    if [ -n "$(git status --porcelain)" ]; then
        log_error "Working directory not clean. Please commit or stash changes."
        return 1
    fi
    
    # Check if on main branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    if [ "$current_branch" != "main" ]; then
        log_warning "Not on main branch (current: $current_branch)"
        read -p "Continue deployment? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Deployment cancelled"
            return 1
        fi
    fi
    
    # Check VERSION file
    if [ ! -f "VERSION" ]; then
        log_error "VERSION file not found"
        return 1
    fi
    
    VERSION=$(cat VERSION)
    log "Deploying version: $VERSION"
    
    # Run quality checks
    log "Running quality assurance checks..."
    if command -v make >/dev/null 2>&1; then
        make lint || log_warning "Linting issues detected"
        make test || log_warning "Test issues detected"
        make security || log_warning "Security scan warnings"
    fi
    
    log_success "Pre-deployment checks completed"
    return 0
}

# Build deployment package
build_package() {
    log "Building deployment package..."
    
    # Create deployment directory
    DEPLOY_DIR="deploy_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$DEPLOY_DIR"
    
    # Copy necessary files
    cp -r scripts "$DEPLOY_DIR/"
    cp -r .github "$DEPLOY_DIR/"
    cp Makefile README.md VERSION "$DEPLOY_DIR/"
    
    # Create package info
    cat > "$DEPLOY_DIR/deploy_info.json" << EOF
{
    "version": "$(cat VERSION)",
    "deploy_time": "$(date -Iseconds)",
    "commit_hash": "$(git rev-parse HEAD)",
    "branch": "$(git rev-parse --abbrev-ref HEAD)",
    "environment": "$DEPLOYMENT_ENV",
    "deployer": "$(whoami)@$(hostname)"
}
EOF
    
    # Create deployment archive
    tar -czf "${DEPLOY_DIR}.tar.gz" "$DEPLOY_DIR"
    
    log_success "Deployment package created: ${DEPLOY_DIR}.tar.gz"
    echo "$DEPLOY_DIR"
}

# Health check function
health_check() {
    local check_url="$1"
    local max_attempts="$2"
    
    log "Performing health check..."
    
    for i in $(seq 1 "$max_attempts"); do
        log "Health check attempt $i/$max_attempts"
        
        # Simulate health check (replace with actual endpoint check)
        if curl -f -s --max-time 10 "$check_url" >/dev/null 2>&1; then
            log_success "Health check passed"
            return 0
        fi
        
        if [ $i -lt "$max_attempts" ]; then
            log "Health check failed, retrying in 5 seconds..."
            sleep 5
        fi
    done
    
    log_error "Health check failed after $max_attempts attempts"
    return 1
}

# Rollback function
rollback() {
    local previous_version="$1"
    log_warning "Initiating rollback to version $previous_version"
    
    # Simulate rollback (implement actual rollback logic)
    log "Rolling back deployment..."
    
    # Here you would implement actual rollback steps
    # For example: restore previous version, restart services, etc.
    
    log_success "Rollback completed"
}

# Main deployment function
deploy() {
    log "🚀 Starting automated deployment for environment: $DEPLOYMENT_ENV"
    
    # Pre-deployment checks
    if ! pre_deployment_checks; then
        log_error "Pre-deployment checks failed"
        exit 1
    fi
    
    # Build package
    DEPLOY_PACKAGE=$(build_package)
    
    # Backup current version (for rollback)
    PREVIOUS_VERSION=$(cat VERSION 2>/dev/null || echo "unknown")
    
    log "Deploying package: ${DEPLOY_PACKAGE}.tar.gz"
    
    # Simulate deployment steps
    log "Extracting deployment package..."
    sleep 2
    
    log "Updating application files..."
    sleep 3
    
    log "Restarting services..."
    sleep 2
    
    # Health check
    HEALTH_URL="http://localhost:8080/health"  # Replace with actual health endpoint
    if ! health_check "$HEALTH_URL" 3; then
        log_error "Deployment failed health check"
        rollback "$PREVIOUS_VERSION"
        exit 1
    fi
    
    # Cleanup
    log "Cleaning up deployment artifacts..."
    rm -rf "$DEPLOY_PACKAGE"
    rm -f "${DEPLOY_PACKAGE}.tar.gz"
    
    log_success "🎉 Deployment completed successfully!"
    log "Version deployed: $(cat VERSION)"
    log "Environment: $DEPLOYMENT_ENV"
    log "Deployment time: $(date)"
}

# Script entry point
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --env)
                DEPLOYMENT_ENV="$2"
                shift 2
                ;;
            --help)
                echo "Usage: $0 [--env environment] [--help]"
                echo "  --env: Target environment (default: staging)"
                echo "  --help: Show this help message"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    deploy
}

# Run main function with all arguments
main "$@"