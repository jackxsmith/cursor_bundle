# Multi-stage Dockerfile for Cursor Bundle
# Stage 1: Build stage
FROM ubuntu:22.04 AS builder

# Metadata
LABEL maintainer="cursor-bundle@example.com"
LABEL description="Cursor Bundle - Secure Container"
LABEL version="v6.9.163"

# Avoid interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    ca-certificates \
    python3 \
    python3-pip \
    python3-venv \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create Python virtual environment
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Install Python dependencies
COPY requirements.txt* ./
RUN if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt; else pip install --no-cache-dir flask gunicorn prometheus-client; fi

# Stage 2: Runtime stage
FROM ubuntu:22.04 AS runtime

# Install runtime dependencies only
RUN apt-get update && apt-get install -y \
    ca-certificates \
    python3 \
    curl \
    dumb-init \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean \
    && rm -rf /tmp/* /var/tmp/*

# Copy Python virtual environment from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Create non-root user with specific UID/GID
RUN groupadd -r -g 1000 cursor && \
    useradd -r -u 1000 -g cursor -d /app -s /bin/bash cursor

# Create necessary directories
RUN mkdir -p /app/{config,secrets,cache,logs,tmp} && \
    chown -R cursor:cursor /app

# Copy application files
COPY --chown=cursor:cursor bump_merged.sh /app/
COPY --chown=cursor:cursor functions/ /app/functions/
COPY --chown=cursor:cursor hooks/ /app/hooks/
COPY --chown=cursor:cursor scripts/ /app/scripts/
COPY --chown=cursor:cursor .repo_config.yaml /app/
COPY --chown=cursor:cursor VERSION /app/

# Copy startup script
COPY --chown=cursor:cursor <<EOF /app/entrypoint.sh
#!/bin/bash
set -euo pipefail

# Health check endpoint
health_check() {
    echo "OK" > /tmp/health
    while true; do
        sleep 30
        echo "$(date): Health check" >> /app/logs/health.log
    done
}

# Start health check in background
health_check &

# Start main application
exec "\$@"
EOF

RUN chmod +x /app/entrypoint.sh

# Set working directory
WORKDIR /app

# Switch to non-root user
USER cursor

# Set environment variables
ENV NODE_ENV=production \
    LOG_LEVEL=info \
    PYTHONPATH=/app \
    PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Expose ports
EXPOSE 8080 9090

# Use dumb-init for proper signal handling
ENTRYPOINT ["/usr/bin/dumb-init", "--", "/app/entrypoint.sh"]

# Default command
CMD ["python3", "-m", "flask", "run", "--host=0.0.0.0", "--port=8080"]