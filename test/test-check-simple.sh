#!/usr/bin/env bash

# Simple test for check command
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TICKET_SH="$SCRIPT_DIR/../ticket.sh"

echo "=== Simple Check Command Test ==="

# Test 1: Check help shows check command
echo "1. Testing help includes check command..."
if "$TICKET_SH" help | grep -q "check.*Check current directory"; then
    echo "  ✓ Check command appears in help"
else
    echo "  ✗ Check command missing from help"
    exit 1
fi

# Test 2: Check command exists
echo "2. Testing check command exists..."
output=$("$TICKET_SH" check 2>&1 || true)
if [[ "$output" =~ "not a git repository" ]] || [[ "$output" =~ "No active ticket" ]] || [[ "$output" =~ "unknown branch" ]] || [[ "$output" =~ "Current ticket is active" ]] || [[ "$output" =~ "Found matching ticket" ]]; then
    echo "  ✓ Check command responds appropriately"
else
    echo "  ✗ Check command unexpected response: $output"
    exit 1
fi

echo "All simple tests passed!"