#!/bin/bash
# Automated release script for gpt-toolkit
# Version managed via Git tags only - no VERSION file needed
# One-shot: test -> build -> test -> tag -> publish -> verify

set -e  # Exit on any error

VERSION=$1
SKIP_PUBLISH=${2:-""}  # Optional: pass "skip-publish" to test without publishing
TARGET_DISTRO="noble"  # Ubuntu 24.04 LTS

if [ -z "$VERSION" ]; then
    echo "Usage: ./release.sh VERSION [skip-publish]"
    echo "Example: ./release.sh 4.0.0"
    echo "         ./release.sh 4.0.0 skip-publish  (test only, don't publish)"
    exit 1
fi

# Validate version format (semantic versioning)
if ! echo "$VERSION" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+$'; then
    echo "✗ ERROR: VERSION must be in format X.Y.Z (e.g., 4.0.0)"
    exit 1
fi

echo "============================================================"
echo "gpt-toolkit Release Pipeline - Version $VERSION"
echo "Target: Ubuntu $TARGET_DISTRO (24.04 LTS)"
echo "============================================================"
echo

# Check git tag - idempotent: allow if points to HEAD
TAG_EXISTS=0
if git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null 2>&1; then
    TAG_SHA=$(git rev-parse "v$VERSION^{commit}" 2>/dev/null)
    HEAD_SHA=$(git rev-parse HEAD)
    if [ "$TAG_SHA" != "$HEAD_SHA" ]; then
        echo "✗ ERROR: Git tag v$VERSION exists but points to different commit"
        echo "  Tag points to: $TAG_SHA"
        echo "  HEAD is at:    $HEAD_SHA"
        exit 1
    fi
    echo "✓ Tag v$VERSION already exists (points to HEAD) - will skip tag creation"
    TAG_EXISTS=1
fi

# Verify working directory is clean
if [ -n "$(git status --porcelain)" ]; then
    echo "✗ ERROR: Working directory has uncommitted changes"
    echo "Commit or stash changes before releasing"
    exit 1
fi

echo "✓ Version $VERSION validated"

# Step 1: Unit tests
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 1/6: Unit Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
make test
echo "✓ Unit tests passed"

# Step 2: Generate debian/changelog entry
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 2/6: Generate debian/changelog"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if changelog already has entry for this version
if head -1 debian/changelog | grep -q "^gpt-toolkit ($VERSION-1) $TARGET_DISTRO"; then
    echo "✓ Changelog already has entry for $VERSION - skipping generation"
else
    # Create temporary changelog entry
    TIMESTAMP=$(date -R)
    cat > /tmp/changelog_entry.txt << EOF
gpt-toolkit ($VERSION-1) $TARGET_DISTRO; urgency=medium

  [Tyler Adams]
  * Release $VERSION

 -- Tyler Adams <tyler@blitzblitzblitz.com>  $TIMESTAMP

EOF

    # Prepend to existing changelog
    cat debian/changelog >> /tmp/changelog_entry.txt
    mv /tmp/changelog_entry.txt debian/changelog
    echo "✓ Generated changelog for $VERSION targeting $TARGET_DISTRO"
fi

# Step 3: Build package
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 3/6: Build Package"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if package already built
if [ -f "target/gpt-toolkit_${VERSION}-1.dsc" ]; then
    echo "✓ Package already built (target/gpt-toolkit_${VERSION}-1.dsc exists) - skipping"
else
    make clean
    make package version=$VERSION
    echo "✓ Package built"
fi

# Step 4: Local build test (Docker)
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 4/6: Local Build Test (Docker)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Building binary .deb and testing in clean Ubuntu $TARGET_DISTRO..."
make test-local
echo "✓ Local build test passed"

if [ "$SKIP_PUBLISH" = "skip-publish" ]; then
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "✓ SUCCESS: All tests passed!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Skipping publish as requested."
    echo "To publish, run: ./release.sh $VERSION"
    echo
    echo "NOTE: Changelog has been updated. Revert with:"
    echo "  git checkout debian/changelog"
    exit 0
fi

# Step 5: Git tag and push
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 5/6: Git Tag & Push"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if changelog already committed
if git log -1 --pretty=%s | grep -q "^Release $VERSION$" && git diff --quiet debian/changelog 2>/dev/null && git diff --cached --quiet debian/changelog 2>/dev/null; then
    echo "✓ Changelog already committed - skipping commit"
else
    # Commit the changelog
    git add debian/changelog
    git commit -m "Release $VERSION

Automated release to Ubuntu $TARGET_DISTRO

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
    echo "✓ Committed changelog"
fi

# Create annotated tag (checked earlier)
if [ "$TAG_EXISTS" -eq 1 ]; then
    echo "✓ Tag v$VERSION already exists - skipping tag creation"
else
    git tag -a v$VERSION -m "Release v$VERSION

Automated release - all tests passed
🤖 Built with Claude Code"
    echo "✓ Created tag v$VERSION"
fi

# Push to GitHub (check what's already there)
echo "Pushing to GitHub..."
PUSH_NEEDED=0

if git branch -r --contains HEAD 2>/dev/null | grep -q "origin/master"; then
    echo "✓ origin/master already has HEAD - skipping branch push"
else
    git push origin master
    echo "✓ Pushed master to origin"
    PUSH_NEEDED=1
fi

if git ls-remote --tags origin "refs/tags/v$VERSION" 2>/dev/null | grep -q "v$VERSION"; then
    echo "✓ origin already has tag v$VERSION - skipping tag push"
else
    git push origin v$VERSION
    echo "✓ Pushed tag v$VERSION to origin"
    PUSH_NEEDED=1
fi

if [ "$PUSH_NEEDED" -eq 0 ]; then
    echo "✓ Nothing to push (already on GitHub)"
fi

# Step 6: Publish to Launchpad
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Step 6/6: Publish to Launchpad PPA"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check if already uploaded (dput creates .upload file after successful upload)
if [ -f "target/gpt-toolkit_${VERSION}-1_source.code-faster.upload" ]; then
    echo "✓ Already uploaded to Launchpad (upload marker exists) - skipping"
else
    make publish version=$VERSION
    echo "✓ Published to Launchpad"
fi

# Success summary
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ RELEASE COMPLETE - Version $VERSION"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "Package published to: https://launchpad.net/~code-faster/+archive/ubuntu/ppa"
echo "GitHub release: https://github.com/tyleradams/gpt-toolkit/releases/tag/v$VERSION"
echo
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Post-Publish Verification (Background)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo
echo "Starting 30-minute wait for Launchpad build..."
echo "Verification will run automatically and notify on failure."
echo

# Run post-publish test in background
(
    sleep 1800  # Wait 30 minutes for Launchpad build

    echo
    echo "Running post-publish verification..."

    if make test-debian 2>&1 | tee /tmp/gpt-toolkit-post-publish-test.log; then
        echo
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✓ POST-PUBLISH VERIFICATION PASSED"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "Version $VERSION is live and working correctly!"
        echo "Users can now install with:"
        echo "  sudo add-apt-repository ppa:code-faster/ppa"
        echo "  sudo apt-get update"
        echo "  sudo apt-get install gpt-toolkit"
    else
        echo
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "✗ POST-PUBLISH VERIFICATION FAILED"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo
        echo "Version $VERSION was published but verification failed."
        echo "Check the log at: /tmp/gpt-toolkit-post-publish-test.log"
        echo
        echo "⚠️  ACTION REQUIRED: Manual investigation needed"
        echo
        # Notification (print to stderr so it's visible)
        >&2 echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        >&2 echo "⚠️  gpt-toolkit $VERSION POST-PUBLISH TEST FAILED"
        >&2 echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        >&2 echo "Log: /tmp/gpt-toolkit-post-publish-test.log"
        >&2 echo "PPA: https://launchpad.net/~code-faster/+archive/ubuntu/ppa"
    fi
) &

echo "Post-publish verification running in background (PID: $!)"
echo "You can continue working - verification will complete in ~30 minutes"
echo
