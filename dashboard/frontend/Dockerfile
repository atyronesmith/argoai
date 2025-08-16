# Multi-stage build
FROM registry.access.redhat.com/ubi8/nodejs-16:latest AS builder

# Build arguments
ARG BUILD_DATE
ARG GIT_COMMIT
ARG VERSION

# Switch to root user for building
USER 0

# Set working directory
WORKDIR /opt/app-root/src

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./
COPY tailwind.config.js ./
COPY postcss.config.js ./

# Update npm to version 9+ to match lockfileVersion 3
RUN npm install -g npm@9

# Install dependencies
RUN npm ci

# Copy source code
COPY src/ ./src/
COPY public/ ./public/

# Build the application
ENV NODE_ENV=production
ENV GENERATE_SOURCEMAP=false
RUN npm run build

# Production stage
FROM registry.access.redhat.com/ubi8/nginx-120:latest

# Build arguments (need to redeclare in multi-stage)
ARG BUILD_DATE
ARG GIT_COMMIT
ARG VERSION

# Labels
LABEL org.opencontainers.image.title="AI Workflow Dashboard Frontend"
LABEL org.opencontainers.image.description="Frontend UI for AI document processing workflow dashboard"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${GIT_COMMIT}"
LABEL org.opencontainers.image.vendor="AI Workflow Team"

# Switch to root user to copy files
USER 0

# Copy built application
COPY --from=builder /opt/app-root/src/build /opt/app-root/src/

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Copy entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Ensure proper permissions
RUN chown -R 1001:0 /opt/app-root/src && chmod -R g=u /opt/app-root/src && \
    chown 1001:0 /usr/local/bin/docker-entrypoint.sh

# Switch back to non-root user
USER 1001

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1

# Start nginx with entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]