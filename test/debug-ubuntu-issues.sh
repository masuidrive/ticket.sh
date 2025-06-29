#!/usr/bin/env bash

# Debug script to identify Ubuntu-specific issues

echo "=== System Information ==="
echo "OS Type: $OSTYPE"
echo "Bash Version: $BASH_VERSION"
echo "grep version: $(grep --version | head -1)"
echo "sed version: $(sed --version 2>&1 | head -1)"
echo "git version: $(git --version)"
echo

echo "=== Testing grep patterns ==="
# Create sample output similar to ticket.sh list
SAMPLE_OUTPUT='📋 Ticket List
---------------------------
- status: todo
  ticket_name: 123456-test-1
  description: Test ticket 1
  priority: 2
  created_at: 2025-01-01T00:00:00Z

- status: todo
  ticket_name: 123457-test-2
  description: Test ticket 2
  priority: 1
  created_at: 2025-01-01T00:01:00Z

- status: doing
  ticket_name: 123458-test-3
  description: Test ticket 3
  priority: 3
  created_at: 2025-01-01T00:02:00Z
  started_at: 2025-01-01T00:03:00Z
'

echo "$SAMPLE_OUTPUT" > test_output.txt

echo "Testing different grep patterns:"
echo "1. grep -c 'ticket_name:' : $(echo "$SAMPLE_OUTPUT" | grep -c 'ticket_name:')"
echo "2. grep 'ticket_name:' | wc -l : $(echo "$SAMPLE_OUTPUT" | grep 'ticket_name:' | wc -l)"
echo "3. grep -E '^[[:space:]]*ticket_name:' | wc -l : $(echo "$SAMPLE_OUTPUT" | grep -E '^[[:space:]]*ticket_name:' | wc -l)"
echo "4. grep -E '^ *ticket_name:' | wc -l : $(echo "$SAMPLE_OUTPUT" | grep -E '^ *ticket_name:' | wc -l)"
echo

echo "=== Testing sed -i variations ==="
echo "Test content" > test_sed.txt
cp test_sed.txt test_sed_backup.txt

echo "Testing sed -i without extension (Linux style):"
if sed -i 's/Test/Modified/' test_sed.txt 2>/dev/null; then
    echo "  Success: sed -i works"
    cat test_sed.txt
else
    echo "  Failed: sed -i doesn't work"
fi

cp test_sed_backup.txt test_sed.txt
echo "Testing sed -i '' (BSD/macOS style):"
if sed -i '' 's/Test/Modified/' test_sed.txt 2>/dev/null; then
    echo "  Success: sed -i '' works"
    cat test_sed.txt
else
    echo "  Failed: sed -i '' doesn't work"
fi

echo

echo "=== Testing git branch parsing ==="
# Create a test git repo
TEST_DIR="debug-git-test-$$"
mkdir "$TEST_DIR"
cd "$TEST_DIR"
git init -q
git config user.name "Test"
git config user.email "test@test.com"
echo "test" > README.md
git add . && git commit -q -m "init"

# Create some branches
git checkout -q -b develop
git checkout -q -b feature/test-1
git checkout -q -b feature/test-2
git checkout -q develop

echo "Testing branch counting methods:"
echo "1. git branch | grep -c feature/ : $(git branch | grep -c feature/)"
echo "2. git branch | grep feature/ | wc -l : $(git branch | grep feature/ | wc -l)"
echo "3. git for-each-ref refs/heads/ | grep -c feature/ : $(git for-each-ref --format='%(refname:short)' refs/heads/ | grep -c feature/)"
echo "4. git branch --list 'feature/*' | wc -l : $(git branch --list 'feature/*' | wc -l)"

echo
echo "Current branch detection:"
echo "1. git branch --show-current : '$(git branch --show-current)'"
echo "2. git rev-parse --abbrev-ref HEAD : '$(git rev-parse --abbrev-ref HEAD)'"

cd ..
rm -rf "$TEST_DIR"

echo

echo "=== Testing readlink behavior ==="
# Create a test symlink
echo "target content" > test_target.txt
ln -s test_target.txt test_link.txt

echo "Testing readlink:"
echo "1. readlink test_link.txt : '$(readlink test_link.txt)'"
echo "2. readlink -f test_link.txt : '$(readlink -f test_link.txt 2>/dev/null || echo "readlink -f not supported")'"
echo "3. ls -l test_link.txt : '$(ls -l test_link.txt)'"

# Cleanup
rm -f test_output.txt test_sed.txt test_sed_backup.txt test_target.txt test_link.txt

echo
echo "=== Testing bash boolean comparison ==="
force=false
echo "force=false"
echo "Testing [[ \"\$force\" == \"false\" ]] : $(if [[ "$force" == "false" ]]; then echo "true"; else echo "false"; fi)"
echo "Testing [[ \$force == false ]] : $(if [[ $force == false ]]; then echo "true"; else echo "false"; fi)"

force=true
echo "force=true"
echo "Testing [[ \"\$force\" == \"true\" ]] : $(if [[ "$force" == "true" ]]; then echo "true"; else echo "false"; fi)"
echo "Testing [[ \$force == true ]] : $(if [[ $force == true ]]; then echo "true"; else echo "false"; fi)"

echo
echo "=== Environment variables ==="
echo "LC_ALL: $LC_ALL"
echo "LANG: $LANG"
echo "GREP_OPTIONS: $GREP_OPTIONS"

echo
echo "=== Done ==="