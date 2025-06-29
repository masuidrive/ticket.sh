#!/usr/bin/env bash

# Debug init problems

echo "=== Testing ticket.sh init ==="

# Create test directory
TEST_DIR="test-debug-init-$(date +%s)"
mkdir -p "$TEST_DIR"
cd "$TEST_DIR"

# Copy ticket.sh
cp ../../ticket.sh .

echo -e "\n1. Setting up git repo..."
git init -q
git config user.name "Test"
git config user.email "test@test.com"
echo "test" > README.md
git add . && git commit -q -m "init"
git checkout -q -b develop

echo -e "\n2. Current directory structure before init:"
ls -la

echo -e "\n3. Running ticket.sh init..."
./ticket.sh init

echo -e "\n4. Init output check:"
echo "Exit code: $?"

echo -e "\n5. Directory structure after init:"
ls -la

echo -e "\n6. Checking if tickets directory exists:"
if [[ -d tickets ]]; then
    echo "tickets/ directory exists"
    ls -la tickets/
else
    echo "ERROR: tickets/ directory NOT created"
fi

echo -e "\n7. Checking .ticket-config.yml:"
if [[ -f .ticket-config.yml ]]; then
    echo "Config file exists:"
    cat .ticket-config.yml | head -5
else
    echo "ERROR: .ticket-config.yml NOT created"
fi

echo -e "\n8. Checking .gitignore:"
if [[ -f .gitignore ]]; then
    echo ".gitignore exists:"
    cat .gitignore
else
    echo "ERROR: .gitignore NOT created"
fi

# Cleanup
cd ../..
rm -rf "$TEST_DIR"