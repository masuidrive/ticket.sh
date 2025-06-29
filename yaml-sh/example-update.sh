#!/usr/bin/env bash

# Example of using yaml_update function

source ./yaml-sh.sh

# Create a sample config file
cat > config.yaml << 'EOF'
# Application configuration
app_name: MyApp
version: 1.0.0  # Current version
debug: false

# Database settings
db_host: localhost
db_port: 5432  # PostgreSQL default

# API configuration  
api_key: secret123
timeout: 30  # seconds

# This should not be updated
description: |
  This is a multiline
  description
EOF

echo "=== Original config.yaml ==="
cat config.yaml
echo

# Update some values
echo "=== Updating values ==="
yaml_update config.yaml "version" "1.1.0"
echo "Updated version to 1.1.0"

yaml_update config.yaml "debug" "true"
echo "Updated debug to true"

yaml_update config.yaml "timeout" "60"
echo "Updated timeout to 60"

echo
echo "=== Updated config.yaml ==="
cat config.yaml

# Clean up
rm -f config.yaml