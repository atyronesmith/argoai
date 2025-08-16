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

# Update npm to version 9+ to match lockfileVersion 3
RUN npm install -g npm@9

# Install dependencies
RUN npm ci

# Copy source code
COPY src/ ./src/

# Build the application
RUN npm run build

# Production stage
FROM registry.access.redhat.com/ubi8/nodejs-16:latest

# Build arguments (need to redeclare in multi-stage)
ARG BUILD_DATE
ARG GIT_COMMIT
ARG VERSION

# Labels
LABEL org.opencontainers.image.title="AI Workflow Dashboard Backend"
LABEL org.opencontainers.image.description="Backend API for AI document processing workflow dashboard"
LABEL org.opencontainers.image.version="${VERSION}"
LABEL org.opencontainers.image.created="${BUILD_DATE}"
LABEL org.opencontainers.image.revision="${GIT_COMMIT}"
LABEL org.opencontainers.image.vendor="AI Workflow Team"

# Switch to root user to install dependencies
USER 0

# Create app directory
WORKDIR /opt/app-root/src

# Copy package files
COPY package*.json ./

# Update npm to version 9+ to match lockfileVersion 3
RUN npm install -g npm@9

# Install only production dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy built application from builder stage
COPY --from=builder /opt/app-root/src/dist ./dist

# Create data directory for SQLite
RUN mkdir -p ./data && chown -R 1001:0 ./data && chmod -R g=u ./data

# Switch back to non-root user
USER 1001

# Expose port
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3001/api/health || exit 1

# Start the application
CMD ["npm", "start"]