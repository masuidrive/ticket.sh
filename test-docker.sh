#!/usr/bin/env bash

# Test script to run in Docker environment

echo "=== Setting up Docker test environment ==="

# Run tests in Docker Ubuntu 22.04
docker run --rm \
  -v "$(pwd):/workspace" \
  -w /workspace \
  ubuntu:22.04 \
  bash -c '
    echo "Installing dependencies..."
    apt-get update -qq > /dev/null 2>&1
    apt-get install -y -qq git > /dev/null 2>&1
    
    echo "Configuring Git..."
    git config --global user.name "Test User"
    git config --global user.email "test@example.com"
    git config --global --add safe.directory "*"
    
    echo "Running tests..."
    ./test-all.sh
  '