# Use Node.js 20 Alpine as base image for smaller size
FROM node:20-alpine AS builder

# Install build dependencies
RUN apk add --no-cache python3 make g++ git

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application source
COPY . .

# Production stage
FROM node:20-alpine

# Install runtime dependencies
# node-pty requires some system libraries
RUN apk add --no-cache \
    python3 \
    make \
    g++ \
    git \
    bash \
    openssh-client \
    su-exec

# Install Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Create non-root user for security
RUN addgroup -g 1001 -S claude && \
    adduser -u 1001 -S claude -G claude

# Set working directory
WORKDIR /app

# Copy node_modules and application from builder
COPY --from=builder --chown=claude:claude /app/node_modules ./node_modules
COPY --chown=claude:claude . .

# Create necessary directories with proper permissions
RUN mkdir -p /app/sessions && \
    mkdir -p /home/claude/.claude/projects && \
    mkdir -p /home/claude/.claude/plugins && \
    mkdir -p /home/claude/.claude/todos && \
    mkdir -p /home/claude/.claude && \
    chown -R claude:claude /app && \
    chown -R claude:claude /home/claude && \
    chmod -R 755 /home/claude/.claude

# Create entrypoint script using printf (more portable than heredoc)
RUN printf '#!/bin/sh\n\
set -e\n\
\n\
# Build command line arguments from environment variables\n\
ARGS=""\n\
\n\
# Port configuration\n\
if [ -n "$PORT" ]; then\n\
    ARGS="$ARGS --port $PORT"\n\
fi\n\
\n\
# Authentication configuration\n\
if [ -n "$AUTH_TOKEN" ]; then\n\
    ARGS="$ARGS --auth $AUTH_TOKEN"\n\
elif [ "$DISABLE_AUTH" = "true" ]; then\n\
    ARGS="$ARGS --disable-auth"\n\
fi\n\
\n\
# Subscription plan\n\
if [ -n "$PLAN" ]; then\n\
    ARGS="$ARGS --plan $PLAN"\n\
fi\n\
\n\
# Always disable browser opening in Docker\n\
ARGS="$ARGS --no-open"\n\
\n\
# HTTPS configuration\n\
if [ "$HTTPS_ENABLED" = "true" ]; then\n\
    ARGS="$ARGS --https"\n\
    \n\
    if [ -n "$SSL_CERT_PATH" ]; then\n\
        ARGS="$ARGS --cert $SSL_CERT_PATH"\n\
    fi\n\
    \n\
    if [ -n "$SSL_KEY_PATH" ]; then\n\
        ARGS="$ARGS --key $SSL_KEY_PATH"\n\
    fi\n\
fi\n\
\n\
# Development mode\n\
if [ "$DEV_MODE" = "true" ]; then\n\
    ARGS="$ARGS --dev"\n\
fi\n\
\n\
# Log the command being executed\n\
echo "Starting Claude Code Web with arguments: $ARGS"\n\
\n\
# Execute the application\n\
exec node bin/cc-web.js $ARGS "$@"\n' > /app/docker-entrypoint.sh && \
    chmod +x /app/docker-entrypoint.sh && \
    chown claude:claude /app/docker-entrypoint.sh

# Copy the external entrypoint script
COPY --chown=root:root docker-entrypoint.sh /app/docker-entrypoint.sh
RUN chmod +x /app/docker-entrypoint.sh

# Don't switch to non-root user here - let entrypoint handle it
# USER claude

# Expose default port
EXPOSE 32352

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:32352/api/health', (r) => {if(r.statusCode !== 200) process.exit(1);})"

# Use entrypoint script to handle environment variables
# Run as root so it can fix permissions, then it will drop to claude user
ENTRYPOINT ["/app/docker-entrypoint.sh"]
