#!/usr/bin/env bash

source ./yaml-sh-v2.sh

echo "=== Test multiline string ==="
yaml_parse "test-user.yaml"
echo "tickets_dir: $(yaml_get "tickets_dir")"
echo "default_content:"
echo "$(yaml_get "default_content")"

echo
echo "=== Test lists ==="
yaml_parse "test-lists.yaml"
echo "fruits.0: $(yaml_get "fruits.0")"
echo "fruits.1: $(yaml_get "fruits.1")"
echo "fruits.2: $(yaml_get "fruits.2")"
echo "List size: $(yaml_list_size "fruits")"

echo
echo "=== Test inline lists ==="
echo "colors.0: $(yaml_get "colors.0")"
echo "colors.1: $(yaml_get "colors.1")"
echo "colors.2: $(yaml_get "colors.2")"

echo
echo "=== All parsed data ==="
yaml_dump | head -20