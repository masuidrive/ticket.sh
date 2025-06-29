# yaml-sh Project

This repository contains two independent but related shell script projects:

## 📁 Project Structure

```
.
├── build.sh          # Build script for ticket.sh
├── ticket.sh         # Built ticket management executable
├── ticket-sh/        # Ticket management system source
│   ├── README.md     # Detailed documentation
│   ├── spec.md       # English specification
│   ├── spec.ja.md    # Japanese specification
│   ├── lib/          # Library files
│   ├── src/          # Source code
│   └── test/         # Test suites
└── yaml-sh/          # YAML parser
    ├── README.md     # Detailed documentation
    ├── yaml-sh       # Executable
    ├── yaml-sh.sh    # Source code
    └── test.sh       # Test suite
```

## 🚀 Quick Start

### yaml-sh - YAML Parser

A simple, portable YAML parser for Bash 3.2+:

```bash
cd yaml-sh
source yaml-sh.sh

# Parse YAML
yaml_parse "config.yml"
value=$(yaml_get "key")
```

See [yaml-sh/README.md](yaml-sh/README.md) for full documentation.

### ticket.sh - Ticket Management System

Git-based ticket management for developers:

```bash
# Build from source
./build.sh

# Or use pre-built
./ticket.sh init
./ticket.sh new implement-feature
./ticket.sh start 241229-123456-implement-feature
./ticket.sh close
```

See [ticket-sh/README.md](ticket-sh/README.md) for full documentation.

## 📋 Features

**yaml-sh:**
- Pure Bash/AWK implementation
- No external dependencies
- Supports basic YAML syntax
- Multiline strings (literal and folded)
- Lists and inline lists
- Comment preservation

**ticket.sh:**
- Git Flow integration
- Markdown + YAML frontmatter
- Single executable file
- Branch automation
- No external services needed

## 🛠️ Development

### Building ticket.sh

```bash
./build.sh
# Creates ticket.sh executable
```

### Running Tests

```bash
# yaml-sh tests
cd yaml-sh && ./test.sh

# ticket.sh tests
cd ticket-sh/test && ./test-final.sh
```

## 📄 License

MIT License - see individual project directories for details.

## 🤝 Contributing

Contributions welcome! Please ensure compatibility with Bash 3.2+ and avoid external dependencies.