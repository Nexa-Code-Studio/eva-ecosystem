#!/usr/bin/env python3
"""
Task Startup Workflow Tool.
Validates branch convention, runs doctor preflight, and safely creates
a task branch or isolated git worktree for development.
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path
from typing import Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common import (
    find_gh_binary,
    get_default_branch,
    get_identity_path,
    get_repo_root,
    load_identity,
    run_cmd,
    sanitize_text,
)
import doctor

ALLOWED_TYPES = ["feat", "fix", "refactor", "docs", "test", "chore"]

def format_slug(text: str) -> str:
    slug = text.lower().strip()
    slug = re.sub(r"[^a-z0-9\-]+", "-", slug)
    slug = re.sub(r"-+", "-", slug).strip("-")
    return slug[:50]

def validate_branch_name(name: str) -> bool:
    pattern = r"^(feat|fix|refactor|docs|test|chore)/(\d+)-([a-z0-9\-]+)$"
    return bool(re.match(pattern, name))

def main():
    parser = argparse.ArgumentParser(description="Start a new task branch or worktree")
    parser.add_argument("--type", choices=ALLOWED_TYPES, required=True, help="Task type (feat, fix, refactor, docs, test, chore)")
    parser.add_argument("--issue", type=int, required=True, help="GitHub Issue number")
    parser.add_argument("--slug", type=str, required=True, help="Short description slug (e.g. login-page)")
    parser.add_argument("--worktree", action="store_true", help="Create an isolated git worktree under .agent/worktrees/")
    parser.add_argument("--base", type=str, help="Base branch (default: origin default branch or main)")
    parser.add_argument("--dry-run", action="store_true", help="Preview action without creating branch/worktree")
    parser.add_argument("--no-preflight", action="store_true", help="Skip doctor preflight checks")
    parser.add_argument("--force", action="store_true", help="Proceed even if assigned to someone else")
    args = parser.parse_args()

    repo_root = get_repo_root()

    # Preflight Check
    if not args.no_preflight:
        diagnostics = doctor.run_diagnostics()
        fatal = [d for d in diagnostics if d.status == doctor.Status.FAIL]
        if fatal:
            print("❌ Preflight check failed! Cannot start task with invalid environment:", file=sys.stderr)
            for f in fatal:
                print(f"  • {f.name}: {f.message}", file=sys.stderr)
                if f.remediation:
                    print(f"    Fix: {f.remediation}", file=sys.stderr)
            sys.exit(1)

    slug = format_slug(args.slug)
    if not slug:
        print("ERROR: Invalid slug description. Must contain alphanumeric characters.", file=sys.stderr)
        sys.exit(1)

    branch_name = f"{args.type}/{args.issue}-{slug}"
    if not validate_branch_name(branch_name):
        print(f"ERROR: Branch '{branch_name}' does not match convention {{type}}/{{issue}}-{{slug}}.", file=sys.stderr)
        sys.exit(1)

    # Check if branch exists
    chk_local = run_cmd(["git", "show-ref", "--verify", "--quiet", f"refs/heads/{branch_name}"])
    if chk_local.returncode == 0:
        print(f"ERROR: Local branch '{branch_name}' already exists. Switch with `git checkout {branch_name}`.", file=sys.stderr)
        sys.exit(1)

    # Base branch determination
    default_branch = args.base or get_default_branch()
    chk_remote = run_cmd(["git", "show-ref", "--verify", "--quiet", f"refs/remotes/origin/{default_branch}"])
    base_ref = f"origin/{default_branch}" if chk_remote.returncode == 0 else default_branch

    # Inspect GitHub Issue if gh is available
    gh_bin = find_gh_binary()
    if gh_bin:
        res = run_cmd([gh_bin, "issue", "view", str(args.issue), "--json", "title,assignees,state,url"])
        if res.returncode == 0:
            try:
                import json
                issue_info = json.loads(res.stdout)
                assignees = [a.get("login") for a in issue_info.get("assignees", [])]
                print(f"\n📋 GitHub Issue #{args.issue}: {sanitize_text(issue_info.get('title', ''))}")
                print(f"   Status: {issue_info.get('state')} | URL: {issue_info.get('url')}")
                if assignees:
                    print(f"   Assignees: {', '.join(assignees)}")
                    id_data, _ = load_identity()
                    my_gh = id_data.get("developer", {}).get("github_username") if id_data else None
                    if my_gh and my_gh not in assignees and not args.force:
                        print(f"⚠️  WARNING: Issue #{args.issue} is currently assigned to {assignees}, not you (@{my_gh}).", file=sys.stderr)
                        print("Use --force if you have explicit authorization to work on this task.", file=sys.stderr)
                        sys.exit(1)
            except Exception:
                pass

    if args.dry_run:
        print("\n--- DRY-RUN SUMMARY ---")
        print(f"Target Branch: {branch_name}")
        print(f"Base Reference: {base_ref}")
        print(f"Mode: {'Isolated Worktree' if args.worktree else 'Standard Git Branch'}")
        if args.worktree:
            wt_path = repo_root / ".agent" / "worktrees" / f"{args.issue}-{slug}"
            print(f"Worktree Directory: {wt_path}")
        print("-----------------------")
        sys.exit(0)

    # Creation
    if args.worktree:
        wt_dir = repo_root / ".agent" / "worktrees" / f"{args.issue}-{slug}"
        if wt_dir.exists():
            print(f"ERROR: Worktree directory already exists at {wt_dir}", file=sys.stderr)
            sys.exit(1)
        wt_dir.parent.mkdir(parents=True, exist_ok=True)
        res = run_cmd(["git", "worktree", "add", "-b", branch_name, str(wt_dir), base_ref])
        if res.returncode != 0:
            print(f"ERROR: Failed to create worktree: {res.stderr.strip()}", file=sys.stderr)
            sys.exit(1)

        print(f"\n✅ Isolated worktree created successfully!")
        print(f"   Branch: {branch_name}")
        print(f"   Worktree Location: {wt_dir}")
        print(f"\nTo begin development, open or navigate to the worktree:")
        print(f"   cd {wt_dir}")
    else:
        res = run_cmd(["git", "checkout", "-b", branch_name, base_ref])
        if res.returncode != 0:
            print(f"ERROR: Failed to create branch: {res.stderr.strip()}", file=sys.stderr)
            sys.exit(1)

        print(f"\n✅ Task branch created and checked out successfully!")
        print(f"   Branch: {branch_name}")
        print(f"   Based on: {base_ref}")

    print("\nNext steps:")
    print("1. Implement code according to issue requirements and tests.")
    print("2. Run tests to establish evidence: `python3 -m unittest` or project tests.")
    print("3. Sync progress: `python3 scripts/agentic/sync-state.py --state In_Progress`.")

if __name__ == "__main__":
    main()
