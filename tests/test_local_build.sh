#!/bin/bash
# Test that gpt-toolkit builds and installs correctly locally before publishing to PPA
# This uses Docker to simulate a clean build environment

set -e

echo "============================================================"
echo "Local Pre-Publish Test - gpt-toolkit"
echo "============================================================"
echo

# Get the current version
VERSION=$(cat VERSION 2>/dev/null || echo "unknown")
echo "Testing version: $VERSION"
echo

# Check if the .dsc file exists
DSC_FILE="target/gpt-toolkit_${VERSION}-1.dsc"
if [ ! -f "$DSC_FILE" ]; then
    echo "ERROR: Source package not found at $DSC_FILE"
    echo "Run 'make package version=$VERSION' first"
    exit 1
fi

echo "Found source package: $DSC_FILE"
echo

# Create a Dockerfile for local build testing
cat > /tmp/gpt-toolkit-local-test.dockerfile << 'EOF'
FROM ubuntu:jammy

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

# Test 2: gpt-token-length exists
if which gpt-token-length > /dev/null 2>&1; then
    echo "✓ gpt-token-length found in PATH"
else
    echo "✗ ERROR: gpt-token-length not found in PATH"
    FAILURES=$((FAILURES+1))
fi

# Test 3: gpt-extract-code exists
if which gpt-extract-code > /dev/null 2>&1; then
    echo "✓ gpt-extract-code found in PATH"
else
    echo "✗ ERROR: gpt-extract-code not found in PATH"
    FAILURES=$((FAILURES+1))
fi

# Test 4: gpt-to-substack exists
if which gpt-to-substack > /dev/null 2>&1; then
    echo "✓ gpt-to-substack found in PATH"
else
    echo "✗ ERROR: gpt-to-substack not found in PATH"
    FAILURES=$((FAILURES+1))
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

# Test 13: Token counter works
if echo "Hello world" | gpt-token-length 2>&1 | grep -qE '^[0-9]+$'; then
    echo "✓ gpt-token-length works"
else
    echo "✗ ERROR: gpt-token-length failed"
    FAILURES=$((FAILURES+1))
fi

# Test 14: Code extractor works
if echo '```
print("hello")
```' | gpt-extract-code 2>&1 | grep -q 'print("hello")'; then
    echo "✓ gpt-extract-code works"
else
    echo "✗ ERROR: gpt-extract-code failed"
    FAILURES=$((FAILURES+1))
fi

echo ""
echo "========================================"
if [ $FAILURES -eq 0 ]; then
    echo "✓ All 14 tests passed!"
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
