# GPT Command-Line Toolkit

A Unix-style command-line interface for OpenAI's GPT models (GPT-4, GPT-5). Designed for pipe-based workflows and text filtering.

## Requirements

1. Linux
2. Python 3.6 and above

## Installation

### From APT
```bash
$ sudo add-apt-repository ppa:code-faster/ppa
$ sudo apt update
$ sudo apt install gpt-toolkit
```

### From Source
Make sure you have python3 and the misc-toolkit installed:
```bash
$ sudo add-apt-repository ppa:code-faster/ppa
$ sudo apt update
$ sudo apt install misc-toolkit
$ git clone git@github.com:tyleradams/gpt-toolkit.git
$ cd gpt-toolkit
$ make dependencies
$ make
$ sudo make install
```

## Setup

Set your OpenAI API credentials in your environment:
```bash
export OPENAI_API_KEY="your-api-key"
export OPENAI_ORGANIZATION="your-org-id"  # optional
```

## Usage

### gpt

The primary command. Reads prompt from stdin, sends to GPT API, outputs to stdout.

#### Basic Examples

```bash
# Simple usage (uses GPT-5 by default)
$ echo "Count from 1 to 10" | gpt
1, 2, 3, 4, 5, 6, 7, 8, 9, 10

# Use GPT-4
$ echo "What is 2+2?" | gpt -4

# Use GPT-5 variants
$ echo "Hello" | gpt --mini    # gpt-5-mini (faster, cheaper)
$ echo "Hello" | gpt --nano    # gpt-5-nano (fastest, cheapest)

# File input
$ cat prompt.txt | gpt
$ gpt -f prompt.txt
```

#### GPT-5 Reasoning Control

GPT-5 models support controlling reasoning effort and output verbosity:

```bash
# Fast responses for simple tasks
$ echo "What is the capital of France?" | gpt --reasoning-effort minimal

# Deep reasoning for complex problems
$ echo "Solve this complex math problem..." | gpt --reasoning-effort high

# Control output length
$ echo "Explain quantum computing" | gpt --verbosity low   # concise
$ echo "Explain quantum computing" | gpt --verbosity high  # comprehensive
```

Reasoning effort levels:
- `minimal` - Fast, minimal thinking
- `low` - Light reasoning
- `medium` - Balanced (default)
- `high` - Maximum quality, more thinking

#### REPL Mode

Interactive conversation mode:
```bash
$ gpt --repl
GPT REPL Mode (model: gpt-5). Type 'exit' to quit.
> What is 2+2?
4
> And what's that plus 3?
7
> exit
```

#### Advanced Usage

```bash
# Combine prompt with file content
$ (echo "Summarize this:"; cat document.txt) | gpt

# Chain commands
$ seq 10 | (echo "Sum these numbers:"; cat) | gpt

# Overwrite file with GPT output
$ cp file.txt file.txt.bak && cat prompt file.txt | gpt > temp && mv temp file.txt

# Process multiple files in parallel
$ for f in $(cat files.txt); do
    cp "$f" "$f.bak" && cat prompt "$f" | gpt > "$f.tmp" && mv "$f.tmp" "$f" &
  done
  wait

# Extract code from GPT response
$ echo "Write a Python hello world" | gpt | gpt-extract-code > hello.py

# Use as shebang
$ cat > script.gpt << 'EOF'
#!/usr/bin/env -S gpt -m gpt-5 -f
Write a bash function that prints "Hello, World!"
EOF
$ chmod +x script.gpt
$ ./script.gpt
```

### gpt-to-substack

Transform GPT output for Substack editor (generates xte keyboard commands):

```bash
$ echo "Write a blog post about AI" | gpt | gpt-to-substack | xte
```

### gpt-extract-code

Extract code blocks from markdown (strips ``` delimiters):

```bash
$ echo "Write Python code to sort a list" | gpt | gpt-extract-code > sort.py
```

### gpt-token-length

Count tokens in text:

```bash
$ echo "Hello world" | gpt-token-length
2
```

## Command-Line Options

### gpt

**Model selection:**
- `-m, --model MODEL` - Specify model (default: gpt-5)
- `-4` - Use gpt-4
- `-5` - Use gpt-5 (default)
- `--mini` - Use gpt-5-mini
- `--nano` - Use gpt-5-nano

**GPT-5 specific:**
- `--reasoning-effort LEVEL` - minimal, low, medium (default), high
- `--verbosity LEVEL` - low, medium (default), high
- `--max-completion-tokens N` - Maximum tokens to generate

**Other parameters:**
- `--temperature FLOAT` - Sampling temperature 0-2 (default: 1.0)
- `--top-p FLOAT` - Nucleus sampling (default: 1.0)
- `--stop TEXT` - Stop sequences

**Modes:**
- `--repl` - Interactive conversation mode
- `-f FILE` - Read prompt from file instead of stdin

## Examples by Use Case

### Code Generation
```bash
# Generate and save code
$ echo "Write a Python function to reverse a string" | gpt | gpt-extract-code > reverse.py

# Generate with high reasoning for complex logic
$ echo "Implement a binary search tree in Python" | gpt --reasoning-effort high | gpt-extract-code > bst.py
```

### Text Processing
```bash
# Summarize documents
$ cat long-document.txt | (echo "Summarize this:"; cat) | gpt --verbosity low

# Translate
$ echo "Translate to French: Hello, how are you?" | gpt
```

### Batch Processing
```bash
# Process all markdown files
$ for f in *.md; do
    echo "Processing $f..."
    (echo "Improve this documentation:"; cat "$f") | gpt > "$f.new" && mv "$f.new" "$f"
  done
```

### Quick Answers
```bash
# Fast responses
$ echo "What is 15% of 200?" | gpt --reasoning-effort minimal
```

## Design Philosophy

This toolkit follows Unix philosophy:
- **Text in, text out** - Simple stdin/stdout interface
- **Do one thing well** - Each tool has a focused purpose
- **Composable** - Tools work together via pipes
- **Scripting-friendly** - Easy to integrate in shell scripts

## Notes

- Reasoning tokens (for GPT-5) count toward output token usage
- Set `temperature=0` for deterministic outputs
- The API is non-deterministic by default

## Feedback

File bugs, questions, or feature requests on [GitHub](https://github.com/tyleradams/gpt-toolkit), or email tyler@blitzblitzblitz.com
