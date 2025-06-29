# Ubuntu Test Failure Fixes

## Issues Identified

### 1. Count Parameter Test Failing
**Problem**: `grep -c "ticket_name:"` returns 1 for all cases
**Root Cause**: The grep pattern might be matching incorrectly due to output formatting
**Fix**: Use more explicit pattern with proper whitespace handling:
```bash
# Instead of:
COUNT_1=$(./ticket.sh list --count 1 2>&1 | grep -c "ticket_name:")

# Use:
COUNT_1=$(./ticket.sh list --count 1 2>&1 | grep -E "^[[:space:]]*ticket_name:" | wc -l | tr -d ' ')
```

### 2. sed -i Syntax Differences
**Problem**: macOS uses `sed -i ''` while Linux uses `sed -i`
**Fix**: Detect OS and use appropriate syntax:
```bash
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    sed -i 's/pattern/replacement/' file
elif [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' 's/pattern/replacement/' file
else
    # Try both
    sed -i 's/pattern/replacement/' file 2>/dev/null || \
    sed -i '' 's/pattern/replacement/' file
fi
```

### 3. Git Branch Counting
**Problem**: `git branch | grep -c feature/` may not work reliably
**Fix**: Use `git for-each-ref` for more reliable counting:
```bash
# Instead of:
BRANCHES=$(git branch | grep -c feature/)

# Use:
BRANCHES=$(git for-each-ref --format='%(refname:short)' refs/heads/ | grep -c "^feature/")
```

### 4. Environment Variables
**Problem**: Inconsistent grep behavior across platforms
**Fix**: Set environment variables at test start:
```bash
export LC_ALL=C
export GREP_OPTIONS=""
```

## Applied Fixes

The following fixes have been applied to `test-additional.sh`:

1. Added environment variable settings at the beginning
2. Updated all grep counting to use explicit patterns with `wc -l | tr -d ' '`
3. Replaced all sed -i commands with OS-detection logic
4. Updated git branch counting to use `git for-each-ref`

## Testing the Fixes

1. Run the debug script on Ubuntu to verify system behavior:
   ```bash
   ./debug-ubuntu-issues.sh
   ```

2. Run the updated test:
   ```bash
   ./test-additional.sh
   ```

## Additional Notes

- The close --force functionality should work correctly as the boolean comparison is properly implemented
- The readlink command should work the same on both platforms for basic symlink resolution
- If issues persist, check the debug script output for platform-specific differences