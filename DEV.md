# Developer Documentation

This document contains detailed information for developers working on ticket.sh.

## Architecture Overview

ticket.sh is designed as a self-contained shell script that manages tickets using Git and markdown files. The system follows these principles:

- **Self-contained**: Compiles to a single executable shell script
- **Git-native**: Uses Git for version control and branch management
- **File-based**: Stores tickets as markdown files with YAML frontmatter
- **Cross-platform**: Works on macOS and Linux with Bash 3.2+

## Project Structure

```
ticket-sh/
├── src/
│   └── ticket.sh          # Main script source
├── lib/
│   ├── yaml-sh.sh         # YAML parser library
│   ├── yaml-frontmatter.sh # YAML frontmatter handler
│   └── utils.sh           # Utility functions
├── test/
│   ├── test-helpers.sh    # Shared test utilities
│   ├── test-compat.sh     # Platform compatibility
│   ├── test-basic.sh      # Basic functionality tests
│   ├── test-final.sh      # Comprehensive tests
│   ├── test-additional.sh # Edge case tests
│   ├── test-missing-coverage.sh # Spec compliance tests
│   ├── run-all.sh         # Local test runner
│   └── run-all-on-docker.sh # Docker test runner
├── build.sh               # Build script
├── spec.md                # English specification
├── spec.ja.md             # Japanese specification
└── README.md              # User documentation
```

## Building

The build process combines all source files into a single executable:

```bash
./build.sh
```

This creates `ticket.sh` in the project root by:
1. Starting with the shebang and warning header
2. Including all library files from `lib/`
3. Appending the main script from `src/ticket.sh`
4. Making the output executable

The build script adds an important warning header:
```bash
# IMPORTANT NOTE: This file is generated from source files. DO NOT EDIT DIRECTLY!
# To make changes, edit the source files in src/ directory and run ./build.sh
```

## Development Environment Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/masuidrive/ticket.sh.git
   cd ticket.sh
   ```

2. **Build the script**:
   ```bash
   ./build.sh
   ```

3. **Run tests**:
   ```bash
   test/run-all.sh
   ```

## Code Structure

### Main Components

#### Command Handler (src/ticket.sh)
The main script uses a case statement to route commands:
- `init`: Initialize ticket system
- `new`: Create new ticket
- `list`: List tickets with filters
- `start`: Start work on ticket
- `close`: Complete ticket
- `restore`: Restore current-ticket.md symlink

#### YAML Processing (lib/yaml-sh.sh, lib/yaml-frontmatter.sh)
- Parses YAML frontmatter from markdown files
- Updates YAML fields (timestamps)
- Preserves formatting and comments

#### Utilities (lib/utils.sh)
- Date/time handling
- Git operations
- File manipulation
- Cross-platform compatibility

### Key Functions

#### `init_repo()`
- Creates `.ticket-config.yml`
- Creates `tickets/` directory
- Updates `.gitignore`

#### `create_ticket()`
- Validates slug format
- Generates timestamp-based filename
- Creates ticket file with template

#### `start_ticket()`
- Creates feature branch
- Updates `started_at` timestamp
- Creates `current-ticket.md` symlink

#### `close_ticket()`
- Updates `closed_at` timestamp
- Squash merges to develop
- Moves ticket to `done/` folder

## Testing

### Test Structure

See `test/README.md` for detailed test documentation. Key points:

- **Unit tests**: Test individual commands
- **Integration tests**: Test complete workflows
- **Edge case tests**: Test error conditions
- **Compatibility tests**: Test on different platforms

### Running Tests

```bash
# All tests locally
test/run-all.sh

# Specific test file
test/test-additional.sh

# Docker environments
test/run-all-on-docker.sh
```

### Writing Tests

Tests use helper functions from `test-helpers.sh`:

```bash
# Setup test repository
setup_test_repo "test-dir"

# Get ticket name safely
TICKET=$(safe_get_ticket_name "*feature.md")

# Portable sed
sed_i 's/old/new/' file.txt
```

## Platform Compatibility

### Supported Platforms
- macOS (BSD utilities)
- Linux (GNU utilities)
- Alpine Linux (busybox)

### Compatibility Considerations

1. **Date command**: Use `test-compat.sh` for portable date handling
2. **Sed command**: Use `sed_i` function for in-place editing
3. **Bash version**: Target Bash 3.2+ for macOS compatibility
4. **File paths**: Always use double quotes around variables

### Cross-Platform Testing

```bash
# Ubuntu
docker run --rm -v "$PWD:/workspace" -w /workspace ubuntu:22.04 \
  bash -c "apt-get update && apt-get install -y git && test/run-all.sh"

# Alpine
docker run --rm -v "$PWD:/workspace" -w /workspace alpine:latest \
  sh -c "apk add --no-cache git bash && test/run-all.sh"
```

## Debugging

### Enable Debug Output

Add to any script:
```bash
set -x  # Enable command tracing
```

### Common Issues

1. **Permission errors**: Check file ownership in Docker
2. **Date parsing**: Verify date format compatibility
3. **Git errors**: Ensure clean working directory
4. **Symlink issues**: Check filesystem support

## Contributing

### Code Style

- Use 2-space indentation
- Quote all variables: `"$var"`
- Use `[[ ]]` for conditionals
- Add error checking for commands
- Comment complex logic

### Pull Request Process

1. Create feature branch from `develop`
2. Write/update tests
3. Ensure all tests pass
4. Update documentation
5. Submit PR with clear description

### Testing Requirements

- All tests must pass locally
- Docker tests must pass (Ubuntu + Alpine)
- New features need test coverage
- Edge cases should be tested

## Release Process

1. Merge all features to `develop`
2. Run full test suite
3. Update version in relevant files
4. Build final script: `./build.sh`
5. Create release tag
6. Update release binary

## Security Considerations

- Never commit sensitive data
- Validate all user input
- Use proper quoting to prevent injection
- Test with malicious filenames/content

## Performance Notes

- Minimize subshell usage
- Cache repeated operations
- Use built-in bash features when possible
- Profile with `time` command for bottlenecks

## Future Improvements

Planned enhancements tracked in tickets:
- Better error messages
- Performance optimizations
- Additional command options
- Extended platform support

## Troubleshooting

### Common Problems

1. **"Not in a git repository"**
   - Ensure you're in a git repo
   - Run `git init` if needed

2. **"Ticket system not initialized"**
   - Run `ticket.sh init`
   - Check for `.ticket-config.yml`

3. **"Permission denied"**
   - Check file permissions
   - Ensure script is executable

4. **Test failures**
   - Check git configuration
   - Verify bash version
   - Review test output carefully

### Getting Help

- Check existing tickets for similar issues
- Review test cases for examples
- Submit detailed bug reports with:
  - Platform/OS version
  - Bash version
  - Complete error output
  - Steps to reproduce