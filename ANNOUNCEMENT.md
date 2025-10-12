# gpt-toolkit: CLI for OpenAI GPT Models

Hey folks! 👋

I'm excited to share **gpt-toolkit** - a clean, Unix-style command-line interface for GPT models that's now properly packaged, tested, and maintained.

## What is it?

A simple CLI that treats GPT like any other Unix text filter. Pipe text in, get GPT's response out:

```bash
echo "Explain quantum computing in one sentence" | gpt
```

## Why would I use this?

- **True Unix philosophy**: Pipes, stdin/stdout, composable with other tools
- **Zero config on Ubuntu**: `apt-get install gpt-toolkit` and you're done
- **GPT-5 by default** with reasoning controls (--reasoning-effort, --verbosity)
- **PDF support**: Attach PDFs directly (`--pdf document.pdf`)
- **REPL mode** for conversations
- **Maintained & tested**: Automated release pipeline, 14 integration tests

## Installation

### Ubuntu/Debian (recommended):
```bash
sudo add-apt-repository ppa:code-faster/ppa
sudo apt-get update
sudo apt-get install gpt-toolkit
```

### From source:
```bash
git clone https://github.com/tyleradams/gpt-toolkit.git
cd gpt-toolkit
make dependencies && sudo make install
```

## Quick Examples

```bash
# Simple text filtering
echo "Count from 1 to 10" | gpt

# Work with files
cat code.py | gpt "Find bugs in this code"

# Reasoning controls
echo "Hard math problem..." | gpt --reasoning-effort high

# PDF analysis
echo "Summarize this research paper" | gpt --pdf paper.pdf -m gpt-4o

# Extract code from responses
echo "Write a Python hello world" | gpt | gpt-extract-code > hello.py

# REPL mode
gpt --repl
```

## Links

- **Install**: https://launchpad.net/~code-faster/+archive/ubuntu/ppa
- **Source**: https://github.com/tyleradams/gpt-toolkit
- **Docs**: https://github.com/tyleradams/gpt-toolkit#readme

## Built with Claude Code

This project went from "rough Python script" to "production-ready package" thanks to [Claude Code](https://claude.com/claude-code). The automated testing pipeline, Debian packaging, and release workflow were all built collaboratively with an AI coding assistant. Pretty cool that we can now ship properly tested, packaged software this way!

Questions? Hit me up!

— Tyler
