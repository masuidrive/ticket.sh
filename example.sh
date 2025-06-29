#!/usr/bin/env bash

# Example usage of yaml-sh library

# Source the library
source ./yaml-sh.sh

echo "=== Example 1: Basic Usage ==="
echo

# Parse a YAML file
yaml_parse "test-config.yaml"

# Get specific values
echo "App name: $(yaml_get "app.name")"
echo "App version: $(yaml_get "app.version")"
echo "Database host: $(yaml_get "database.host")"
echo "Database user: $(yaml_get "database.credentials.user")"

echo
echo "=== Example 2: Working with Lists ==="
echo

# Get list items
echo "First server: $(yaml_get "servers.0.name")"
echo "Server roles:"
echo "  - $(yaml_get "servers.0.roles.0")"
echo "  - $(yaml_get "servers.0.roles.1")"

# Get list size
server_count=$(yaml_list_size "servers")
echo "Total servers: $server_count"

echo
echo "=== Example 3: Loading into Variables ==="
echo

# Load YAML into variables with prefix
yaml_load "test-simple.yaml" "my"

# Access values from variables
echo "Name from variable: $my_name"
echo "City from variable: $my_address_city"

echo
echo "=== Example 4: Searching and Filtering ==="
echo

# Search for keys matching a pattern
echo "All database-related keys:"
yaml_search "database" | head -5

echo
echo "Keys under 'logging' prefix:"
yaml_get_prefix "logging" | head -5

echo
echo "=== Example 5: Practical Use Case ==="
echo

# Parse configuration and use it
yaml_parse "test-config.yaml"

# Check if debug mode is enabled
if [[ "$(yaml_get "app.debug")" == "true" ]]; then
    echo "Debug mode is ON"
else
    echo "Debug mode is OFF"
fi

# Iterate through servers
echo
echo "Server configuration:"
for i in $(seq 0 $(($(yaml_list_size "servers") - 1))); do
    name=$(yaml_get "servers.$i.name")
    host=$(yaml_get "servers.$i.host")
    max_conn=$(yaml_get "servers.$i.config.max_connections")
    
    echo "  $name ($host) - Max connections: $max_conn"
done