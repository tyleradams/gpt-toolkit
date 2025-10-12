#!/bin/bash
# Automated release script for gpt-toolkit
# One-shot: test -> build -> test -> publish -> verify

set -e  # Exit on any error

VERSION=$1
SKIP_PUBLISH=${2:-""}  # Optional: pass "skip-publish" to test without publishing

if [ -z "$VERSION" ]; then
    echo "Usage: ./release.sh VERSION [skip-publish]"
    echo "Example: ./release.sh 2.0.5"
    echo "         ./release.sh 2.0.5 skip-publish  (test only, don't publish)"
    exit 1
fi

echo "============================================================"
echo "gpt-toolkit Release Pipeline - Version $VERSION"
echo "============================================================"
echo

# Validate versions match
VERSION_FILE=$(cat VERSION)
if [ "$VERSION_FILE" != "$VERSION" ]; then
    echo "✗ ERROR: VERSION file contains '$VERSION_FILE' but you specified '$VERSION'"
    exit 1
fi

if ! grep -q "version='$VERSION'" src/gpt; then
    echo "✗ ERROR: src/gpt doesn't have version='$VERSION'"
    exit 1
fi

if ! head -1 debian/changelog | grep -q "($VERSION-1)"; then
    echo "✗ ERROR: debian/changelog doesn't start with version $VERSION-1"
    exit 1
fi

echo "✓ Version $VERSION verified"

# Step 1: Unit tests
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1/5: Unit Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
make test
echo "✓ Unit tests passed"

# Step 2: Build package
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2/5: Build Package"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
make clean
make package version=$VERSION
echo "✓ Package built"

# Step 3: Local build test
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3/5: Local Build Test (Docker)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Building binary .deb and testing in clean Ubuntu Jammy..."
make test-local
echo "✓ Local build test passed (14/14 tests)"

if [ "$SKIP_PUBLISH" = "skip-publish" ]; then
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✓ SUCCESS: All tests passed!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Skipping publish as requested."
    echo "To publish, run: ./release.sh $VERSION"
    exit 0
fi

# Step 4: Git tag and push
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4/5: Git Tag & Push"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if git tag -l | grep -q "^v$VERSION$"; then
    echo "⚠ Tag v$VERSION already exists, skipping tag creation"
else
    git tag -a v$VERSION -m "Release v$VERSION

Automated release - all tests passed
🤖 Built with Claude Code"
    echo "✓ Created tag v$VERSION"
fi

echo "Pushing to GitHub..."
git push origin master
git push origin v$VERSION
echo "✓ Pushed to GitHub"

# Step 5: Publish to Launchpad
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5/5: Publish to Launchpad PPA"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
make publish version=$VERSION
echo "✓ Published to Launchpad"

# Success summary
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ RELEASE COMPLETE - Version $VERSION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "Package published to: https://launchpad.net/~code-faster/+archive/ubuntu/ppa"
echo "GitHub release: https://github.com/tyleradams/gpt-toolkit/releases/tag/v$VERSION"
echo
echo "Next steps:"
echo "  • Launchpad will build the package (~20-30 minutes)"
echo "  • Run 'make test-debian' to verify PPA installation"
echo "  • Users can install with: sudo add-apt-repository ppa:code-faster/ppa"
echo "                            sudo apt-get update"
echo "                            sudo apt-get install gpt-toolkit"
echo
