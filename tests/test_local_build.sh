#!/bin/bash
# Test that gpt-toolkit builds and installs correctly locally before publishing to PPA
# This uses Docker to simulate a clean build environment

set -e

echo "============================================================"
echo "Local Pre-Publish Test - gpt-toolkit"
echo "============================================================"
echo

# Find the most recent .dsc file in target/
DSC_FILE=$(ls -t target/*.dsc 2>/dev/null | head -1)

if [ -z "$DSC_FILE" ]; then
    echo "ERROR: No .dsc file found in target/"
    echo "Run 'make package version=X.Y.Z' first"
    exit 1
fi

# Extract version from .dsc filename
VERSION=$(basename "$DSC_FILE" | sed 's/gpt-toolkit_\(.*\)-1\.dsc/\1/')
echo "Testing version: $VERSION"
echo

echo "Found source package: $DSC_FILE"
echo

# Create a Dockerfile for local build testing
cat > /tmp/gpt-toolkit-local-test.dockerfile << 'EOF'
FROM ubuntu:noble

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    debhelper \
    dh-make \
    devscripts \
    software-properties-common

# Copy the source package
COPY target/*.dsc /build/
COPY target/*.tar.* /build/
WORKDIR /build

# Extract and build
RUN DSC_FILE=$(ls *.dsc) && \
    dpkg-source -x $DSC_FILE && \
    cd gpt-toolkit-* && \
    dpkg-buildpackage -b -us -uc

# Install the built package
RUN dpkg -i /build/*.deb || apt-get install -f -y

# Run the same tests as the PPA test
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

echo "Building Docker image for local test..."
docker build --no-cache -f /tmp/gpt-toolkit-local-test.dockerfile -t gpt-toolkit-local-test:latest .

echo
echo "Running tests in container..."
if docker run --rm gpt-toolkit-local-test:latest; then
    echo
    echo "============================================================"
    echo "✓ SUCCESS: Local build and tests passed!"
    echo "Ready to publish to Launchpad PPA"
    echo "============================================================"
    exit 0
else
    echo
    echo "============================================================"
    echo "✗ FAILURE: Local build or tests failed"
    echo "DO NOT publish to Launchpad - fix issues first"
    echo "============================================================"
    exit 1
fi
