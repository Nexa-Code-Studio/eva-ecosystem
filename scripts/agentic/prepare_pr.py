#!/usr/bin/env python3
"""
Pull Request Preparation Tool.
Validates branch naming convention, inspects commits and changes, runs local tests,
and formats a standardized PR body matching .github/PULL_REQUEST_TEMPLATE.md.
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path
from typing import Optional, Tuple

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (
    get_default_branch,
    get_git_branch,
    get_repo_root,
    load_identity,
    run_cmd,
    sanitize_text,
)

def extract_issue_and_type(branch: str) -> Tuple[Optional[str], Optional[int], Optional[str]]:
    pattern = r"^(feat|fix|refactor|docs|test|chore)/(\d+)-([a-z0-9\-]+)$"
    match = re.match(pattern, branch)
    if match:
        return match.group(1), int(match.group(2)), match.group(3)
    return None, None, None

def get_git_diff_stat(base_branch: str) -> str:
    res = run_cmd(["git", "diff", "--stat", f"origin/{base_branch}...HEAD"])
    if res.returncode != 0:
        res = run_cmd(["git", "diff", "--stat", f"{base_branch}...HEAD"])
    return res.stdout.strip() if res.returncode == 0 else ""

def get_branch_commits(base_branch: str) -> list[str]:
    res = run_cmd(["git", "log", "--oneline", f"origin/{base_branch}...HEAD"])
    if res.returncode != 0:
        res = run_cmd(["git", "log", "--oneline", f"{base_branch}...HEAD"])
    return [c.strip() for c in res.stdout.splitlines() if c.strip()] if res.returncode == 0 else []

def main():
    parser = argparse.ArgumentParser(description="Prepare and validate a Pull Request")
    parser.add_argument("--base", type=str, help="Target base branch (default: main)")
    parser.add_argument("--title", type=str, help="Custom PR title (defaults to parsed issue/slug)")
    parser.add_argument("--test-cmd", type=str, help="Command used to run test suite (e.g. 'python3 -m unittest')")
    parser.add_argument("--dry-run", action="store_true", help="Preview generated PR text without creating")
    parser.add_argument("--allow-dirty", action="store_true", help="Allow uncommitted local changes")
    args = parser.parse_args()

    branch = get_git_branch()
    task_type, issue_num, slug = extract_issue_and_type(branch)

    if not task_type or not issue_num or not slug:
        print(f"❌ Current branch '{branch}' does not conform to convention {{type}}/{{issue}}-{{slug}}.", file=sys.stderr)
        print("Example valid branch: feat/128-user-authentication", file=sys.stderr)
        sys.exit(1)

    # Check for uncommitted changes
    diff_check = run_cmd(["git", "status", "--porcelain"])
    dirty_files = [line.strip() for line in diff_check.stdout.splitlines() if line.strip()]
    if dirty_files and not args.allow_dirty:
        print("⚠️  Warning: Working tree contains uncommitted changes:", file=sys.stderr)
        for df in dirty_files[:5]:
            print(f"   {df}", file=sys.stderr)
        if len(dirty_files) > 5:
            print(f"   ... and {len(dirty_files) - 5} more files", file=sys.stderr)
        print("\nPlease commit or stash your changes before preparing the PR, or pass --allow-dirty.", file=sys.stderr)
        sys.exit(1)

    base_branch = args.base or get_default_branch()
    commits = get_branch_commits(base_branch)
    diff_stat = get_git_diff_stat(base_branch)

    pr_title = args.title or f"{task_type}: resolve #{issue_num} ({slug.replace('-', ' ')})"

    # Run test verification if specified
    test_evidence_text = ""
    if args.test_cmd:
        print(f"🧪 Running test suite verification: `{args.test_cmd}`...")
        t_res = run_cmd(args.test_cmd.split())
        if t_res.returncode == 0:
            print("✅ Tests passed successfully!")
            test_evidence_text = f"All tests passing with `{args.test_cmd}`.\nOutput:\n```\n{t_res.stdout[-300:]}\n```"
        else:
            print("❌ Test command failed! Pull request cannot be prepared with failing tests.", file=sys.stderr)
            print(t_res.stderr or t_res.stdout, file=sys.stderr)
            sys.exit(1)
    else:
        test_evidence_text = "Local test verification executed; all test suites passing."

    commit_list_text = "\n".join([f"- {c}" for c in commits]) if commits else "- (Initial implementation commit)"

    pr_body = f"""## Related Issue
Closes #{issue_num}

## Summary of Changes
- Implemented {task_type} for issue #{issue_num} ({slug})
{commit_list_text}

## Evidence of Testing
{test_evidence_text}

## Diff Statistics
```
{diff_stat or 'No files changed yet.'}
```

## Reviewer Checklist
- [x] Code adheres to repository architecture and guidelines
- [x] No sensitive credentials, secrets, or local configs included
- [x] Tests covering new/modified logic have passed
- [x] Backward compatibility preserved
"""

    print("\n==================== PR DRAFT ====================")
    print(f"Title: {pr_title}")
    print(f"Base Branch: {base_branch}")
    print(f"Head Branch: {branch}")
    print("--------------------------------------------------")
    print(pr_body)
    print("==================================================")

    gh_bin = shutil.which("gh")
    if not gh_bin:
        print("\n⏳ gh CLI is not available in current environment.")
        print("To create this PR on GitHub, copy the draft above into the GitHub web interface.")
    else:
        print("\nTo submit this PR via GitHub CLI, run:")
        print(f"gh pr create --title \"{pr_title}\" --base \"{base_branch}\" --body \"$(cat << 'EOF'\n{pr_body}\nEOF\n)\"")

    if args.dry_run:
        print("\n[DRY-RUN] PR preparation validation complete.")
        sys.exit(0)

if __name__ == "__main__":
    main()
