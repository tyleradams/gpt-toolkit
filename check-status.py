#!/usr/bin/env python3
"""
Comprehensive status checker for gpt-toolkit Debian package project.
Gathers ALL relevant data in ONE execution without requiring permissions.
Outputs structured JSON data.
"""

import json
import os
import re
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from pathlib import Path
import urllib.request
import urllib.error


class StatusChecker:
    def __init__(self, project_dir="/home/cowboy/code/gpt-toolkit"):
        self.project_dir = Path(project_dir)
        self.results = {}

    def run_cmd(self, cmd, cwd=None, timeout=30):
        """Run command and return stdout, or None on error."""
        try:
            result = subprocess.run(
                cmd,
                shell=True,
                cwd=cwd or self.project_dir,
                capture_output=True,
                text=True,
                timeout=timeout
            )
            return result.stdout.strip()
        except Exception as e:
            return None

    def check_git_state(self):
        """Gather all git-related information."""
        git_data = {}

        # Current branch
        git_data['current_branch'] = self.run_cmd('git rev-parse --abbrev-ref HEAD')

        # Current commit hash
        git_data['current_commit'] = self.run_cmd('git rev-parse HEAD')
        git_data['current_commit_short'] = self.run_cmd('git rev-parse --short HEAD')

        # Current tag
        git_data['current_tag'] = self.run_cmd('git describe --tags --exact-match 2>/dev/null')

        # Latest tag
        git_data['latest_tag'] = self.run_cmd('git describe --tags --abbrev=0 2>/dev/null')

        # All tags sorted
        tags = self.run_cmd('git tag --sort=-version:refname')
        git_data['all_tags'] = tags.split('\n') if tags else []

        # Working directory status
        git_data['working_status'] = self.run_cmd('git status --porcelain')
        git_data['working_status_summary'] = self.run_cmd('git status --short')

        # Is working tree clean?
        git_data['is_clean'] = not bool(git_data['working_status'])

        # Staged vs unstaged changes
        git_data['staged_files'] = self.run_cmd('git diff --name-only --cached')
        git_data['unstaged_files'] = self.run_cmd('git diff --name-only')
        git_data['untracked_files'] = self.run_cmd('git ls-files --others --exclude-standard')

        # Remote status
        git_data['remote_url'] = self.run_cmd('git config --get remote.origin.url')
        git_data['remote_branch'] = self.run_cmd('git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null')

        # Ahead/behind remote
        ahead_behind = self.run_cmd('git rev-list --left-right --count @{u}...HEAD 2>/dev/null')
        if ahead_behind:
            parts = ahead_behind.split()
            if len(parts) == 2:
                git_data['commits_behind'] = int(parts[0])
                git_data['commits_ahead'] = int(parts[1])

        # Last commit info
        git_data['last_commit_message'] = self.run_cmd('git log -1 --pretty=%B')
        git_data['last_commit_author'] = self.run_cmd('git log -1 --pretty=%an')
        git_data['last_commit_date'] = self.run_cmd('git log -1 --pretty=%ci')

        # Recent commits (last 5)
        recent_commits = []
        commits_raw = self.run_cmd('git log -5 --pretty=format:"%H|%h|%an|%ae|%ci|%s"')
        if commits_raw:
            for line in commits_raw.split('\n'):
                parts = line.split('|')
                if len(parts) == 6:
                    recent_commits.append({
                        'hash': parts[0],
                        'short_hash': parts[1],
                        'author': parts[2],
                        'email': parts[3],
                        'date': parts[4],
                        'subject': parts[5]
                    })
        git_data['recent_commits'] = recent_commits

        return git_data

    def check_build_artifacts(self):
        """List all build artifacts in target/ directory."""
        artifacts = {
            'target_dir_exists': False,
            'dsc_files': [],
            'changes_files': [],
            'deb_files': [],
            'buildinfo_files': [],
            'upload_files': [],
            'source_files': [],
            'other_files': []
        }

        target_dir = self.project_dir / 'target'
        if not target_dir.exists():
            return artifacts

        artifacts['target_dir_exists'] = True

        for item in target_dir.rglob('*'):
            if not item.is_file():
                continue

            stat = item.stat()
            file_info = {
                'path': str(item.relative_to(self.project_dir)),
                'name': item.name,
                'size': stat.st_size,
                'mtime': datetime.fromtimestamp(stat.st_mtime).isoformat(),
                'mtime_unix': stat.st_mtime
            }

            if item.suffix == '.dsc':
                artifacts['dsc_files'].append(file_info)
            elif item.suffix == '.changes':
                artifacts['changes_files'].append(file_info)
            elif item.suffix == '.deb':
                artifacts['deb_files'].append(file_info)
            elif item.suffix == '.buildinfo':
                artifacts['buildinfo_files'].append(file_info)
            elif item.suffix == '.upload':
                artifacts['upload_files'].append(file_info)
            elif item.suffix in ['.gz', '.xz']:
                artifacts['source_files'].append(file_info)
            else:
                artifacts['other_files'].append(file_info)

        # Sort by modification time (newest first)
        for key in artifacts:
            if isinstance(artifacts[key], list) and artifacts[key] and isinstance(artifacts[key][0], dict):
                artifacts[key].sort(key=lambda x: x.get('mtime_unix', 0), reverse=True)

        return artifacts

    def parse_debian_changelog(self):
        """Parse debian/changelog for version and distribution info."""
        changelog_data = {
            'file_exists': False,
            'entries': []
        }

        changelog_path = self.project_dir / 'debian' / 'changelog'
        if not changelog_path.exists():
            return changelog_data

        changelog_data['file_exists'] = True

        try:
            with open(changelog_path, 'r') as f:
                content = f.read()

            # Parse changelog entries (first 10)
            # Format: package (version) distribution; urgency=medium
            entry_pattern = r'^(\S+)\s+\(([^)]+)\)\s+([^;]+);'
            date_pattern = r'--\s+(.+?)\s+<(.+?)>\s+(.+)$'

            entries = []
            current_entry = None

            for line in content.split('\n'):
                # Check for new entry
                match = re.match(entry_pattern, line)
                if match:
                    if current_entry:
                        entries.append(current_entry)
                    current_entry = {
                        'package': match.group(1),
                        'version': match.group(2),
                        'distribution': match.group(3).strip(),
                        'changes': [],
                        'author': None,
                        'email': None,
                        'date': None
                    }
                # Check for date/author line
                elif current_entry and line.strip().startswith('--'):
                    match = re.match(date_pattern, line.strip())
                    if match:
                        current_entry['author'] = match.group(1)
                        current_entry['email'] = match.group(2)
                        current_entry['date'] = match.group(3)
                # Collect changes
                elif current_entry and line.strip().startswith('*'):
                    current_entry['changes'].append(line.strip()[1:].strip())

                # Limit to first 10 entries
                if len(entries) >= 10:
                    break

            if current_entry and len(entries) < 10:
                entries.append(current_entry)

            changelog_data['entries'] = entries

            # Extract first entry info for quick access
            if entries:
                first = entries[0]
                changelog_data['current_version'] = first['version']
                changelog_data['current_distribution'] = first['distribution']
                changelog_data['current_author'] = first['author']
                changelog_data['current_date'] = first['date']

        except Exception as e:
            changelog_data['error'] = str(e)

        return changelog_data

    def parse_debian_control(self):
        """Parse debian/control for package metadata."""
        control_data = {
            'file_exists': False,
            'source': {},
            'packages': []
        }

        control_path = self.project_dir / 'debian' / 'control'
        if not control_path.exists():
            return control_data

        control_data['file_exists'] = True

        try:
            with open(control_path, 'r') as f:
                content = f.read()

            # Simple parser for debian/control
            sections = content.split('\n\n')

            for section in sections:
                if not section.strip():
                    continue

                fields = {}
                current_field = None

                for line in section.split('\n'):
                    if not line:
                        continue

                    # New field
                    if line[0] != ' ' and ':' in line:
                        key, value = line.split(':', 1)
                        current_field = key.strip()
                        fields[current_field] = value.strip()
                    # Continuation
                    elif line[0] == ' ' and current_field:
                        fields[current_field] += '\n' + line.strip()

                # Determine if source or binary package
                if 'Source' in fields:
                    control_data['source'] = fields
                elif 'Package' in fields:
                    control_data['packages'].append(fields)

        except Exception as e:
            control_data['error'] = str(e)

        return control_data

    def check_launchpad_ppa(self):
        """Scrape Launchpad PPA for published packages and build status."""
        ppa_data = {
            'available': False,
            'packages': [],
            'error': None
        }

        ppa_url = 'https://launchpad.net/~code-faster/+archive/ubuntu/ppa/+packages'

        try:
            req = urllib.request.Request(
                ppa_url,
                headers={'User-Agent': 'Mozilla/5.0'}
            )
            with urllib.request.urlopen(req, timeout=10) as response:
                html = response.read().decode('utf-8')

            ppa_data['available'] = True

            # Parse HTML for package info (simple regex-based)
            # Look for gpt-toolkit entries
            package_pattern = r'<a[^>]*>gpt-toolkit\s+([^<]+)</a>'
            matches = re.findall(package_pattern, html)

            if matches:
                ppa_data['packages'] = [{'version': v.strip()} for v in matches]

            # Try to extract more detailed info
            # Look for build status indicators
            status_indicators = {
                'Successfully built': 0,
                'Currently building': 0,
                'Failed to build': 0,
                'Uploading': 0,
                'Pending publication': 0
            }

            for status in status_indicators.keys():
                count = html.count(status)
                if count > 0:
                    status_indicators[status] = count

            ppa_data['build_status_counts'] = status_indicators

        except urllib.error.URLError as e:
            ppa_data['error'] = f"URL Error: {str(e)}"
        except Exception as e:
            ppa_data['error'] = str(e)

        return ppa_data

    def check_apt_availability(self):
        """Use Docker to check apt-cache policy for jammy and noble."""
        apt_data = {
            'jammy': {'available': False, 'version': None, 'output': None, 'error': None},
            'noble': {'available': False, 'version': None, 'output': None, 'error': None}
        }

        for distro in ['jammy', 'noble']:
            try:
                # Build Docker command
                cmd = f'''docker run --rm ubuntu:{distro} /bin/bash -c "
                    apt-get update -qq 2>/dev/null &&
                    echo 'deb http://ppa.launchpad.net/code-faster/ppa/ubuntu {distro} main' > /etc/apt/sources.list.d/ppa.list &&
                    apt-get update -qq 2>/dev/null &&
                    apt-cache policy gpt-toolkit 2>/dev/null || echo 'NOT_AVAILABLE'
                "'''

                output = self.run_cmd(cmd, timeout=60)

                if output and 'NOT_AVAILABLE' not in output:
                    apt_data[distro]['output'] = output
                    apt_data[distro]['available'] = True

                    # Extract version
                    version_match = re.search(r'Candidate:\s+(\S+)', output)
                    if version_match:
                        apt_data[distro]['version'] = version_match.group(1)
                else:
                    apt_data[distro]['output'] = output

            except Exception as e:
                apt_data[distro]['error'] = str(e)

        return apt_data

    def check_background_processes(self):
        """Find bash processes related to gpt-toolkit/release and check logs."""
        process_data = {
            'related_processes': [],
            'log_files': []
        }

        # Find related processes
        try:
            ps_output = self.run_cmd('ps aux')
            if ps_output:
                for line in ps_output.split('\n'):
                    if 'gpt-toolkit' in line.lower() or 'release' in line.lower():
                        # Skip grep itself
                        if 'grep' not in line and 'check-status' not in line:
                            process_data['related_processes'].append(line.strip())
        except Exception as e:
            process_data['process_error'] = str(e)

        # Check for log files
        log_patterns = [
            '/tmp/gpt-toolkit*.log',
            '/tmp/*gpt-toolkit*',
            str(self.project_dir / '*.log')
        ]

        for pattern in log_patterns:
            try:
                output = self.run_cmd(f'ls -la {pattern} 2>/dev/null')
                if output:
                    for line in output.split('\n'):
                        if line.strip():
                            process_data['log_files'].append(line.strip())
            except:
                pass

        # Check specific log file
        test_log = Path('/tmp/gpt-toolkit-post-publish-test.log')
        if test_log.exists():
            try:
                stat = test_log.stat()
                with open(test_log, 'r') as f:
                    content = f.read()

                process_data['post_publish_test_log'] = {
                    'exists': True,
                    'size': stat.st_size,
                    'mtime': datetime.fromtimestamp(stat.st_mtime).isoformat(),
                    'content_preview': content[:1000] if len(content) > 1000 else content,
                    'content_tail': content[-1000:] if len(content) > 1000 else None
                }
            except Exception as e:
                process_data['post_publish_test_log'] = {'error': str(e)}

        return process_data

    def check_upload_history(self):
        """Parse ~/.dput.log for recent uploads."""
        upload_data = {
            'dput_log_exists': False,
            'recent_uploads': []
        }

        dput_log = Path.home() / '.dput.log'
        if not dput_log.exists():
            # Try alternative location
            dput_log = Path.home() / '.dput' / 'dput.log'

        if not dput_log.exists():
            return upload_data

        upload_data['dput_log_exists'] = True

        try:
            with open(dput_log, 'r') as f:
                lines = f.readlines()

            # Get last 50 lines
            recent_lines = lines[-50:] if len(lines) > 50 else lines

            for line in recent_lines:
                if 'gpt-toolkit' in line:
                    upload_data['recent_uploads'].append(line.strip())

        except Exception as e:
            upload_data['error'] = str(e)

        return upload_data

    def check_test_results(self):
        """Check for test output files."""
        test_data = {
            'test_files': []
        }

        # Check common test output locations
        test_patterns = [
            self.project_dir / 'test',
            self.project_dir / 'test.log',
            self.project_dir / 'test-results',
            Path('/tmp/gpt-toolkit-test*')
        ]

        for pattern in test_patterns:
            if '*' in str(pattern):
                # Use glob
                try:
                    matches = list(Path('/tmp').glob('gpt-toolkit-test*'))
                    for match in matches:
                        if match.is_file():
                            stat = match.stat()
                            test_data['test_files'].append({
                                'path': str(match),
                                'name': match.name,
                                'size': stat.st_size,
                                'mtime': datetime.fromtimestamp(stat.st_mtime).isoformat()
                            })
                except:
                    pass
            else:
                if pattern.exists():
                    if pattern.is_file():
                        stat = pattern.stat()
                        test_data['test_files'].append({
                            'path': str(pattern),
                            'name': pattern.name,
                            'size': stat.st_size,
                            'mtime': datetime.fromtimestamp(stat.st_mtime).isoformat()
                        })
                    elif pattern.is_dir():
                        # List directory contents
                        for item in pattern.iterdir():
                            if item.is_file():
                                stat = item.stat()
                                test_data['test_files'].append({
                                    'path': str(item),
                                    'name': item.name,
                                    'size': stat.st_size,
                                    'mtime': datetime.fromtimestamp(stat.st_mtime).isoformat()
                                })

        return test_data

    def check_all(self):
        """Run all checks in parallel where possible."""
        print("Gathering status information...", file=sys.stderr)

        # Quick checks (run in main thread)
        self.results['timestamp'] = datetime.now().isoformat()
        self.results['project_dir'] = str(self.project_dir)

        # Parallel checks
        with ThreadPoolExecutor(max_workers=8) as executor:
            futures = {
                executor.submit(self.check_git_state): 'git',
                executor.submit(self.check_build_artifacts): 'build_artifacts',
                executor.submit(self.parse_debian_changelog): 'debian_changelog',
                executor.submit(self.parse_debian_control): 'debian_control',
                executor.submit(self.check_launchpad_ppa): 'launchpad_ppa',
                executor.submit(self.check_background_processes): 'processes',
                executor.submit(self.check_upload_history): 'upload_history',
                executor.submit(self.check_test_results): 'test_results',
            }

            # Note: apt_availability is intentionally slow, run last
            # futures[executor.submit(self.check_apt_availability)] = 'apt_availability'

            for future in as_completed(futures):
                key = futures[future]
                try:
                    result = future.result()
                    self.results[key] = result
                    print(f"  ✓ {key}", file=sys.stderr)
                except Exception as e:
                    self.results[key] = {'error': str(e)}
                    print(f"  ✗ {key}: {str(e)}", file=sys.stderr)

        # Run apt check separately (can be very slow)
        print("  Checking apt availability (slow)...", file=sys.stderr)
        try:
            self.results['apt_availability'] = self.check_apt_availability()
            print("  ✓ apt_availability", file=sys.stderr)
        except Exception as e:
            self.results['apt_availability'] = {'error': str(e)}
            print(f"  ✗ apt_availability: {str(e)}", file=sys.stderr)

        return self.results


def main():
    # Support custom project directory
    project_dir = sys.argv[1] if len(sys.argv) > 1 else "/home/cowboy/code/gpt-toolkit"

    checker = StatusChecker(project_dir)
    results = checker.check_all()

    # Output JSON to stdout
    print(json.dumps(results, indent=2))


if __name__ == '__main__':
    main()
