# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

gpt-toolkit is a command-line interface for OpenAI's GPT models (GPT-4, GPT-5). It's designed for Unix-style pipe-based workflows and is distributed as a Debian package via PPA.

## Environment Setup

Required environment variables:
- `OPENAI_API_KEY` - Your OpenAI API key
- `OPENAI_ORGANIZATION` - Your OpenAI organization ID (optional)

## Build and Installation

```bash
# Install Python dependencies
make dependencies

# Build and install locally
make
sudo make install

# Build Debian package (requires misc-toolkit from code-faster PPA)
make package version=<version>

# Publish to PPA (requires GPG key for signing)
make publish version=<version>
```

## Core Commands

The toolkit provides four main executables (all in `src/`):

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

### gpt-extract-code
Extracts code from markdown code blocks (strips ```). Used to parse GPT output containing code.

### gpt-to-substack
Transforms GPT output for Substack editor. Generates xte keyboard commands to type formatted text (including bold/italics via Ctrl+b/Ctrl+i).

### gpt-token-length
Counts tokens in stdin using tiktoken for GPT-5/GPT-4 encoding.

### gpt-tokens
Prints token IDs for stdin using tiktoken.

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
2. Test locally with `make dependencies && make && sudo make install`
3. Use `make package version=X.Y.Z` to build the Debian package
4. Package changelog is auto-generated from git log

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

# Extract code from GPT output
echo "Write a Python hello world" | gpt | gpt-extract-code > hello.py
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
