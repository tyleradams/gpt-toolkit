#!/bin/bash
# Wait 30 minutes for Launchpad to build the package, then test

echo "Waiting 30 minutes for Launchpad to build gpt-toolkit 2.0.2..."
echo "Started at: $(date)"
echo ""

# Wait 30 minutes
sleep 1800

echo "Wait complete at: $(date)"
echo "Running Docker test..."
echo ""

# Run the test
make test-debian
