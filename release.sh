#!/bin/bash
# Release script for gpt-toolkit
# Ensures proper testing order before publishing to PPA

set -e  # Exit on any error

VERSION=$1

if [ -z "$VERSION" ]; then
    echo "Usage: ./release.sh VERSION"
    echo "Example: ./release.sh 2.0.5"
    exit 1
fi

echo "============================================================"
echo "gpt-toolkit Release Pipeline - Version $VERSION"
echo "============================================================"
echo

# Check if version matches VERSION file
VERSION_FILE=$(cat VERSION)
if [ "$VERSION_FILE" != "$VERSION" ]; then
    echo "ERROR: VERSION file contains '$VERSION_FILE' but you specified '$VERSION'"
    echo "Update VERSION file first"
    exit 1
fi

# Check if version matches src/gpt
if ! grep -q "version='$VERSION'" src/gpt; then
    echo "ERROR: src/gpt doesn't have version='$VERSION'"
    echo "Update src/gpt version"
    exit 1
fi

# Check if changelog has this version
if ! head -1 debian/changelog | grep -q "($VERSION-1)"; then
    echo "ERROR: debian/changelog doesn't start with version $VERSION-1"
    echo "Update debian/changelog"
    exit 1
fi

echo "✓ Version $VERSION verified in VERSION, src/gpt, and debian/changelog"
echo

# Step 1: Run unit tests
echo "============================================================"
echo "Step 1: Running Unit Tests"
echo "============================================================"
make test
echo "✓ Unit tests passed"
echo

# Step 2: Build package
echo "============================================================"
echo "Step 2: Building Debian Package"
echo "============================================================"
make clean
make package version=$VERSION
echo "✓ Package built"
echo

# Step 3: Local build test (Docker)
echo "============================================================"
echo "Step 3: Local Build Test (Docker)"
echo "============================================================"
echo "This builds the binary .deb and tests it in a clean container..."
make test-local
echo "✓ Local build test passed"
echo

# Step 4: Install locally
echo "============================================================"
echo "Step 4: Installing Locally"
echo "============================================================"
echo "Installing to /usr/local..."
echo "Running: sudo make install"
echo "You may need to enter your password..."
sudo make install
echo "✓ Installed locally"
echo

# Step 5: Test installed version
echo "============================================================"
echo "Step 5: Testing Installed Version"
echo "============================================================"

# Test 1: Version check
echo -n "Testing version... "
INSTALLED_VERSION=$(gpt --version 2>&1 | head -1 | grep -oP '[\d\.]+' || echo "")
if [ "$INSTALLED_VERSION" != "$VERSION" ]; then
    echo "✗ FAILED"
    echo "Expected version $VERSION, got $INSTALLED_VERSION"
    exit 1
fi
echo "✓"

# Test 2: Help works
echo -n "Testing help... "
if ! gpt --help > /dev/null 2>&1; then
    echo "✗ FAILED"
    exit 1
fi
echo "✓"

# Test 3: PDF flag exists
echo -n "Testing PDF flag... "
if ! gpt --help | grep -q "\-\-pdf"; then
    echo "✗ FAILED"
    exit 1
fi
echo "✓"

# Test 4: Basic functionality (requires API key)
if [ -n "$OPENAI_API_KEY" ]; then
    echo -n "Testing basic API call... "
    RESULT=$(echo "Say only the word 'test'" | gpt --reasoning-effort minimal 2>&1 || echo "")
    if [ -z "$RESULT" ]; then
        echo "✗ FAILED"
        exit 1
    fi
    echo "✓"
else
    echo "⚠ Skipping API test (no OPENAI_API_KEY)"
fi

echo "✓ All installed version tests passed"
echo

# Step 6: Confirm before publishing
echo "============================================================"
echo "Step 6: Ready to Publish"
echo "============================================================"
echo "All tests passed. Ready to:"
echo "  1. Create git tag v$VERSION"
echo "  2. Push to GitHub"
echo "  3. Publish to Launchpad PPA"
echo
read -p "Continue with publish? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted by user"
    exit 1
fi

# Step 7: Create and push git tag
echo
echo "============================================================"
echo "Step 7: Creating Git Tag"
echo "============================================================"

if git tag -l | grep -q "^v$VERSION$"; then
    echo "Tag v$VERSION already exists, skipping..."
else
    git tag -a v$VERSION -m "Release v$VERSION

Automated release via release.sh
All tests passed before tagging."
    echo "✓ Created tag v$VERSION"
fi

echo "Pushing to GitHub..."
git push origin master
git push origin v$VERSION
echo "✓ Pushed to GitHub"
echo

# Step 8: Publish to Launchpad
echo "============================================================"
echo "Step 8: Publishing to Launchpad PPA"
echo "============================================================"
make publish version=$VERSION
echo "✓ Published to Launchpad"
echo

# Step 9: Wait and run post-publish test
echo "============================================================"
echo "Step 9: Post-Publish Test"
echo "============================================================"
echo "Launchpad needs ~30 minutes to build the package."
echo
read -p "Wait 30 minutes and run PPA integration test? (yes/skip): " RUN_FINAL_TEST

if [ "$RUN_FINAL_TEST" = "yes" ]; then
    echo "Waiting 30 minutes for Launchpad build..."
    sleep 1800

    echo
    echo "Running PPA integration test..."
    make test-debian

    echo
    echo "============================================================"
    echo "✓ RELEASE COMPLETE - Version $VERSION"
    echo "============================================================"
    echo "All tests passed, package is live on PPA"
else
    echo
    echo "============================================================"
    echo "⚠ RELEASE PENDING - Version $VERSION"
    echo "============================================================"
    echo "Published to Launchpad, but final PPA test not run yet."
    echo "Run 'make test-debian' in ~30 minutes to verify."
fi
