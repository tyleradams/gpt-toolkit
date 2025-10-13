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

# Get the current version from git
VERSION=$(git describe --tags --always 2>/dev/null | sed 's/^v//' || echo "unknown")
echo "Testing version: $VERSION"
echo

# Create a Dockerfile for testing
cat > /tmp/gpt-toolkit-test.dockerfile << 'EOF'
FROM ubuntu:noble

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

# Create a test script that collects all failures
RUN cat > /tmp/test_all.sh << 'TESTEOF'
#!/bin/bash
FAILURES=0

echo "=== Checking Installed Version ==="
if gpt --version 2>&1 | head -1; then
    echo ""
else
    echo "✗ Cannot determine version (--version not available)"
    echo ""
fi

echo "=== Testing Installation ==="

# Test 1: gpt command exists
if which gpt > /dev/null 2>&1; then
    echo "✓ gpt found in PATH"
else
    echo "✗ ERROR: gpt not found in PATH"
    FAILURES=$((FAILURES+1))
fi

# Test 2: Old utilities should NOT exist (v3.0 removed them)
if which gpt-token-length > /dev/null 2>&1 || which gpt-extract-code > /dev/null 2>&1 || which gpt-to-substack > /dev/null 2>&1; then
    echo "✗ ERROR: Old utilities still present (should be removed in v3.0)"
    FAILURES=$((FAILURES+1))
else
    echo "✓ Old utilities correctly removed (v3.0)"
fi

echo ""
echo "=== Testing Help ==="

# Test 5: gpt --help
if gpt --help 2>&1 | grep -q "Usage: gpt"; then
    echo "✓ gpt --help works"
else
    echo "✗ ERROR: gpt --help failed"
    FAILURES=$((FAILURES+1))
fi

# Test 6: gpt -h
if gpt -h 2>&1 | grep -q "Usage: gpt"; then
    echo "✓ gpt -h works"
else
    echo "✗ ERROR: gpt -h failed"
    FAILURES=$((FAILURES+1))
fi

echo ""
echo "=== Testing Man Pages ==="

# Test 7: man page installed
if man gpt > /dev/null 2>&1; then
    echo "✓ man gpt works"
else
    echo "✗ ERROR: man gpt failed"
    FAILURES=$((FAILURES+1))
fi

echo ""
echo "=== Testing Python Dependencies ==="

# Test 8: click
if python3 -c "import click" 2>&1; then
    echo "✓ python3-click installed"
else
    echo "✗ ERROR: python3-click not installed"
    FAILURES=$((FAILURES+1))
fi

# Test 9: openai
if python3 -c "import openai" 2>&1; then
    echo "✓ python3-openai installed"
else
    echo "✗ ERROR: python3-openai not installed"
    FAILURES=$((FAILURES+1))
fi

# Test 10: tiktoken
if python3 -c "import tiktoken" 2>&1; then
    echo "✓ python3-tiktoken installed"
else
    echo "✗ ERROR: python3-tiktoken not installed"
    FAILURES=$((FAILURES+1))
fi

# Test 11: readline
if python3 -c "import readline" 2>&1; then
    echo "✓ python3-readline installed"
else
    echo "✗ ERROR: python3-readline not installed"
    FAILURES=$((FAILURES+1))
fi

echo ""
echo "=== Testing Functionality ==="

# Test 12: Default model is gpt-5
if gpt --help 2>&1 | grep -q "gpt-5"; then
    echo "✓ Default model is gpt-5"
else
    echo "✗ ERROR: Default model not gpt-5"
    FAILURES=$((FAILURES+1))
fi

# Test 13: Token counter works (--tokens flag)
if echo "Hello world" | gpt --tokens 2>&1 | grep -q '"token_count"'; then
    echo "✓ gpt --tokens works"
else
    echo "✗ ERROR: gpt --tokens failed"
    FAILURES=$((FAILURES+1))
fi

# Test 14: --tokens outputs valid JSON
if echo "test" | gpt --tokens 2>&1 | python3 -c "import json, sys; json.load(sys.stdin)" > /dev/null 2>&1; then
    echo "✓ gpt --tokens outputs valid JSON"
else
    echo "✗ ERROR: gpt --tokens JSON invalid"
    FAILURES=$((FAILURES+1))
fi

echo ""
echo "========================================"
if [ $FAILURES -eq 0 ]; then
    echo "✓ All 12 tests passed!"
    exit 0
else
    echo "✗ $FAILURES test(s) failed"
    exit 1
fi
TESTEOF

RUN chmod +x /tmp/test_all.sh

CMD /tmp/test_all.sh
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
