#!/usr/bin/env bash

# Setup test environment for selfupdate

echo "Setting up selfupdate test..."

# Create test version of ticket.sh
cp ticket.sh test-ticket.sh
chmod +x test-ticket.sh

# Create "new version" with different version number
cp ticket.sh test-new-version.sh
sed -i '' 's/# Version: 1.0.0/# Version: 2.0.0-test/' test-new-version.sh

# Modify test-ticket.sh to use local file instead of GitHub
sed -i '' 's|https://raw.githubusercontent.com/masuidrive/ticket.sh/main/ticket.sh|file://'"$(pwd)"'/test-new-version.sh|' test-ticket.sh

echo "✅ Test setup complete!"
echo ""
echo "To test selfupdate:"
echo "1. Check current version: grep 'Version:' test-ticket.sh | head -1"
echo "2. Run update: ./test-ticket.sh selfupdate"
echo "3. Wait 2 seconds for update to complete"
echo "4. Check new version: grep 'Version:' test-ticket.sh | head -1"
echo ""
echo "Expected: Version changes from 1.0.0 to 2.0.0-test"