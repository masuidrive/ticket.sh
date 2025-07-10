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
│   ├── test-*.sh          # Feature-specific test files
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
bash ./build.sh
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
   bash ./build.sh
   ```

3. **Run tests**:
   ```bash
   bash ./test/run-all.sh
   ```

## Code Structure

### Main Components

#### Command Handler (src/ticket.sh)
The main script uses a case statement to route commands:
- `init`: Initialize ticket system
- `new`: Create new ticket
- `list`: List tickets with filters and options
- `start`: Start work on ticket
- `close`: Complete ticket
- `restore`: Restore current-ticket.md symlink
- `check`: Diagnose current state and provide guidance
- `version`: Display version information
- `selfupdate`: Update to latest release from GitHub

#### YAML Processing (lib/yaml-sh.sh, lib/yaml-frontmatter.sh)
- Parses YAML frontmatter from markdown files
- Updates YAML fields (timestamps)
- Preserves formatting and comments

#### Utilities (lib/utils.sh)
- Date/time handling and timezone conversion
- Git operations with output display
- File manipulation and validation
- Cross-platform compatibility
- Dynamic command name detection

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
- Removes current-ticket.md from git history
- Squash merges to default branch
- Moves ticket to `done/` folder
- Optional remote branch cleanup

## Testing

### Test Structure

See `test/README.md` for detailed test documentation. Key points:

- **Unit tests**: Test individual commands and features
- **Integration tests**: Test complete workflows
- **Edge case tests**: Test error conditions and boundary cases
- **Compatibility tests**: Test on different platforms and environments
- **UTF-8 tests**: Test Unicode support and international characters
- **Timezone tests**: Test date/time conversion functionality

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

1. **Date command**: Supports both GNU date (Linux) and BSD date (macOS) for timezone conversion
2. **Sed command**: Use `sed_i` function for in-place editing
3. **Bash version**: Target Bash 3.2+ for macOS compatibility
4. **File paths**: Always use double quotes around variables
5. **Process detection**: Uses `/proc/self/cmdline` on Linux, `ps` command on macOS for dynamic command names
6. **UTF-8 support**: Automatic locale setting (LANG=C.UTF-8) for consistent Unicode handling

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
2. **Date parsing**: Verify date format compatibility and timezone handling
3. **Git errors**: Ensure clean working directory
4. **Symlink issues**: Check filesystem support
5. **UTF-8 issues**: Verify locale settings and character encoding
6. **Command detection**: Test dynamic command name detection on different shells

## Contributing

### Code Style

- Use 2-space indentation
- Quote all variables: `"$var"`
- Use `[[ ]]` for conditionals
- Add error checking for commands
- Comment complex logic

### Documentation Requirements

**IMPORTANT**: When making code changes, always update relevant documentation:

1. **User-facing changes**: Update README.md and README.ja.md
2. **New features**: Add to both English and Japanese documentation
3. **API changes**: Update this DEV.md file
4. **Command changes**: Update help text and usage examples
5. **Configuration changes**: Update config documentation

Documentation updates should be part of the same PR as code changes.

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

## Architecture Features

### Key Design Decisions

1. **Self-contained**: Single executable script with inlined dependencies
2. **Git-native**: Leverages Git for branch management and version control
3. **Markdown-based**: Human-readable ticket format with YAML frontmatter
4. **Timezone-aware**: Converts UTC timestamps to local timezone for display
5. **Error recovery**: Comprehensive diagnostic and recovery commands
6. **Cross-platform**: Works consistently across different Unix-like systems

### Recent Enhancements

- **Smart branch handling**: Automatically handles existing branches and clean states
- **Dynamic command detection**: Shows actual invocation method in help messages
- **UTF-8 support**: Full Unicode support for international users
- **Done folder organization**: Automatic organization of completed tickets
- **Git history protection**: Prevents accidental commits of working files

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