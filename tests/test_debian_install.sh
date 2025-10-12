#!/bin/bash
# Test that gpt-toolkit installs and works correctly from a clean Debian/Ubuntu system

set -e

echo "============================================================"
echo "Testing gpt-toolkit Debian Package Installation"
echo "============================================================"
echo

# Check if docker is available
if ! command -v docker &> /dev/null; then
    echo "ERROR: Docker is required for this test"
    exit 1
fi

# Get the current version
VERSION=$(cat VERSION 2>/dev/null || echo "unknown")
echo "Testing version: $VERSION"
echo

# Create a Dockerfile for testing
cat > /tmp/gpt-toolkit-test.dockerfile << 'EOF'
FROM ubuntu:jammy

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install basic utilities
RUN apt-get update && apt-get install -y \
    software-properties-common \
    curl \
    gnupg

# Add the PPA and install gpt-toolkit
RUN add-apt-repository -y ppa:code-faster/ppa && \
    apt-get update && \
    apt-get install -y gpt-toolkit

# Verify installation
RUN which gpt || (echo "ERROR: gpt not found in PATH" && exit 1)
RUN which gpt-token-length || (echo "ERROR: gpt-token-length not found in PATH" && exit 1)
RUN which gpt-extract-code || (echo "ERROR: gpt-extract-code not found in PATH" && exit 1)

# Test help works
RUN gpt --help | grep -q "Usage: gpt" || (echo "ERROR: gpt --help failed" && exit 1)
RUN gpt -h | grep -q "Usage: gpt" || (echo "ERROR: gpt -h failed" && exit 1)

# Test man page is installed
RUN man gpt > /dev/null 2>&1 || (echo "ERROR: man gpt failed" && exit 1)

# Verify Python dependencies are installed
RUN python3 -c "import click; import openai; import tiktoken; import readline" || \
    (echo "ERROR: Python dependencies not installed correctly" && exit 1)

# Test that version info is correct
RUN gpt --help | grep -q "gpt-5" || (echo "ERROR: Default model not gpt-5" && exit 1)

# Test token counter
RUN echo "Hello world" | gpt-token-length | grep -qE '^[0-9]+$' || \
    (echo "ERROR: gpt-token-length failed" && exit 1)

# Test code extractor
RUN echo '```\nprint("hello")\n```' | gpt-extract-code | grep -q 'print("hello")' || \
    (echo "ERROR: gpt-extract-code failed" && exit 1)

CMD echo "✓ All installation tests passed!"
EOF

echo "Building test Docker image (no cache)..."
docker build --no-cache -f /tmp/gpt-toolkit-test.dockerfile -t gpt-toolkit-test:latest /tmp/ 2>&1 | \
    grep -E '(Step|Successfully|ERROR)' || true

echo
echo "Running container to verify installation..."
if docker run --rm gpt-toolkit-test:latest; then
    echo
    echo "============================================================"
    echo "✓ SUCCESS: Package installs and works correctly!"
    echo "============================================================"
    exit 0
else
    echo
    echo "============================================================"
    echo "✗ FAILURE: Package installation or tests failed"
    echo "============================================================"
    exit 1
fi
