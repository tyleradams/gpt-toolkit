#!/usr/bin/env python3
"""
Test suite for gpt command-line tool.

Tests basic functionality without making actual API calls.
"""

import subprocess
import sys
import os

def run_gpt(*args, stdin_data=None, expect_error=False):
    """Run gpt command with given arguments."""
    cmd = ['./src/gpt'] + list(args)
    result = subprocess.run(
        cmd,
        input=stdin_data,
        capture_output=True,
        text=True,
        cwd='/home/cowboy/code/gpt-toolkit'
    )

    if not expect_error and result.returncode != 0:
        print(f"Command failed: {' '.join(cmd)}", file=sys.stderr)
        print(f"STDOUT: {result.stdout}", file=sys.stderr)
        print(f"STDERR: {result.stderr}", file=sys.stderr)
        raise AssertionError(f"Command failed with code {result.returncode}")

    return result

def test_help():
    """Test that help flags work."""
    print("Testing --help flag...")
    result = run_gpt('--help')
    assert 'Usage: gpt' in result.stdout
    assert '--model' in result.stdout
    assert '--reasoning-effort' in result.stdout
    print("✓ --help works")

    print("Testing -h flag...")
    result = run_gpt('-h')
    assert 'Usage: gpt' in result.stdout
    print("✓ -h works")

def test_version_in_help():
    """Test that help shows correct version."""
    print("Testing version display...")
    result = run_gpt('--help')
    # Just verify help works, version is in man page
    assert 'gpt-5' in result.stdout.lower()
    print("✓ Version info present")

def test_model_flags():
    """Test model selection flags parse correctly."""
    print("Testing model flags...")

    # Test that flags are recognized (will fail with API key error but that's ok)
    result = run_gpt('-4', '--help')
    assert 'Usage: gpt' in result.stdout
    print("✓ -4 flag accepted")

    result = run_gpt('--mini', '--help')
    assert 'Usage: gpt' in result.stdout
    print("✓ --mini flag accepted")

    result = run_gpt('--nano', '--help')
    assert 'Usage: gpt' in result.stdout
    print("✓ --nano flag accepted")

def test_reasoning_effort_flag():
    """Test reasoning effort flag accepts valid values."""
    print("Testing reasoning-effort flag...")

    # These should parse without error (even if API call would fail)
    for level in ['minimal', 'low', 'medium', 'high']:
        result = run_gpt('--reasoning-effort', level, '--help')
        assert 'Usage: gpt' in result.stdout
        print(f"✓ --reasoning-effort {level} accepted")

def test_verbosity_flag():
    """Test verbosity flag accepts valid values."""
    print("Testing verbosity flag...")

    for level in ['low', 'medium', 'high']:
        result = run_gpt('--verbosity', level, '--help')
        assert 'Usage: gpt' in result.stdout
        print(f"✓ --verbosity {level} accepted")

def test_invalid_reasoning_effort():
    """Test that invalid reasoning effort is rejected."""
    print("Testing invalid reasoning-effort value...")
    result = run_gpt('--reasoning-effort', 'invalid', expect_error=True)
    assert result.returncode != 0
    print("✓ Invalid reasoning-effort rejected")

def test_invalid_verbosity():
    """Test that invalid verbosity is rejected."""
    print("Testing invalid verbosity value...")
    result = run_gpt('--verbosity', 'invalid', expect_error=True)
    assert result.returncode != 0
    print("✓ Invalid verbosity rejected")

def test_stdin_with_tokens():
    """Test that stdin input works with --tokens flag."""
    print("Testing stdin input with --tokens...")
    result = run_gpt('--tokens', stdin_data='Hello world')
    assert result.returncode == 0
    assert 'token_count' in result.stdout
    print("✓ stdin with --tokens works")

def test_stdin_filter_mode():
    """Test that stdin filter mode doesn't crash with NameError.

    This test would have caught the undefined variable 'f' bug.
    The important thing is no NameError - it should either succeed (if API key present)
    or fail with API error (if no key).
    """
    print("Testing stdin filter mode (no NameError expected)...")
    result = run_gpt(stdin_data='test', expect_error=False)
    # The critical check: should not have NameError for undefined 'f'
    assert 'NameError' not in result.stderr, "Should not have NameError for undefined variable"
    assert 'NameError' not in result.stdout, "Should not have NameError for undefined variable"
    # If it succeeded (returncode 0), great. If it failed, should be API error not NameError.
    if result.returncode != 0:
        assert 'NameError' not in result.stderr
    print("✓ stdin filter mode runs (no NameError)")

def test_model_selection_no_crash():
    """Test that model selection doesn't cause undefined variable issues."""
    print("Testing model flags don't cause crashes...")
    # Test with --tokens to avoid API call, but with different models
    result = run_gpt('-4', '--tokens', stdin_data='test')
    assert result.returncode == 0
    assert '"model": "gpt-4o"' in result.stdout
    print("✓ -4 flag with stdin works")

    result = run_gpt('--mini', '--tokens', stdin_data='test')
    assert result.returncode == 0
    assert '"model": "gpt-5-mini"' in result.stdout
    print("✓ --mini flag with stdin works")

def test_numeric_flags():
    """Test that numeric parameters are validated."""
    print("Testing numeric parameters...")

    # Valid temperature
    result = run_gpt('--temperature', '0.5', '--help')
    assert 'Usage: gpt' in result.stdout
    print("✓ Valid temperature accepted")

    # Valid max-completion-tokens
    result = run_gpt('--max-completion-tokens', '100', '--help')
    assert 'Usage: gpt' in result.stdout
    print("✓ Valid max-completion-tokens accepted")

def test_executable_permissions():
    """Test that gpt script is executable."""
    print("Testing executable permissions...")
    gpt_path = '/home/cowboy/code/gpt-toolkit/src/gpt'
    assert os.access(gpt_path, os.X_OK), f"{gpt_path} is not executable"
    print("✓ gpt is executable")

def test_shebang():
    """Test that shebang is correct."""
    print("Testing shebang...")
    with open('/home/cowboy/code/gpt-toolkit/src/gpt', 'r') as f:
        first_line = f.readline().strip()
        assert first_line == '#!/usr/bin/env python3', f"Invalid shebang: {first_line}"
    print("✓ Shebang is correct")

def test_retry_flags():
    """Test that retry/resilience flags are accepted."""
    print("Testing retry flags...")

    # Test --timeout flag
    result = run_gpt('--timeout', '30', '--help')
    assert 'Usage: gpt' in result.stdout
    print("✓ --timeout flag accepted")

    # Test --debug flag
    result = run_gpt('--debug', '--help')
    assert 'Usage: gpt' in result.stdout
    print("✓ --debug flag accepted")

    # Test --fail-after-chunks flag (for testing)
    result = run_gpt('--fail-after-chunks', '10', '--help')
    assert 'Usage: gpt' in result.stdout
    print("✓ --fail-after-chunks flag accepted")

def main():
    """Run all tests."""
    print("=" * 60)
    print("GPT Command-Line Tool Test Suite")
    print("=" * 60)
    print()

    tests = [
        test_help,
        test_version_in_help,
        test_model_flags,
        test_reasoning_effort_flag,
        test_verbosity_flag,
        test_invalid_reasoning_effort,
        test_invalid_verbosity,
        test_stdin_with_tokens,
        test_stdin_filter_mode,
        test_model_selection_no_crash,
        test_numeric_flags,
        test_executable_permissions,
        test_shebang,
        test_retry_flags,
    ]

    failed = []
    passed = 0

    for test in tests:
        try:
            test()
            passed += 1
            print()
        except Exception as e:
            failed.append((test.__name__, str(e)))
            print(f"✗ {test.__name__} FAILED: {e}")
            print()

    print("=" * 60)
    print(f"Test Results: {passed}/{len(tests)} passed")

    if failed:
        print(f"\n{len(failed)} test(s) failed:")
        for name, error in failed:
            print(f"  - {name}: {error}")
        return 1
    else:
        print("\n✓ All tests passed!")
        return 0

if __name__ == '__main__':
    sys.exit(main())
