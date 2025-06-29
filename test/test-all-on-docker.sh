#!/usr/bin/env bash

# Run tests on Ubuntu and Alpine Linux containers
# This ensures cross-platform compatibility

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get current directory
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${YELLOW}=== Running Tests on Docker Containers ===${NC}"
echo

# Test on Ubuntu 22.04
echo -e "${YELLOW}Testing on Ubuntu 22.04...${NC}"
docker run --rm -v "$PROJECT_DIR:/workspace" -w /workspace ubuntu:22.04 bash -c "
    apt-get update -qq && apt-get install -y -qq git >/dev/null 2>&1
    git config --global user.name 'Test User'
    git config --global user.email 'test@example.com'
    git config --global --add safe.directory /workspace
    git config --global --add safe.directory '*'
    echo 'Running tests on Ubuntu 22.04...'
    cd test && ./test-all.sh
"
UBUNTU_RESULT=$?

echo
echo -e "${YELLOW}Testing on Alpine Linux...${NC}"
# Test on Alpine Linux
docker run --rm -v "$PROJECT_DIR:/workspace" -w /workspace alpine:latest sh -c "
    apk add --no-cache bash git >/dev/null 2>&1
    git config --global user.name 'Test User'
    git config --global user.email 'test@example.com'
    git config --global --add safe.directory /workspace
    git config --global --add safe.directory '*'
    echo 'Running tests on Alpine Linux...'
    cd test && bash ./test-all.sh
"
ALPINE_RESULT=$?

# Summary
echo
echo -e "${YELLOW}=== Docker Test Summary ===${NC}"
if [[ $UBUNTU_RESULT -eq 0 ]]; then
    echo -e "${GREEN}✓ Ubuntu 22.04: All tests passed${NC}"
else
    echo -e "${RED}✗ Ubuntu 22.04: Some tests failed${NC}"
fi

if [[ $ALPINE_RESULT -eq 0 ]]; then
    echo -e "${GREEN}✓ Alpine Linux: All tests passed${NC}"
else
    echo -e "${RED}✗ Alpine Linux: Some tests failed${NC}"
fi

# Exit with failure if any tests failed
if [[ $UBUNTU_RESULT -ne 0 ]] || [[ $ALPINE_RESULT -ne 0 ]]; then
    exit 1
else
    exit 0
fi