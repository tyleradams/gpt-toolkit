# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

gpt-toolkit (v3.0.0) is a command-line interface for OpenAI's GPT models (GPT-4, GPT-5). It's designed for Unix-style pipe-based workflows and is distributed as a Debian package via PPA.

**Current Version**: 3.0.0 (see VERSION file)

**Version 3.0 Changes**: Simplified to a single `gpt` executable with all functionality built-in. Token counting is now available via `--tokens` flag. The utilities gpt-extract-code, gpt-to-substack, gpt-token-length, and gpt-tokens have been removed.

## Environment Setup

Required environment variables:
- `OPENAI_API_KEY` - Your OpenAI API key
- `OPENAI_ORGANIZATION` - Your OpenAI organization ID (optional)

## Build and Installation

```bash
# Install Python dependencies
make dependencies

# Run tests
make test

# Build and install locally
make
sudo make install

# Build Debian package (requires misc-toolkit from code-faster PPA)
make package version=<version>

# Publish to PPA (requires GPG key for signing)
make publish version=<version>
```

## Core Commands

The toolkit provides a single executable: `gpt` (in `src/`).

### gpt
The primary GPT interface. Takes input via stdin or file, outputs to stdout.

**Basic usage:**
```bash
# Use GPT-5 (default)
echo "prompt" | gpt

# Use GPT-4
echo "prompt" | gpt -4

# Use GPT-5 variants
echo "prompt" | gpt --mini    # gpt-5-mini (faster, cheaper)
echo "prompt" | gpt --nano    # gpt-5-nano (fastest, cheapest)

# File input mode
gpt -f prompt.txt

# REPL mode for conversations
gpt --repl

# Token counting (no API call, outputs JSON)
echo "text" | gpt --tokens

# PDF attachment (requires vision-capable model)
echo "Summarize this document" | gpt --pdf file.pdf -m gpt-4o
```

**GPT-5 specific flags:**
- `--reasoning-effort` (minimal, low, medium, high) - Controls thinking time. Default: medium
- `--verbosity` (low, medium, high) - Controls output length. Default: medium
- `--max-completion-tokens` - Maximum tokens to generate

**Other flags:**
- `--temperature` - Sampling temperature (0-2)
- `--top-p` - Nucleus sampling parameter
- `--stop` - Stop sequences
- `-m, --model` - Specify model explicitly
- `--tokens` - Count tokens in input (outputs JSON with token_count, token_ids, and model)
- `--pdf FILE` - Attach PDF file(s) to prompt (can be used multiple times)

## Architecture

**Core design**: Unix philosophy - small tools that do one thing well, composable via pipes.

**Main script** (`src/gpt`):
- Python 3 with Click for CLI
- Uses modern OpenAI SDK (>= 1.0.0) with `OpenAI().chat.completions.create()`
- Default model: `gpt-5`
- Supports GPT-5 specific parameters: `reasoning_effort` and `verbosity`
- Supports conversation history in REPL mode
- Key parameters exposed as CLI flags

**Key implementation details**:
- `gpt()` function (line 9): Core API wrapper that manages conversation history
- REPL mode (line 78-101): Maintains conversation state with error handling
- Filter mode (line 103-118): Standard stdin/stdout text filter
- GPT-5 parameters only applied to gpt-5 and o-series models (line 32-36)

**Debian packaging**:
- Uses debuild/debsign workflow
- Changelog auto-generated from git via `git-to-changelog` (from misc-toolkit)
- Published to code-faster PPA

## Development Workflow

The package version is managed in debian/changelog. When making changes:
1. Make code changes in `src/`
2. Run tests with `make test`
3. Test locally with `make dependencies && make && sudo make install`
4. Use `make package version=X.Y.Z` to build the Debian package
5. Package changelog is auto-generated from git log

## Testing

The project includes three levels of testing:

### 1. Unit Tests

Test the CLI functionality (`tests/test_gpt.py`):

```bash
# Run unit tests
make test
# Or: ./tests/test_gpt.py
```

Tests verify:
- CLI argument parsing
- Help/version display
- Model selection flags
- GPT-5 specific parameters (reasoning-effort, verbosity)
- Error handling for invalid inputs
- File input validation

### 2. Local Pre-Publish Tests

**IMPORTANT**: Always run this BEFORE publishing to Launchpad PPA.

Test that the package builds and installs correctly (`tests/test_local_build.sh`):

```bash
# Build package first
make package version=X.Y.Z

# Test locally (builds binary .deb in clean Docker)
make test-local
```

This test:
- Builds binary .deb in clean Ubuntu Jammy Docker container
- Installs the .deb with all dependencies
- Runs all 14 integration tests
- **Takes ~2-5 minutes** (much faster than waiting 30min for Launchpad)
- Catches build/install issues before publishing

**Publishing Workflow**:
1. `make package version=X.Y.Z` - Build source package
2. `make test-local` - Test locally (catches issues immediately)
3. `make publish version=X.Y.Z` - Publish to Launchpad (only if test passes)
4. Wait ~30 minutes for Launchpad to build
5. `make test-debian` - Final verification from PPA

### 3. PPA Integration Tests

Test the published package from the PPA (`tests/test_debian_install.sh`):

```bash
# Test installation from code-faster PPA in Docker (requires Docker)
make test-debian
# Or: ./tests/test_debian_install.sh
```

This test:
- Creates a clean Ubuntu Jammy container (no cache)
- Adds the PPA and installs gpt-toolkit
- Runs comprehensive checks:
  - Version identification
  - gpt command in PATH
  - Help flags work
  - Man pages installed
  - Python dependencies (click, openai, tiktoken, readline)
  - Functionality tests (default model, token counting, PDF support)

## Common Use Cases

Pipeline examples:
```bash
# Simple filter
echo "Count from 1 to 10" | gpt

# With reasoning control (for complex tasks)
echo "Solve this math problem..." | gpt --reasoning-effort high

# Fast responses (for simple tasks)
echo "Summarize this" | gpt --reasoning-effort minimal --verbosity low

# Overwrite file with GPT output
cp file file.bak && cat prompt file | gpt > temp && mv temp file

# Parallel processing on multiple files
for f in $(cat files.txt); do
  cp "$f" "$f.bak" && cat prompt "$f" | gpt > "$f.tmp" && mv "$f.tmp" "$f" &
done
wait

# Shebang usage
#!/usr/bin/env -S gpt -m gpt-5 -f
Print out 1 to 10

# Token counting
echo "How many tokens?" | gpt --tokens
```

## Dependencies

Core Python packages (requirements.txt):
- click>=8.0.4 - CLI framework
- openai>=1.0.0 - OpenAI API (modern SDK)
- tiktoken>=0.4.0 - Token counting
- readline>=6.2.4.1 - REPL support

## GPT-5 Reasoning Models

GPT-5 models include built-in reasoning capabilities:
- **reasoning_effort**: Controls how much the model thinks before responding
  - `minimal`: Fast, minimal reasoning
  - `low`: Light reasoning
  - `medium`: Balanced (default)
  - `high`: Maximum quality, more thinking tokens
- **verbosity**: Controls output length independently of reasoning
  - `low`: Concise answers
  - `medium`: Balanced (default)
  - `high`: Comprehensive answers

Reasoning tokens count toward output token usage and billing.
