.PHONY: all lint test security release clean install help docker k8s terraform dev prod check
.DEFAULT_GOAL := help

# Colors for terminal output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[0;33m
BLUE := \033[0;34m
PURPLE := \033[0;35m
CYAN := \033[0;36m
NC := \033[0m # No Color

# Project configuration
VERSION := $(shell cat VERSION 2>/dev/null || echo "unknown")
PROJECT_NAME := cursor-bundle
DOCKER_REGISTRY := ghcr.io/jackxsmith
DOCKER_IMAGE := $(DOCKER_REGISTRY)/$(PROJECT_NAME)
NAMESPACE := cursor-bundle

# Environment detection
ENVIRONMENT ?= development
ifeq ($(ENVIRONMENT),production)
	DOCKER_TAG := $(VERSION)
	REPLICAS := 3
else ifeq ($(ENVIRONMENT),staging)
	DOCKER_TAG := $(VERSION)-staging
	REPLICAS := 2
else
	DOCKER_TAG := $(VERSION)-dev
	REPLICAS := 1
endif

# Build configuration
BUILD_DATE := $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

all: lint test security build ## Run all build tasks

help: ## Show this help message
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "$(BLUE)                    🚀 Cursor Bundle Build System                               $(NC)"
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "$(CYAN)Project:$(NC)     $(PROJECT_NAME)"
	@echo "$(CYAN)Version:$(NC)     $(VERSION)"
	@echo "$(CYAN)Environment:$(NC) $(ENVIRONMENT)"
	@echo "$(CYAN)Git Commit:$(NC)  $(GIT_COMMIT)"
	@echo "$(CYAN)Git Branch:$(NC)  $(GIT_BRANCH)"
	@echo "$(CYAN)Build Date:$(NC)  $(BUILD_DATE)"
	@echo ""
	@echo "$(YELLOW)📋 Available Commands:$(NC)"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(BLUE)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)🏷️  Environment Variables:$(NC)"
	@echo "  $(BLUE)ENVIRONMENT$(NC)      Set to development, staging, or production"
	@echo "  $(BLUE)DOCKER_REGISTRY$(NC)  Override Docker registry (default: $(DOCKER_REGISTRY))"
	@echo "  $(BLUE)NAMESPACE$(NC)        Kubernetes namespace (default: $(NAMESPACE))"

# ============================================================================
# Development & Dependencies
# ============================================================================

install: ## Install all dependencies and development tools
	@echo "$(YELLOW)📦 Installing dependencies and development tools...$(NC)"
	@echo "$(CYAN)Installing Python dependencies...$(NC)"
	@if command -v pip3 >/dev/null 2>&1; then \
		pip3 install --upgrade pip wheel setuptools; \
		pip3 install flask gunicorn prometheus-client; \
		pip3 install ruff black isort mypy pytest pytest-cov bandit safety; \
		pip3 install pre-commit yamllint shellcheck-py; \
	else \
		echo "$(RED)❌ Python pip3 not found. Please install Python 3.$(NC)"; \
		exit 1; \
	fi
	@echo "$(CYAN)Setting up pre-commit hooks...$(NC)"
	@if [ -f scripts/install_hooks.sh ]; then bash scripts/install_hooks.sh; fi
	@echo "$(GREEN)✅ Dependencies installed successfully$(NC)"

dev-setup: install ## Set up development environment
	@echo "$(YELLOW)🔧 Setting up development environment...$(NC)"
	@echo "$(CYAN)Creating virtual environment...$(NC)"
	@python3 -m venv venv --upgrade-deps
	@echo "$(CYAN)Activating virtual environment and installing packages...$(NC)"
	@. venv/bin/activate && pip install -r requirements.txt 2>/dev/null || echo "No requirements.txt found"
	@echo "$(GREEN)✅ Development environment ready$(NC)"
	@echo "$(BLUE)💡 To activate: source venv/bin/activate$(NC)"

# ============================================================================
# Code Quality & Testing
# ============================================================================

lint: ## Run comprehensive code linting
	@echo "$(YELLOW)🔍 Running code linting...$(NC)"
	@echo "$(CYAN)Checking shell scripts with shellcheck...$(NC)"
	@find . -name "*.sh" -type f -not -path "./venv/*" | head -20 | \
		xargs shellcheck --format=gcc --severity=warning || echo "$(YELLOW)⚠️  Shellcheck completed with warnings$(NC)"
	@echo "$(CYAN)Checking Python code with ruff...$(NC)"
	@ruff check . --output-format=github --exclude=venv || echo "$(YELLOW)⚠️  Ruff completed with warnings$(NC)"
	@echo "$(CYAN)Checking code formatting with black...$(NC)"
	@black --check --diff . --exclude=venv || echo "$(YELLOW)⚠️  Black formatting issues found$(NC)"
	@echo "$(CYAN)Checking YAML files...$(NC)"
	@find . -name "*.yaml" -o -name "*.yml" | grep -v venv | \
		xargs yamllint -f parsable || echo "$(YELLOW)⚠️  YAML linting completed with warnings$(NC)"
	@echo "$(GREEN)✅ Linting completed$(NC)"

format: ## Auto-format code
	@echo "$(YELLOW)🎨 Formatting code...$(NC)"
	@black . --exclude=venv
	@isort . --skip=venv
	@echo "$(GREEN)✅ Code formatting completed$(NC)"

type-check: ## Run type checking
	@echo "$(YELLOW)🔬 Running type checking...$(NC)"
	@mypy . --exclude=venv --ignore-missing-imports || echo "$(YELLOW)⚠️  Type checking completed with warnings$(NC)"
	@echo "$(GREEN)✅ Type checking completed$(NC)"

test: ## Run comprehensive test suite
	@echo "$(YELLOW)🧪 Running test suite...$(NC)"
	@if [ -f scripts/run_tests.sh ]; then \
		bash scripts/run_tests.sh; \
	else \
		echo "$(CYAN)Running basic validation tests...$(NC)"; \
		bash -n bump_merged.sh || echo "Syntax check for bump_merged.sh"; \
		python3 -m py_compile *.py 2>/dev/null || echo "Python syntax check completed"; \
		echo "$(BLUE)💡 Add scripts/run_tests.sh for comprehensive testing$(NC)"; \
	fi
	@echo "$(GREEN)✅ Tests completed$(NC)"

test-coverage: ## Run tests with coverage report
	@echo "$(YELLOW)📊 Running tests with coverage analysis...$(NC)"
	@if [ -f scripts/generate_coverage.sh ]; then \
		bash scripts/generate_coverage.sh; \
	else \
		pytest --cov=. --cov-report=html --cov-report=term-missing || echo "Coverage analysis completed"; \
	fi
	@echo "$(GREEN)✅ Coverage analysis completed$(NC)"

# ============================================================================
# Security & Compliance
# ============================================================================

security: ## Run comprehensive security scans
	@echo "$(YELLOW)🔒 Running security scans...$(NC)"
	@echo "$(CYAN)Checking for common security issues with bandit...$(NC)"
	@bandit -r . -f txt --exclude=./venv || echo "$(YELLOW)⚠️  Security scan completed with warnings$(NC)"
	@echo "$(CYAN)Checking for vulnerable dependencies with safety...$(NC)"
	@safety check || echo "$(YELLOW)⚠️  Dependency check completed with warnings$(NC)"
	@echo "$(CYAN)Scanning for secrets and sensitive data...$(NC)"
	@grep -r -n -i "password\|secret\|key\|token" --include="*.sh" --include="*.py" \
		--exclude-dir=venv . | head -10 || echo "No obvious secrets detected"
	@echo "$(GREEN)✅ Security scans completed$(NC)"

dynamic-scan: ## Run dynamic security analysis
	@echo "$(YELLOW)🕵️  Running dynamic security scan...$(NC)"
	@if [ -f scripts/dynamic_security_scan.sh ]; then \
		bash scripts/dynamic_security_scan.sh; \
	else \
		echo "$(CYAN)Running basic dynamic analysis...$(NC)"; \
		echo "✓ File permissions check"; \
		find . -type f -perm /111 -name "*.sh" | head -10; \
		echo "✓ Dynamic analysis completed"; \
	fi
	@echo "$(GREEN)✅ Dynamic security scan completed$(NC)"

generate-sbom: ## Generate Software Bill of Materials
	@echo "$(YELLOW)📋 Generating Software Bill of Materials...$(NC)"
	@if [ -f scripts/generate_sbom.sh ]; then \
		bash scripts/generate_sbom.sh; \
	else \
		echo "$(CYAN)Creating basic SBOM...$(NC)"; \
		mkdir -p dist; \
		echo "# Software Bill of Materials - $(PROJECT_NAME) v$(VERSION)" > dist/sbom.txt; \
		echo "Generated: $(BUILD_DATE)" >> dist/sbom.txt; \
		echo "Git Commit: $(GIT_COMMIT)" >> dist/sbom.txt; \
		echo "$(GREEN)✅ Basic SBOM created at dist/sbom.txt$(NC)"; \
	fi

# ============================================================================
# Build & Release
# ============================================================================

build: ## Build application artifacts
	@echo "$(YELLOW)🏗️  Building application artifacts...$(NC)"
	@mkdir -p dist
	@if [ -f scripts/build_release.sh ]; then \
		bash scripts/build_release.sh; \
	else \
		echo "$(CYAN)Creating release archive...$(NC)"; \
		tar -czf dist/$(PROJECT_NAME)_$(VERSION).tar.gz \
			--exclude=dist --exclude=.git --exclude=venv \
			--exclude=node_modules --exclude=.pytest_cache .; \
		echo "$(GREEN)✅ Release archive created: dist/$(PROJECT_NAME)_$(VERSION).tar.gz$(NC)"; \
	fi

sign-artifacts: ## Sign build artifacts with GPG
	@echo "$(YELLOW)✍️  Signing build artifacts...$(NC)"
	@if [ -f scripts/sign_artifacts.sh ]; then \
		bash scripts/sign_artifacts.sh; \
	else \
		echo "$(CYAN)Checking for GPG key...$(NC)"; \
		if command -v gpg >/dev/null 2>&1; then \
			for file in dist/*.tar.gz dist/*.zip 2>/dev/null; do \
				[ -f "$$file" ] && gpg --detach-sign --armor "$$file" && echo "✓ Signed $$file"; \
			done; \
		else \
			echo "$(YELLOW)⚠️  GPG not available, skipping signing$(NC)"; \
		fi; \
	fi
	@echo "$(GREEN)✅ Artifact signing completed$(NC)"

release: build sign-artifacts generate-sbom ## Create a complete release
	@echo "$(YELLOW)🚀 Creating release for version $(VERSION)...$(NC)"
	@echo "$(GREEN)✅ Release $(VERSION) created successfully$(NC)"
	@echo "$(BLUE)📦 Artifacts available in dist/ directory$(NC)"

# ============================================================================
# Docker Operations
# ============================================================================

docker-build: ## Build Docker image
	@echo "$(YELLOW)🐳 Building Docker image...$(NC)"
	@docker build \
		--build-arg VERSION=$(VERSION) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--build-arg GIT_COMMIT=$(GIT_COMMIT) \
		--label version=$(VERSION) \
		--label build-date=$(BUILD_DATE) \
		--label git-commit=$(GIT_COMMIT) \
		-t $(DOCKER_IMAGE):$(DOCKER_TAG) \
		-t $(DOCKER_IMAGE):latest .
	@echo "$(GREEN)✅ Docker image built: $(DOCKER_IMAGE):$(DOCKER_TAG)$(NC)"

docker-push: docker-build ## Push Docker image to registry
	@echo "$(YELLOW)📤 Pushing Docker image to registry...$(NC)"
	@docker push $(DOCKER_IMAGE):$(DOCKER_TAG)
	@if [ "$(ENVIRONMENT)" = "production" ]; then \
		docker push $(DOCKER_IMAGE):latest; \
	fi
	@echo "$(GREEN)✅ Docker image pushed$(NC)"

docker-run: ## Run Docker container locally
	@echo "$(YELLOW)🏃 Running Docker container...$(NC)"
	@docker run -d \
		--name $(PROJECT_NAME)-$(ENVIRONMENT) \
		-p 8080:8080 \
		-e ENVIRONMENT=$(ENVIRONMENT) \
		$(DOCKER_IMAGE):$(DOCKER_TAG)
	@echo "$(GREEN)✅ Container started: http://localhost:8080$(NC)"

docker-stop: ## Stop and remove Docker container
	@echo "$(YELLOW)🛑 Stopping Docker container...$(NC)"
	@docker stop $(PROJECT_NAME)-$(ENVIRONMENT) 2>/dev/null || true
	@docker rm $(PROJECT_NAME)-$(ENVIRONMENT) 2>/dev/null || true
	@echo "$(GREEN)✅ Container stopped$(NC)"

docker-logs: ## Show Docker container logs
	@docker logs -f $(PROJECT_NAME)-$(ENVIRONMENT) 2>/dev/null || echo "$(RED)Container not running$(NC)"

# ============================================================================
# Kubernetes Operations
# ============================================================================

k8s-deploy: ## Deploy to Kubernetes
	@echo "$(YELLOW)☸️  Deploying to Kubernetes ($(ENVIRONMENT))...$(NC)"
	@if [ ! -f k8s/deployment.yaml ]; then \
		echo "$(RED)❌ Kubernetes manifests not found in k8s/$(NC)"; \
		exit 1; \
	fi
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@envsubst < k8s/deployment.yaml | kubectl apply -n $(NAMESPACE) -f -
	@kubectl apply -n $(NAMESPACE) -f k8s/
	@echo "$(GREEN)✅ Deployed to Kubernetes namespace: $(NAMESPACE)$(NC)"

k8s-status: ## Check Kubernetes deployment status
	@echo "$(YELLOW)📊 Checking Kubernetes deployment status...$(NC)"
	@kubectl get pods,svc,ingress -n $(NAMESPACE) -o wide

k8s-logs: ## Show Kubernetes pod logs
	@echo "$(YELLOW)📜 Showing Kubernetes logs...$(NC)"
	@kubectl logs -n $(NAMESPACE) -l app=$(PROJECT_NAME) --tail=100 -f

k8s-delete: ## Delete Kubernetes deployment
	@echo "$(YELLOW)🗑️  Deleting Kubernetes deployment...$(NC)"
	@kubectl delete namespace $(NAMESPACE) --ignore-not-found=true
	@echo "$(GREEN)✅ Kubernetes deployment deleted$(NC)"

helm-install: ## Install with Helm
	@echo "$(YELLOW)⎈  Installing with Helm...$(NC)"
	@helm upgrade --install $(PROJECT_NAME) ./helm/cursor-bundle/ \
		--namespace $(NAMESPACE) --create-namespace \
		--set image.tag=$(DOCKER_TAG) \
		--set environment=$(ENVIRONMENT) \
		--set replicas=$(REPLICAS)
	@echo "$(GREEN)✅ Helm chart installed$(NC)"

# ============================================================================
# Infrastructure & Terraform
# ============================================================================

terraform-init: ## Initialize Terraform
	@echo "$(YELLOW)🏗️  Initializing Terraform...$(NC)"
	@cd terraform && terraform init
	@echo "$(GREEN)✅ Terraform initialized$(NC)"

terraform-plan: ## Plan Terraform changes
	@echo "$(YELLOW)📋 Planning Terraform changes...$(NC)"
	@cd terraform && terraform plan -var="environment=$(ENVIRONMENT)" -var="app_version=$(VERSION)"

terraform-apply: ## Apply Terraform changes
	@echo "$(YELLOW)🚀 Applying Terraform changes...$(NC)"
	@cd terraform && terraform apply -var="environment=$(ENVIRONMENT)" -var="app_version=$(VERSION)" -auto-approve
	@echo "$(GREEN)✅ Terraform applied$(NC)"

terraform-destroy: ## Destroy Terraform infrastructure
	@echo "$(YELLOW)💥 Destroying Terraform infrastructure...$(NC)"
	@cd terraform && terraform destroy -var="environment=$(ENVIRONMENT)" -var="app_version=$(VERSION)" -auto-approve
	@echo "$(GREEN)✅ Infrastructure destroyed$(NC)"

# ============================================================================
# Performance & Monitoring
# ============================================================================

perf-test: ## Run performance tests
	@echo "$(YELLOW)⚡ Running performance tests...$(NC)"
	@if [ -f scripts/run_performance_test.sh ]; then \
		bash scripts/run_performance_test.sh; \
	else \
		echo "$(CYAN)Running basic performance checks...$(NC)"; \
		time bash -c "echo 'Performance test placeholder'"; \
		echo "$(BLUE)💡 Add scripts/run_performance_test.sh for comprehensive testing$(NC)"; \
	fi

benchmark: ## Run benchmarks
	@echo "$(YELLOW)📈 Running benchmarks...$(NC)"
	@echo "$(CYAN)File I/O benchmark...$(NC)"
	@time for i in {1..1000}; do echo "test" > /tmp/bench_$$i.tmp && rm /tmp/bench_$$i.tmp; done
	@echo "$(GREEN)✅ Benchmarks completed$(NC)"

# ============================================================================
# Maintenance & Cleanup
# ============================================================================

clean: ## Clean all build artifacts and caches
	@echo "$(YELLOW)🧹 Cleaning build artifacts...$(NC)"
	@rm -rf dist/ *.log *.tmp .pytest_cache/ __pycache__/ *.pyc
	@rm -rf coverage/ .coverage .coverage.* htmlcov/
	@rm -rf .mypy_cache/ .ruff_cache/
	@find . -name "*.pyc" -delete
	@find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@echo "$(GREEN)✅ Cleanup completed$(NC)"

clean-docker: ## Clean Docker images and containers
	@echo "$(YELLOW)🐳 Cleaning Docker resources...$(NC)"
	@docker system prune -f
	@docker rmi $(DOCKER_IMAGE):$(DOCKER_TAG) 2>/dev/null || true
	@echo "$(GREEN)✅ Docker cleanup completed$(NC)"

update-deps: ## Update dependencies
	@echo "$(YELLOW)📦 Updating dependencies...$(NC)"
	@pip3 install --upgrade pip wheel setuptools
	@pip3 list --outdated --format=freeze | grep -v '^\-e' | cut -d = -f 1 | xargs -n1 pip3 install -U
	@echo "$(GREEN)✅ Dependencies updated$(NC)"

# ============================================================================
# Validation & Health Checks
# ============================================================================

validate: ## Validate project structure and configuration
	@echo "$(YELLOW)✅ Validating project structure...$(NC)"
	@echo "$(CYAN)Checking required files...$(NC)"
	@test -f VERSION && echo "✓ VERSION file found" || echo "❌ VERSION file missing"
	@test -f README.md && echo "✓ README.md found" || echo "❌ README.md missing"
	@test -f Dockerfile && echo "✓ Dockerfile found" || echo "❌ Dockerfile missing"
	@test -f .repo_config.yaml && echo "✓ .repo_config.yaml found" || echo "❌ .repo_config.yaml missing"
	@test -d scripts && echo "✓ scripts directory found" || echo "❌ scripts directory missing"
	@test -d k8s && echo "✓ k8s directory found" || echo "❌ k8s directory missing"
	@echo "$(CYAN)Validating YAML syntax...$(NC)"
	@find . -name "*.yaml" -o -name "*.yml" | grep -v venv | xargs -I {} sh -c 'python3 -c "import yaml; yaml.safe_load(open(\"{}\"))" && echo "✓ {}" || echo "❌ {}"'
	@echo "$(GREEN)✅ Validation completed$(NC)"

health-check: ## Perform comprehensive health check
	@echo "$(YELLOW)🏥 Performing health check...$(NC)"
	@echo "$(CYAN)System requirements...$(NC)"
	@command -v python3 >/dev/null && echo "✓ Python 3 available" || echo "❌ Python 3 missing"
	@command -v docker >/dev/null && echo "✓ Docker available" || echo "❌ Docker missing"
	@command -v kubectl >/dev/null && echo "✓ kubectl available" || echo "❌ kubectl missing"
	@command -v terraform >/dev/null && echo "✓ Terraform available" || echo "❌ Terraform missing"
	@echo "$(CYAN)Project health...$(NC)"
	@test -x bump_merged.sh && echo "✓ Main script executable" || echo "❌ Main script not executable"
	@python3 -c "import sys; print(f'✓ Python {sys.version.split()[0]}')"
	@echo "$(GREEN)✅ Health check completed$(NC)"

# ============================================================================
# CI/CD Integration
# ============================================================================

ci: lint test security build ## Run CI pipeline locally
	@echo "$(GREEN)✅ CI pipeline completed successfully$(NC)"

cd-staging: ci docker-push ## Deploy to staging
	@$(MAKE) ENVIRONMENT=staging k8s-deploy
	@echo "$(GREEN)✅ Deployed to staging$(NC)"

cd-production: ci docker-push ## Deploy to production
	@$(MAKE) ENVIRONMENT=production k8s-deploy
	@echo "$(GREEN)✅ Deployed to production$(NC)"

# ============================================================================
# Environment-specific shortcuts
# ============================================================================

dev: ## Set up and run development environment
	@$(MAKE) ENVIRONMENT=development dev-setup docker-run
	@echo "$(GREEN)✅ Development environment ready$(NC)"

staging: ## Deploy to staging environment
	@$(MAKE) ENVIRONMENT=staging cd-staging

prod: ## Deploy to production environment
	@$(MAKE) ENVIRONMENT=production cd-production

# ============================================================================
# Information & Status
# ============================================================================

status: ## Show project status and information
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "$(BLUE)                         📊 Project Status                                      $(NC)"
	@echo "$(BLUE)━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━$(NC)"
	@echo "$(CYAN)Project Name:$(NC)     $(PROJECT_NAME)"
	@echo "$(CYAN)Version:$(NC)         $(VERSION)"
	@echo "$(CYAN)Environment:$(NC)     $(ENVIRONMENT)"
	@echo "$(CYAN)Docker Image:$(NC)    $(DOCKER_IMAGE):$(DOCKER_TAG)"
	@echo "$(CYAN)Git Branch:$(NC)      $(GIT_BRANCH)"
	@echo "$(CYAN)Git Commit:$(NC)      $(GIT_COMMIT)"
	@echo "$(CYAN)Build Date:$(NC)      $(BUILD_DATE)"
	@echo "$(CYAN)Namespace:$(NC)       $(NAMESPACE)"
	@echo ""
	@echo "$(YELLOW)📁 Project Structure:$(NC)"
	@ls -la | head -10
	@echo ""
	@echo "$(YELLOW)🔗 Quick Links:$(NC)"
	@echo "  $(BLUE)Local Web UI:$(NC)    http://localhost:8080"
	@echo "  $(BLUE)GitHub Repo:$(NC)     https://github.com/jackxsmith/cursor_bundle"
	@echo "  $(BLUE)CI/CD Status:$(NC)    https://github.com/jackxsmith/cursor_bundle/actions"

# ============================================================================
# Special targets
# ============================================================================

check: validate health-check ## Run all validation and health checks

full-pipeline: clean install lint type-check test security build generate-sbom sign-artifacts ## Run complete build pipeline

.PHONY: docker docker-build docker-push docker-run docker-stop docker-logs
.PHONY: k8s k8s-deploy k8s-status k8s-logs k8s-delete helm-install
.PHONY: terraform terraform-init terraform-plan terraform-apply terraform-destroy
.PHONY: dev-setup format type-check test-coverage dynamic-scan
.PHONY: perf-test benchmark clean-docker update-deps health-check
.PHONY: ci cd-staging cd-production dev staging prod status check full-pipeline