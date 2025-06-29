#!/usr/bin/env bash

source ./yaml-sh.sh

echo "=== Parsing test-simple.yaml ==="
_yaml_parse_awk "test-simple.yaml" | head -20

echo
echo "=== Parsing test-lists.yaml ==="
_yaml_parse_awk "test-lists.yaml" | head -20

echo
echo "=== Test yaml_parse on test-user.yaml ==="
yaml_parse "test-user.yaml"
echo "Keys: ${_YAML_KEYS[@]}"
echo
echo "Values:"
for i in "${!_YAML_KEYS[@]}"; do
    echo "${_YAML_KEYS[$i]} = ${_YAML_VALUES[$i]}"
done

echo
echo "=== Test specific keys ==="
echo "tickets_dir: $(yaml_get "tickets_dir")"
echo "default_branch: $(yaml_get "default_branch")"
echo "default_content: $(yaml_get "default_content")"