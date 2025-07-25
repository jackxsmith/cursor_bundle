# 🚀 Cursor Bundle – Enterprise Automation Suite

![CI](https://github.com/jackxsmith/cursor_bundle/actions/workflows/ci.yml/badge.svg)
![Version](https://img.shields.io/badge/version-6.9.163-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Platform](https://img.shields.io/badge/platform-Linux-lightgrey.svg)

> Advanced automation suite for Cursor IDE with enterprise-grade infrastructure, security, and observability features.

## 📖 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Development](#development)
- [Security](#security)
- [Monitoring](#monitoring)
- [Contributing](#contributing)
- [License](#license)

## 🔍 Overview

Cursor Bundle is a comprehensive automation suite designed for enterprise-scale deployment and management of Cursor IDE. It provides automated installation, configuration, security hardening, and monitoring capabilities through a modern cloud-native architecture.

### Key Components

- **🖥️ Launcher Scripts** - Enhanced AppImage launchers with security validation
- **🐳 Container Infrastructure** - Multi-stage Docker builds with security hardening  
- **☸️ Kubernetes Deployment** - Production-ready K8s manifests with Istio service mesh
- **🏗️ Terraform Infrastructure** - Multi-environment AWS/cloud provisioning
- **🔒 Security Suite** - Comprehensive security scanning and compliance tools
- **📊 Observability Stack** - OpenTelemetry, Prometheus, Grafana, and Jaeger integration
- **🌐 API Gateway** - Kong-powered gateway with advanced plugins
- **🔄 CI/CD Pipeline** - GitHub Actions with security scanning and SBOM generation

## ✨ Features

### 🔐 Enterprise Security
- **Zero-trust architecture** with mutual TLS
- **Container security scanning** with Syft and Grype
- **SBOM generation** for compliance tracking
- **Secret management** with Kubernetes secrets and external secret operators
- **Network policies** and pod security standards
- **Security headers** and content security policies

### 📈 Observability & Monitoring
- **Distributed tracing** with OpenTelemetry and Jaeger
- **Metrics collection** with Prometheus and custom exporters
- **Log aggregation** with FluentBit and Loki
- **Service mesh visibility** with Istio telemetry
- **Application performance monitoring** with Grafana dashboards
- **SLA monitoring** and alerting with PagerDuty integration

### 🏗️ Cloud-Native Infrastructure
- **Multi-environment** Terraform modules (dev/staging/prod)
- **Auto-scaling** with Kubernetes HPA and VPA
- **Cost optimization** with spot instances and Karpenter
- **Disaster recovery** with cross-region backups
- **High availability** with anti-affinity and zone distribution

### 🔄 DevOps & Automation
- **GitOps workflows** with automated version management
- **Multi-platform CI/CD** with matrix builds
- **Automated dependency updates** and security patching
- **Canary deployments** with progressive delivery
- **Rollback capabilities** and blue-green deployments

## 🚀 Quick Start

### Prerequisites

- **Linux** (Ubuntu 20.04+ recommended)
- **Docker** 20.10+
- **Kubernetes** 1.28+ (or managed service like EKS)
- **Terraform** 1.6+
- **Python** 3.11+
- **Node.js** 18+ (for some tools)

### Installation

```bash
# Clone the repository
git clone https://github.com/jackxsmith/cursor_bundle.git
cd cursor_bundle

# Make scripts executable
chmod +x *.sh scripts/*.sh

# Quick installation (with dependencies)
./14-install_enhanced.sh --quick

# Or manual installation
./02-launcher_enhanced.sh --install
```

### Docker Deployment

```bash
# Build the container
docker build -t cursor-bundle:latest .

# Run with docker-compose
docker-compose up -d

# Access web interface
open http://localhost:8080
```

### Kubernetes Deployment

```bash
# Apply Kubernetes manifests
kubectl apply -f k8s/

# Or use Helm
helm install cursor-bundle ./helm/cursor-bundle/

# Port forward for local access
kubectl port-forward svc/cursor-bundle 8080:80
```

## 🏗️ Architecture

```mermaid
graph TB
    subgraph "User Interface"
        CLI[CLI Tools]
        WEB[Web Interface]
        API[REST API]
    end
    
    subgraph "Application Layer"
        LAUNCHER[Enhanced Launcher]
        WEBAPP[Flask Web App]
        HOOKS[Git Hooks]
    end
    
    subgraph "Infrastructure Layer"
        KONG[Kong API Gateway]
        K8S[Kubernetes Cluster]
        ISTIO[Istio Service Mesh]
    end
    
    subgraph "Data Layer"
        POSTGRES[PostgreSQL]
        REDIS[Redis Cache]
        S3[Object Storage]
    end
    
    subgraph "Observability"
        PROMETHEUS[Prometheus]
        GRAFANA[Grafana]
        JAEGER[Jaeger]
        LOKI[Loki]
    end
    
    CLI --> LAUNCHER
    WEB --> WEBAPP
    API --> KONG
    KONG --> K8S
    K8S --> POSTGRES
    K8S --> REDIS
    K8S --> S3
    K8S --> PROMETHEUS
    PROMETHEUS --> GRAFANA
    K8S --> JAEGER
    K8S --> LOKI
```

## 🛠️ Configuration

### Environment Variables

```bash
# Application Configuration
export CURSOR_VERSION="6.9.163"
export ENVIRONMENT="production"
export DEBUG="false"

# Database Configuration
export DATABASE_URL="postgresql://user:pass@host:5432/db"
export REDIS_URL="redis://host:6379/0"

# Observability Configuration
export JAEGER_ENDPOINT="http://jaeger:14268/api/traces"
export OTEL_EXPORTER_OTLP_ENDPOINT="http://otel-collector:4317"

# Security Configuration
export ENABLE_SECURITY_SCANNING="true"
export SECRET_KEY="your-secret-key"
```

### Repository Configuration

The `.repo_config.yaml` file controls feature flags and deployment settings:

```yaml
# Repository Information
owner: jackxsmith
repo: cursor_bundle
current_version: 6.9.163

# Feature Flags
create_release: true
generate_changelog: true
generate_artifacts: true
enable_security_scanning: true

# Notification Channels
notification_channels:
  - slack
  - teams
  - email
```

## 🔧 Development

### Local Development Setup

```bash
# Install development dependencies
pip install -r requirements-dev.txt
npm install -g @commitlint/cli

# Set up pre-commit hooks
./scripts/install_hooks.sh

# Run tests
./scripts/run_tests.sh

# Start development server
python webui.py
```

### Running Tests

```bash
# Unit tests
./scripts/run_tests.sh

# Integration tests
./scripts/run_performance_test.sh

# Security tests
./scripts/dynamic_security_scan.sh

# Generate coverage report
./scripts/generate_coverage.sh
```

### Building Documentation

```bash
# Generate API documentation
./scripts/generate_docs.sh

# Build and serve locally
mkdocs serve
```

## 🔒 Security

### Security Features

- **🛡️ Container Security**: Non-root execution, read-only filesystems, capability dropping
- **🔐 Secret Management**: Kubernetes secrets, external secret operators
- **🌐 Network Security**: Network policies, Istio mTLS, ingress protection
- **📋 Compliance**: SBOM generation, vulnerability scanning, policy enforcement
- **🔍 Monitoring**: Security event logging, anomaly detection, threat intelligence

### Security Scanning

```bash
# Run comprehensive security scan
./scripts/dynamic_security_scan.sh

# Generate SBOM
./scripts/generate_sbom.sh

# Sign artifacts
./scripts/sign_artifacts.sh
```

### Vulnerability Management

The project includes automated vulnerability scanning in the CI/CD pipeline:

- **Static Analysis**: CodeQL, Semgrep, and custom security rules
- **Container Scanning**: Grype for vulnerability detection
- **Dependency Scanning**: Automated dependency updates with Dependabot
- **License Compliance**: FOSSA integration for license scanning

## 📊 Monitoring

### Metrics and Alerting

The observability stack provides comprehensive monitoring:

```bash
# Access Grafana dashboard
kubectl port-forward svc/grafana 3000:80

# View Jaeger traces
kubectl port-forward svc/jaeger 16686:16686

# Check Prometheus metrics
kubectl port-forward svc/prometheus 9090:9090
```

### Key Metrics

- **Application Performance**: Response time, throughput, error rate
- **Infrastructure Health**: CPU, memory, disk, network utilization
- **Security Events**: Authentication failures, policy violations
- **Business Metrics**: User activity, feature usage, conversion rates

### Alerting Rules

Alerts are configured for:

- Application downtime or high error rates
- Resource exhaustion (CPU, memory, disk)
- Security policy violations
- SLA breaches and performance degradation

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Workflow

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Code Standards

- **Shell Scripts**: Follow ShellCheck recommendations
- **Python**: Use Black formatting and type hints
- **YAML**: Validate with yamllint
- **Documentation**: Update README and inline docs

## 📋 Changelog

See [CHANGELOG.md](CHANGELOG.md) for detailed release notes.

### Recent Updates (v6.9.163)

- ✨ Enhanced security with container hardening
- 🚀 Improved CI/CD pipeline with SBOM generation
- 📊 Advanced observability with OpenTelemetry
- 🔧 Multi-environment Terraform infrastructure
- 🌐 Kong API Gateway with advanced plugins

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: [Wiki](https://github.com/jackxsmith/cursor_bundle/wiki)
- **Issues**: [GitHub Issues](https://github.com/jackxsmith/cursor_bundle/issues)
- **Discussions**: [GitHub Discussions](https://github.com/jackxsmith/cursor_bundle/discussions)
- **Security**: [Security Policy](SECURITY.md)

## 🙏 Acknowledgments

- **Cursor IDE** team for the excellent editor
- **Open Source Community** for the amazing tools and libraries
- **Contributors** who help make this project better

---

<div align="center">

**[⬆ Back to Top](#-cursor-bundle--enterprise-automation-suite)**

Made with ❤️ by the Cursor Bundle team

</div>