**IMPORTANT**: When updating this file, also update README.md files in other languages

- [English ver.](README.md)
- [Japanese ver.](README.ja.md)

---
# yaml-sh

A simple, portable YAML parser for Bash 3.2+ that provides basic YAML parsing capabilities without external dependencies.

## Features

- **Pure Bash/AWK**: No external dependencies required
- **Bash 3.2+ Compatible**: Works on macOS and older Linux systems
- **Simple API**: Easy-to-use functions for parsing and accessing YAML data
- **Multiline String Support**: Handles literal (`|`) and folded (`>`) multiline strings
- **List Support**: Both dash notation and inline lists
- **Comment Preservation**: Maintains comments when updating values
- **Update Capability**: Can update simple key-value pairs

## Installation

```bash
# Download the script
curl -O https://raw.githubusercontent.com/yourusername/yaml-sh/main/yaml-sh
chmod +x yaml-sh

# Or source it in your script
source yaml-sh
```

## Usage

### Basic Example

```bash
#!/usr/bin/env bash
source yaml-sh

# Parse a YAML file
yaml_parse "config.yml"

# Get a value
name=$(yaml_get "name")
echo "Name: $name"

# Check if a key exists
if yaml_has_key "database.host"; then
    echo "Database host: $(yaml_get 'database.host')"
fi

# List all keys
yaml_keys

# Update a value
yaml_update "config.yml" "version" "2.0.0"
```

### Working with Lists

```yaml
# config.yml
tags:
  - development
  - testing
  - production
```

```bash
# Get list size
size=$(yaml_list_size "tags")
echo "Number of tags: $size"

# Access list items
for i in $(seq 0 $((size - 1))); do
    tag=$(yaml_get "tags.$i")
    echo "Tag $i: $tag"
done
```

### Loading into Environment Variables

```bash
# Load all values as environment variables
yaml_load "config.yml" "CONFIG"

# Access as variables
echo "$CONFIG_name"
echo "$CONFIG_version"
```

## API Reference

### Functions

- **`yaml_parse <file>`** - Parse a YAML file
- **`yaml_get <key>`** - Get value by key
- **`yaml_keys`** - List all keys
- **`yaml_has_key <key>`** - Check if key exists (returns 0 if exists)
- **`yaml_list_size <prefix>`** - Get size of a list
- **`yaml_load <file> [prefix]`** - Load YAML into environment variables
- **`yaml_update <file> <key> <value>`** - Update a top-level single-line value

## Supported YAML Syntax

### Key-Value Pairs
```yaml
name: My Application
version: 1.0.0
debug: true
```

### Lists
```yaml
# Dash notation
items:
  - first
  - second
  - third

# Inline notation
colors: [red, green, blue]
```

### Multiline Strings
```yaml
# Literal style (preserves newlines)
description: |
  This is a multiline
  description that preserves
  line breaks.

# Folded style (converts newlines to spaces)
summary: >
  This is a folded
  multiline string that
  becomes a single line.

# Strip final newline
stripped: |-
  No final newline

# Keep all trailing newlines
preserved: |+
  Keeps trailing newlines


```

### Quoted Strings
```yaml
single: 'Single quoted string'
double: "Double quoted string"
```

### Comments
```yaml
# This is a comment
key: value  # Inline comment
```

## Limitations

- **No Nested Objects**: Only flat structures are supported
- **No Complex Types**: No support for anchors, aliases, or tags
- **Basic Multiline**: Some edge cases in multiline strings may not be handled perfectly
- **Simple Updates Only**: `yaml_update` only works with simple key-value pairs

## Examples

### Configuration File Parser

```bash
#!/usr/bin/env bash
source yaml-sh

# Parse application config
yaml_parse "app.yml"

# Get configuration values
APP_NAME=$(yaml_get "name")
APP_PORT=$(yaml_get "port")
APP_DEBUG=$(yaml_get "debug")

# Start application
if [[ "$APP_DEBUG" == "true" ]]; then
    echo "Starting $APP_NAME in debug mode on port $APP_PORT"
else
    echo "Starting $APP_NAME on port $APP_PORT"
fi
```

### Docker Compose Parser

```bash
#!/usr/bin/env bash
source yaml-sh

# Parse docker-compose.yml
yaml_parse "docker-compose.yml"

# List all services
echo "Services:"
yaml_keys | grep -E "^services\." | cut -d. -f2 | sort | uniq
```

## ticket-sh: A Practical Application

This repository includes `ticket-sh`, a Git-based ticket management system that demonstrates yaml-sh in action:

```bash
cd ticket-sh
./build.sh  # Creates a single deployable script
./ticket.sh init
./ticket.sh new implement-feature
./ticket.sh start 241229-123456-implement-feature
# ... do work ...
./ticket.sh close
```

See [ticket-sh/README.md](ticket-sh/README.md) for more details.

## Testing

```bash
# Run yaml-sh tests
./test.sh

# Run ticket-sh tests
cd ticket-sh
./test-final.sh
./test-additional.sh
```

## Contributing

Contributions are welcome! Please ensure that any changes maintain compatibility with Bash 3.2 and don't introduce external dependencies.

## License

MIT License - see LICENSE file for details.

## Acknowledgments

Created for use in shell-based automation tools where a lightweight YAML parser is needed without external dependencies.