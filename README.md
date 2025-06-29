# yaml-sh: Pure Bash YAML Parser

A lightweight YAML parser implemented in pure Bash script with no external dependencies except AWK (which is available on all POSIX systems).

## Requirements

- Bash 4.0+ (for associative array support)
- AWK (standard POSIX tool)

## Features

- ✓ Pure Bash implementation
- ✓ No external libraries required
- ✓ Supports nested structures
- ✓ Supports lists and inline lists
- ✓ Supports multiline strings (| and > with modifiers)
- ✓ Supports comments
- ✓ Dot notation for accessing nested values
- ✓ Load YAML data into associative arrays

## Installation

Simply source the `yaml-sh.sh` file in your script:

```bash
source /path/to/yaml-sh.sh
```

## Usage

### Basic Example

```bash
#!/usr/bin/env bash
source ./yaml-sh.sh

# Parse a YAML file
yaml_parse "config.yaml"

# Get values
name=$(yaml_get "app.name")
port=$(yaml_get "server.port")
```

### API Reference

#### `yaml_parse "file.yaml"`
Parse a YAML file and load data into internal storage.

#### `yaml_get "key.path"`
Get a value by its dot-notation path.

#### `yaml_load "file.yaml" array_name`
Load YAML data directly into an associative array.

```bash
declare -A config
yaml_load "config.yaml" config
echo "${config[database.host]}"
```

#### `yaml_keys`
List all available keys.

#### `yaml_dump`
Dump all key-value pairs.

#### `yaml_search "pattern"`
Search for keys matching a regex pattern.

#### `yaml_get_prefix "prefix"`
Get all keys with a specific prefix.

#### `yaml_has_key "key"`
Check if a key exists.

#### `yaml_list_size "list.path"`
Get the number of items in a list.

#### `yaml_clear`
Clear all loaded data.

## Supported YAML Features

### Basic Key-Value
```yaml
name: John Doe
age: 30
```

### Nested Structures
```yaml
database:
  host: localhost
  port: 5432
  credentials:
    user: admin
    pass: secret
```

### Lists
```yaml
# Hyphen format
fruits:
  - apple
  - banana
  - orange

# Inline format
colors: [red, green, blue]

# List of objects
users:
  - name: Alice
    age: 25
  - name: Bob
    age: 30
```

### Multiline Strings
```yaml
# Literal style (preserves newlines)
description: |
  Line 1
  Line 2
  
# Folded style (newlines become spaces)
summary: >
  This is a long
  text that spans
  multiple lines
```

### Comments
```yaml
# This is a comment
key: value  # Inline comment
```

## Data Access

Data is accessed using dot notation:

```yaml
# YAML structure
app:
  database:
    host: localhost
    ports:
      - 5432
      - 5433

# Access in Bash
host=$(yaml_get "app.database.host")        # "localhost"
port1=$(yaml_get "app.database.ports.0")    # "5432"
port2=$(yaml_get "app.database.ports.1")    # "5433"
```

## Examples

See `example.sh` for practical usage examples.

## Testing

Run the test suite:

```bash
./test.sh
```

## Limitations

- No support for YAML anchors and aliases
- No support for tags
- All values are stored as strings (no type information)
- Limited error handling (invalid syntax is skipped)

## License

MIT License