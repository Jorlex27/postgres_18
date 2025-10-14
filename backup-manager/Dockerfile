FROM alpine:3.19

LABEL maintainer="PostgreSQL Backup Manager with AWS S3"
LABEL description="Lightweight backup manager with AWS CLI for PostgreSQL backups"

# Install required packages
RUN apk add --no-cache \
    bash \
    aws-cli \
    postgresql16-client \
    curl \
    ca-certificates \
    tzdata \
    && rm -rf /var/cache/apk/*

# Set timezone (optional, adjust as needed)
ENV TZ=Australia/Sydney

# Create directories
RUN mkdir -p /backups /logs /s3-scripts

# Set working directory
WORKDIR /s3-scripts

# Copy scripts
COPY scripts/*.sh /s3-scripts/

# Make scripts executable
RUN chmod +x /s3-scripts/*.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD aws --version || exit 1

# Keep container running
CMD ["tail", "-f", "/dev/null"]
