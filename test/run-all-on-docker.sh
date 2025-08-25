#!/usr/bin/env bash

# Test script to run tests in Docker environments (Ubuntu and Alpine)
# Usage: ./run-all-on-docker.sh

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Testing in Docker Environments ==="
echo

# Function to run tests in a container
run_docker_tests() {
    local image="$1"
    local name="$2"
    
    echo "=== Testing on $name ($image) ==="
    echo
    
    docker run --rm \
      -v "$ROOT_DIR:/workspace" \
      -w /workspace \
      "$image" \
      sh -c '
        echo "Installing dependencies..."
        if command -v apk >/dev/null 2>&1; then
            # Alpine Linux
            apk add --no-cache git bash sudo >/dev/null 2>&1
        elif command -v apt-get >/dev/null 2>&1; then
            # Ubuntu/Debian
            apt-get update -qq >/dev/null 2>&1
            apt-get install -y -qq git sudo >/dev/null 2>&1
        fi
        
        echo "Creating test user..."
        useradd -m -s /bin/bash testuser 2>/dev/null || adduser -D -s /bin/bash testuser 2>/dev/null
        echo "testuser ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/testuser 2>/dev/null || true
        
        echo "Setting up workspace permissions..."
        chown -R testuser:testuser /workspace || chown -R testuser:users /workspace
        
        echo "Configuring Git for test user..."
        sudo -u testuser git config --global user.name "Test User"
        sudo -u testuser git config --global user.email "test@example.com"
        sudo -u testuser git config --global --add safe.directory "*"
        
        echo "Running tests as non-root user..."
        # Make scripts executable
        chmod +x ./build.sh ./ticket.sh
        chmod +x ./test/*.sh
        
        # Set environment variables for testuser
        export DOCKER_ENV=1
        
        # Run tests as testuser
        sudo -u testuser -E ./test/run-all.sh
      '
    
    echo
    echo "=== Finished testing on $name ==="
    echo
}

# Test on Ubuntu 22.04
run_docker_tests "ubuntu:22.04" "Ubuntu 22.04"

# Test on Alpine Linux
run_docker_tests "alpine:latest" "Alpine Linux"

echo "=== All Docker tests completed ==="