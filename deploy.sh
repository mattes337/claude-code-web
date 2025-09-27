#!/bin/bash

# Exit on any error
set -e

echo "Starting deployment process..."

# Create .claude directory if it doesn't exist
mkdir -p .claude

# Copy .credentials.json from home directory to project
if [ -f ~/.claude/.credentials.json ]; then
    echo "Copying .credentials.json..."
    cp ~/.claude/.credentials.json ./.claude/.credentials.json
else
    echo "Warning: ~/.claude/.credentials.json not found"
    echo "Please ensure .credentials.json exists in ~/.claude/ directory"
    exit 1
fi

# Stop existing container if running
echo "Stopping existing container..."
docker-compose down

# Rebuild and restart container
echo "Rebuilding and starting container..."
docker-compose up -d --build

echo "Deployment complete!"
echo "Container is running. Check logs with: docker-compose logs -f"